import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accubooks/core/constants/auth_constants.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/controllers/auth_controller.dart';
import 'package:accubooks/repositories/account_repository.dart';
import 'package:accubooks/repositories/auth_repository.dart';
import 'package:accubooks/services/auth_service.dart';

import 'package:accubooks/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });

    DatabaseHelper.initializeFfi();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AccuBooks SaaS Authentication & Multi-Tenant Tests', () {
    final authRepo = AuthRepository();
    final authService = AuthService(authRepo: authRepo);
    final accountRepo = AccountRepository();

    test('Sign Up: creates organization, assigns OWNER role, and seeds default accounts', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final email = 'owner_$ts@abctraders.com';
      final company = 'ABC Traders $ts';

      final user = await authService.signup(
        fullName: 'Test Owner',
        email: email,
        phone: '+91 9876543210',
        password: 'Password123',
        companyName: company,
      );

      // Verify User Model
      expect(user.id, isNotNull);
      expect(user.email, email.toLowerCase());
      expect(user.fullName, 'Test Owner');
      expect(user.role, AuthConstants.roleOwner);
      expect(user.isOwner, isTrue);
      expect(user.isAdmin, isTrue);

      // Verify Organization
      final org = await authRepo.getOrganizationById(user.organizationId);
      expect(org, isNotNull);
      expect(org!.name, company);
      expect(org.ownerId, user.id);

      // Verify AuthService State
      expect(authService.isAuthenticated.value, isTrue);
      expect(authService.currentUser.value?.id, user.id);
      expect(authService.currentOrganization.value?.id, org.id);

      // Verify default chart of accounts seeded
      final accounts = await accountRepo.getAllAccounts();
      expect(accounts.isNotEmpty, isTrue);
      final hasCash = accounts.any((a) => a.accountCode == AccountingConstants.codeCash);
      expect(hasCash, isTrue);
    });

    test('Sign Up: prevents duplicate email registration', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final email = 'duplicate_$ts@company.com';

      await authService.signup(
        fullName: 'First User',
        email: email,
        phone: '9876543210',
        password: 'Password123',
        companyName: 'Company A',
      );

      // Attempt second registration with same email
      expect(
        () async => await authService.signup(
          fullName: 'Second User',
          email: email,
          phone: '9876543211',
          password: 'Password123',
          companyName: 'Company B',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Login: authenticates with valid credentials, rejects invalid password', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final email = 'login_test_$ts@example.com';
      final password = 'SecurePassword1';

      await authService.signup(
        fullName: 'Login User',
        email: email,
        phone: '1234567890',
        password: password,
        companyName: 'Login Enterprise',
      );

      // Logout first
      await authService.logout();
      expect(authService.isAuthenticated.value, isFalse);

      // Test wrong password
      expect(
        () async => await authService.login(email: email, password: 'WrongPassword1'),
        throwsA(isA<Exception>()),
      );

      // Test valid login
      final loggedIn = await authService.login(email: email, password: password, rememberMe: true);
      expect(loggedIn.email, email.toLowerCase());
      expect(authService.isAuthenticated.value, isTrue);
    });

    test('Session Persistence: restoreSession recovers active session', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final email = 'session_test_$ts@example.com';
      final password = 'Password999';

      final created = await authService.signup(
        fullName: 'Session User',
        email: email,
        phone: '1122334455',
        password: password,
        companyName: 'Session Org',
      );

      // Clear memory state but preserve persistent storage
      authService.currentUser.value = null;
      authService.currentOrganization.value = null;
      authService.isAuthenticated.value = false;

      // Restore session
      final restored = await authService.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.id, created.id);
      expect(authService.isAuthenticated.value, isTrue);
    });

    test('Logout: clears session token and authentication state', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final email = 'logout_test_$ts@example.com';

      await authService.signup(
        fullName: 'Logout User',
        email: email,
        phone: '5544332211',
        password: 'Password123',
        companyName: 'Logout Org',
      );

      expect(authService.isAuthenticated.value, isTrue);

      await authService.logout();

      expect(authService.isAuthenticated.value, isFalse);
      expect(authService.currentUser.value, isNull);
      expect(authService.currentOrganization.value, isNull);

      final restored = await authService.restoreSession();
      expect(restored, isNull);
    });

    test('Forgot & Reset Password flow: token verification and password update', () async {
      final ts = DateTime.now().microsecondsSinceEpoch;
      final email = 'reset_test_$ts@example.com';
      final oldPassword = 'OldPassword1';
      final newPassword = 'NewPassword2';

      await authService.signup(
        fullName: 'Reset User',
        email: email,
        phone: '9988776655',
        password: oldPassword,
        companyName: 'Reset Org',
      );

      // Request reset
      final token = await authService.requestPasswordReset(email);
      expect(token, isNotEmpty);
      expect(token.length, 6);

      // Reset password with token
      final resetSuccess = await authService.resetPassword(
        email: email,
        token: token,
        newPassword: newPassword,
      );
      expect(resetSuccess, isTrue);

      // Verify login with old password fails
      expect(
        () async => await authService.login(email: email, password: oldPassword),
        throwsA(isA<Exception>()),
      );

      // Verify login with new password succeeds
      final loggedIn = await authService.login(email: email, password: newPassword);
      expect(loggedIn.email, email.toLowerCase());
    });

    test('Validation Helpers: password complexity and strength validation', () {
      // Must have length >= 8, uppercase, lowercase, number
      expect(AuthController.validatePassword('short'), isNotNull);
      expect(AuthController.validatePassword('alllowercase123'), isNotNull);
      expect(AuthController.validatePassword('ALLUPPERCASE123'), isNotNull);
      expect(AuthController.validatePassword('NoNumbersHere'), isNotNull);
      expect(AuthController.validatePassword('ValidPass123'), isNull);

      // Email validation
      expect(AuthController.isValidEmail('test@company.com'), isTrue);
      expect(AuthController.isValidEmail('not-an-email'), isFalse);
      expect(AuthController.isValidEmail(''), isFalse);

      // Phone validation
      expect(AuthController.isValidPhone('+91 9876543210'), isTrue);
      expect(AuthController.isValidPhone('123'), isFalse);
    });
  });
}
