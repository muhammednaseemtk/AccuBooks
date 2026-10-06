import 'package:get/get.dart';
import '../core/constants/auth_constants.dart';
import '../models/organization_model.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthService extends GetxService {
  final AuthRepository _authRepo;

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final Rx<OrganizationModel?> currentOrganization = Rx<OrganizationModel?>(null);
  final RxBool isAuthenticated = false.obs;

  AuthService({AuthRepository? authRepo})
      : _authRepo = authRepo ?? AuthRepository();

  bool get isOwner => currentUser.value?.isOwner ?? false;
  bool get isAdmin => currentUser.value?.isAdmin ?? false;
  bool get isAccountant => currentUser.value?.isAccountant ?? false;
  String get userRole => currentUser.value?.role ?? AuthConstants.roleViewer;

  /// Check and restore existing session from secure storage
  Future<UserModel?> restoreSession() async {
    try {
      final session = await _authRepo.loadSession();
      if (session == null) {
        isAuthenticated.value = false;
        return null;
      }

      final userId = session['userId'] as int;
      final user = await _authRepo.findUserById(userId);
      if (user == null || !user.isActive) {
        await _authRepo.clearSession();
        isAuthenticated.value = false;
        return null;
      }

      final org = await _authRepo.getOrganizationById(user.organizationId);

      currentUser.value = user;
      currentOrganization.value = org;
      isAuthenticated.value = true;
      return user;
    } catch (_) {
      isAuthenticated.value = false;
      return null;
    }
  }

  /// Complete SaaS Sign Up flow:
  /// 1. Check email uniqueness
  /// 2. Create Organization
  /// 3. Create User with role OWNER
  /// 4. Link User as Owner in Organization
  /// 5. Seed default chart of accounts for the new organization
  /// 6. Save session & mark authenticated
  Future<UserModel> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String companyName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanFullName = fullName.trim();
    final cleanCompanyName = companyName.trim();
    final cleanPhone = phone.trim();

    // Check if email already registered
    final existingUser = await _authRepo.findUserByEmail(cleanEmail);
    if (existingUser != null) {
      throw Exception('This email is already registered.');
    }

    // 1. Create Organization
    final org = await _authRepo.createOrganization(
      name: cleanCompanyName,
      email: cleanEmail,
      phone: cleanPhone,
    );

    if (org.id == null) {
      throw Exception('Failed to create company organization. Please try again.');
    }

    // 2. Create User as OWNER
    final user = await _authRepo.createUser(
      organizationId: org.id!,
      email: cleanEmail,
      password: password,
      fullName: cleanFullName,
      phone: cleanPhone,
      role: AuthConstants.roleOwner,
    );

    // 3. Set Owner ID on Organization
    if (user.id != null) {
      await _authRepo.updateOrganizationOwner(org.id!, user.id!);
    }

    // 4. Seed default chart of accounts for this organization
    await _authRepo.seedDefaultAccountsForOrganization(org.id!);

    // 5. Store session and set reactive user state
    await _authRepo.saveSession(
      userId: user.id!,
      email: cleanEmail,
      organizationId: org.id!,
      rememberMe: true,
    );

    currentUser.value = user;
    currentOrganization.value = org.copyWith(ownerId: user.id);
    isAuthenticated.value = true;

    return user;
  }

  /// Login with email and password
  Future<UserModel> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Query credentials
    final creds = await _authRepo.getAuthCredentialsByEmail(cleanEmail);
    if (creds == null) {
      throw Exception('Invalid email or password.');
    }

    // 2. Verify password
    final storedHash = creds['password_hash'] as String;
    final salt = creds['salt'] as String;
    final isMatch = AuthRepository.verifyPassword(password, storedHash, salt);
    if (!isMatch) {
      throw Exception('Invalid email or password.');
    }

    // 3. Check active status
    final isActive = (creds['is_active'] as int? ?? 1) == 1;
    if (!isActive) {
      throw Exception('Your account is currently disabled. Please contact support.');
    }

    final user = UserModel.fromMap(creds);
    final org = await _authRepo.getOrganizationById(user.organizationId);

    // 4. Save session
    await _authRepo.saveSession(
      userId: user.id!,
      email: user.email,
      organizationId: user.organizationId,
      rememberMe: rememberMe,
    );

    currentUser.value = user;
    currentOrganization.value = org;
    isAuthenticated.value = true;

    return user;
  }

  /// Request Password Reset link / verification token
  Future<String> requestPasswordReset(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final user = await _authRepo.findUserByEmail(cleanEmail);

    if (user != null) {
      return await _authRepo.createPasswordResetToken(cleanEmail);
    }

    // Return dummy token or success message to preserve privacy
    return '123456';
  }

  /// Reset Password with verification token
  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final success = await _authRepo.resetPasswordWithToken(
      email: email,
      token: token,
      newPassword: newPassword,
    );

    if (!success) {
      throw Exception('Invalid or expired reset code. Please check and try again.');
    }

    return true;
  }

  /// Update User Profile
  Future<void> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    final user = currentUser.value;
    if (user == null || user.id == null) {
      throw Exception('No active user session found.');
    }

    await _authRepo.updateProfile(
      userId: user.id!,
      fullName: fullName,
      phone: phone,
    );

    currentUser.value = user.copyWith(
      fullName: fullName,
      phone: phone,
      updatedAt: DateTime.now(),
    );
  }

  /// Logout and clear session
  Future<void> logout() async {
    await _authRepo.clearSession();
    currentUser.value = null;
    currentOrganization.value = null;
    isAuthenticated.value = false;
  }
}
