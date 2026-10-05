import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/auth_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_migrations.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../models/organization_model.dart';
import '../models/user_model.dart';

class AuthRepository {
  final DatabaseHelper _dbHelper;

  AuthRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  // -------------------------------------------------------------
  // Cryptographic Helpers (Salt + SHA-256)
  // -------------------------------------------------------------
  static String generateSalt([int length = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password:$salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool verifyPassword(String password, String storedHash, String salt) {
    return hashPassword(password, salt) == storedHash;
  }

  // -------------------------------------------------------------
  // User Queries & Creation
  // -------------------------------------------------------------
  Future<UserModel?> findUserByEmail(String email) async {
    final db = await _dbHelper.database;
    final cleanEmail = email.trim().toLowerCase();
    final res = await db.query(
      DatabaseTables.tableUsers,
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return UserModel.fromMap(res.first);
  }

  Future<UserModel?> findUserById(int id) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      DatabaseTables.tableUsers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return UserModel.fromMap(res.first);
  }

  Future<Map<String, dynamic>?> getAuthCredentialsByEmail(String email) async {
    final db = await _dbHelper.database;
    final cleanEmail = email.trim().toLowerCase();
    final res = await db.query(
      DatabaseTables.tableUsers,
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first;
  }

  Future<UserModel> createUser({
    required int organizationId,
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String role = AuthConstants.roleOwner,
    Transaction? txn,
  }) async {
    final executor = txn ?? await _dbHelper.database;
    final salt = generateSalt();
    final hash = hashPassword(password, salt);
    final now = AppDateUtils.formatDb(DateTime.now());
    final cleanEmail = email.trim().toLowerCase();

    final id = await executor.insert(DatabaseTables.tableUsers, {
      'organization_id': organizationId,
      'email': cleanEmail,
      'password_hash': hash,
      'salt': salt,
      'full_name': fullName.trim(),
      'phone': phone?.trim(),
      'role': role,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    return UserModel(
      id: id,
      organizationId: organizationId,
      email: cleanEmail,
      fullName: fullName.trim(),
      phone: phone?.trim(),
      role: role,
      isActive: true,
    );
  }

  Future<void> updateProfile({
    required int userId,
    required String fullName,
    String? phone,
  }) async {
    final db = await _dbHelper.database;
    final now = AppDateUtils.formatDb(DateTime.now());
    await db.update(
      DatabaseTables.tableUsers,
      {
        'full_name': fullName.trim(),
        'phone': phone?.trim(),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updatePassword({
    required int userId,
    required String newPassword,
  }) async {
    final db = await _dbHelper.database;
    final salt = generateSalt();
    final hash = hashPassword(newPassword, salt);
    final now = AppDateUtils.formatDb(DateTime.now());

    await db.update(
      DatabaseTables.tableUsers,
      {
        'password_hash': hash,
        'salt': salt,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // -------------------------------------------------------------
  // Organization Management
  // -------------------------------------------------------------
  Future<OrganizationModel?> getOrganizationById(int id) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      DatabaseTables.tableOrganizations,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return OrganizationModel.fromMap(res.first);
  }

  Future<OrganizationModel> createOrganization({
    required String name,
    required String email,
    String? phone,
    String? address,
    Transaction? txn,
  }) async {
    final executor = txn ?? await _dbHelper.database;
    final now = AppDateUtils.formatDb(DateTime.now());

    final id = await executor.insert(DatabaseTables.tableOrganizations, {
      'name': name.trim(),
      'owner_id': null,
      'currency': '₹',
      'email': email.trim().toLowerCase(),
      'phone': phone?.trim(),
      'address': address?.trim(),
      'created_at': now,
      'updated_at': now,
    });

    return OrganizationModel(
      id: id,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone?.trim(),
      address: address?.trim(),
    );
  }

  Future<void> updateOrganizationOwner(int orgId, int ownerId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    final now = AppDateUtils.formatDb(DateTime.now());
    await executor.update(
      DatabaseTables.tableOrganizations,
      {
        'owner_id': ownerId,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [orgId],
    );
  }

  Future<void> seedDefaultAccountsForOrganization(int organizationId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    await DatabaseMigrations.seedChartOfAccountsForOrganization(executor, organizationId);
  }

  // -------------------------------------------------------------
  // Password Reset Management
  // -------------------------------------------------------------
  Future<String> createPasswordResetToken(String email) async {
    final db = await _dbHelper.database;
    final cleanEmail = email.trim().toLowerCase();

    // 6-digit numeric verification code
    final rand = Random.secure();
    final token = (100000 + rand.nextInt(900000)).toString();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 1));

    // Clear previous tokens for this email
    await db.delete(
      DatabaseTables.tablePasswordResets,
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
    );

    await db.insert(DatabaseTables.tablePasswordResets, {
      'email': cleanEmail,
      'token': token,
      'expires_at': AppDateUtils.formatDb(expiresAt),
      'created_at': AppDateUtils.formatDb(now),
    });

    return token;
  }

  Future<bool> verifyPasswordResetToken(String email, String token) async {
    final db = await _dbHelper.database;
    final cleanEmail = email.trim().toLowerCase();
    final cleanToken = token.trim();

    final res = await db.query(
      DatabaseTables.tablePasswordResets,
      where: 'LOWER(email) = ? AND token = ?',
      whereArgs: [cleanEmail, cleanToken],
      limit: 1,
    );

    if (res.isEmpty) return false;

    final expiresStr = res.first['expires_at'] as String?;
    final expiresAt = AppDateUtils.parseDb(expiresStr);
    if (DateTime.now().isAfter(expiresAt)) {
      return false; // Expired
    }

    return true;
  }

  Future<bool> resetPasswordWithToken({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final isValid = await verifyPasswordResetToken(email, token);
    if (!isValid) return false;

    final user = await findUserByEmail(email);
    if (user == null || user.id == null) return false;

    await updatePassword(userId: user.id!, newPassword: newPassword);

    // Clean up used token
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseTables.tablePasswordResets,
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
    );

    return true;
  }

  // -------------------------------------------------------------
  // Session Persistence via SharedPreferences
  // -------------------------------------------------------------
  Future<void> saveSession({
    required int userId,
    required String email,
    required int organizationId,
    required bool rememberMe,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AuthConstants.prefRememberMe, rememberMe);
    if (rememberMe) {
      await prefs.setInt(AuthConstants.prefUserId, userId);
      await prefs.setString(AuthConstants.prefUserEmail, email.trim().toLowerCase());
      await prefs.setInt(AuthConstants.prefActiveOrgId, organizationId);
      final sessionToken = generateSalt(32);
      await prefs.setString(AuthConstants.prefAuthToken, sessionToken);
    } else {
      // Clear token so next startup requires login
      await prefs.remove(AuthConstants.prefAuthToken);
      await prefs.remove(AuthConstants.prefUserId);
      await prefs.remove(AuthConstants.prefUserEmail);
      await prefs.remove(AuthConstants.prefActiveOrgId);
    }
  }

  Future<Map<String, dynamic>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(AuthConstants.prefRememberMe) ?? true;
    if (!rememberMe) return null;

    final token = prefs.getString(AuthConstants.prefAuthToken);
    final userId = prefs.getInt(AuthConstants.prefUserId);
    final email = prefs.getString(AuthConstants.prefUserEmail);
    final orgId = prefs.getInt(AuthConstants.prefActiveOrgId);

    if (token == null || userId == null || email == null) {
      return null;
    }

    return {
      'userId': userId,
      'email': email,
      'organizationId': orgId ?? 1,
      'token': token,
    };
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AuthConstants.prefAuthToken);
    await prefs.remove(AuthConstants.prefUserId);
    await prefs.remove(AuthConstants.prefUserEmail);
    await prefs.remove(AuthConstants.prefActiveOrgId);
    await prefs.remove(AuthConstants.prefRememberMe);
  }
}
