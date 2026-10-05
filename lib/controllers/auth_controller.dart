import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app/routes/app_routes.dart';
import '../app/theme/app_colors.dart';
import '../core/widgets/app_dialog.dart';
import '../models/organization_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService;

  AuthController({AuthService? authService})
      : _authService = authService ?? Get.find<AuthService>();

  // Reactive State
  final RxBool isLoading = false.obs;
  final RxBool rememberMe = true.obs;
  final RxString errorMessage = ''.obs;
  final RxString successMessage = ''.obs;

  // Password Visibility Toggles
  final RxBool loginObscurePassword = true.obs;
  final RxBool signupObscurePassword = true.obs;
  final RxBool signupObscureConfirmPassword = true.obs;
  final RxBool resetObscurePassword = true.obs;
  final RxBool resetObscureConfirmPassword = true.obs;

  // Password Strength Reactive
  final RxString passwordStrength = 'Weak'.obs;
  final RxDouble passwordStrengthProgress = 0.2.obs;
  final Rx<Color> passwordStrengthColor = Colors.red.obs;

  // Controllers: Login
  final loginEmailController = TextEditingController();
  final loginPasswordController = TextEditingController();

  // Controllers: Sign Up
  final signupFullNameController = TextEditingController();
  final signupEmailController = TextEditingController();
  final signupPhoneController = TextEditingController();
  final signupPasswordController = TextEditingController();
  final signupConfirmPasswordController = TextEditingController();
  final signupCompanyController = TextEditingController();

  // Controllers: Forgot Password
  final forgotEmailController = TextEditingController();

  // Controllers: Reset Password
  final resetCodeController = TextEditingController();
  final resetNewPasswordController = TextEditingController();
  final resetConfirmPasswordController = TextEditingController();

  // Controllers: Profile
  final profileNameController = TextEditingController();
  final profilePhoneController = TextEditingController();

  // Getters for Auth State
  UserModel? get currentUser => _authService.currentUser.value;
  OrganizationModel? get currentOrganization => _authService.currentOrganization.value;
  bool get isAuthenticated => _authService.isAuthenticated.value;
  bool get isOwner => _authService.isOwner;
  bool get isAdmin => _authService.isAdmin;
  String get userRole => _authService.userRole;

  @override
  void onInit() {
    super.onInit();
    // Listen to password input to dynamically update strength meter
    signupPasswordController.addListener(() {
      _evaluatePasswordStrength(signupPasswordController.text);
    });
    resetNewPasswordController.addListener(() {
      _evaluatePasswordStrength(resetNewPasswordController.text);
    });

    // Populate profile controllers if user session changes
    ever(_authService.currentUser, (user) {
      if (user != null) {
        profileNameController.text = user.fullName;
        profilePhoneController.text = user.phone ?? '';
      }
    });
  }

  @override
  void onClose() {
    loginEmailController.dispose();
    loginPasswordController.dispose();
    signupFullNameController.dispose();
    signupEmailController.dispose();
    signupPhoneController.dispose();
    signupPasswordController.dispose();
    signupConfirmPasswordController.dispose();
    signupCompanyController.dispose();
    forgotEmailController.dispose();
    resetCodeController.dispose();
    resetNewPasswordController.dispose();
    resetConfirmPasswordController.dispose();
    profileNameController.dispose();
    profilePhoneController.dispose();
    super.onClose();
  }

  // -------------------------------------------------------------
  // Password Strength Evaluator
  // -------------------------------------------------------------
  void _evaluatePasswordStrength(String password) {
    if (password.isEmpty) {
      passwordStrength.value = 'Weak';
      passwordStrengthProgress.value = 0.1;
      passwordStrengthColor.value = Colors.red;
      return;
    }

    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 3) {
      passwordStrength.value = 'Weak';
      passwordStrengthProgress.value = 0.33;
      passwordStrengthColor.value = Colors.red;
    } else if (score <= 5) {
      passwordStrength.value = 'Medium';
      passwordStrengthProgress.value = 0.66;
      passwordStrengthColor.value = Colors.orange;
    } else {
      passwordStrength.value = 'Strong';
      passwordStrengthProgress.value = 1.0;
      passwordStrengthColor.value = AppColors.credit;
    }
  }

  // -------------------------------------------------------------
  // Validation Helpers
  // -------------------------------------------------------------
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$');
    return emailRegex.hasMatch(email.trim());
  }

  static bool isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
    return cleaned.length >= 7 && cleaned.length <= 15;
  }

  static String? validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least one number.';
    }
    return null;
  }

  // -------------------------------------------------------------
  // Session Check
  // -------------------------------------------------------------
  Future<bool> checkSession() async {
    final user = await _authService.restoreSession();
    return user != null;
  }

  // -------------------------------------------------------------
  // Login
  // -------------------------------------------------------------
  Future<void> login() async {
    if (isLoading.value) return; // Prevent duplicate requests
    errorMessage.value = '';

    final email = loginEmailController.text.trim();
    final password = loginPasswordController.text;

    if (email.isEmpty) {
      _showError('Please enter your email address.');
      return;
    }
    if (!isValidEmail(email)) {
      _showError('Please enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter your password.');
      return;
    }

    try {
      isLoading.value = true;
      await _authService.login(
        email: email,
        password: password,
        rememberMe: rememberMe.value,
      );

      // Clean controllers
      loginPasswordController.clear();

      // Navigate to Dashboard
      Get.offAllNamed(AppRoutes.dashboard);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showError(msg);
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------------------------------------------------
  // Sign Up
  // -------------------------------------------------------------
  Future<void> signup() async {
    if (isLoading.value) return; // Prevent duplicate requests
    errorMessage.value = '';

    final fullName = signupFullNameController.text.trim();
    final email = signupEmailController.text.trim();
    final phone = signupPhoneController.text.trim();
    final password = signupPasswordController.text;
    final confirmPassword = signupConfirmPasswordController.text;
    final companyName = signupCompanyController.text.trim();

    // 1. Full Name Validation
    if (fullName.isEmpty || fullName.length < 2) {
      _showError('Please enter your full name (minimum 2 characters).');
      return;
    }

    // 2. Email Validation
    if (email.isEmpty || !isValidEmail(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    // 3. Phone Validation
    if (phone.isEmpty || !isValidPhone(phone)) {
      _showError('Please enter a valid phone number.');
      return;
    }

    // 4. Password Requirement Validation
    final pwdErr = validatePassword(password);
    if (pwdErr != null) {
      _showError(pwdErr);
      return;
    }

    // 5. Confirm Password Validation
    if (password != confirmPassword) {
      _showError('Passwords do not match.');
      return;
    }

    // 6. Company Name Validation
    if (companyName.isEmpty || companyName.length < 2) {
      _showError('Please enter your company / organization name.');
      return;
    }

    try {
      isLoading.value = true;
      await _authService.signup(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        companyName: companyName,
      );

      // Clear sensitive controllers
      signupPasswordController.clear();
      signupConfirmPasswordController.clear();

      Get.snackbar(
        'Account Created',
        'Welcome to AccuBooks, $fullName! Your company $companyName is ready.',
        backgroundColor: AppColors.credit,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );

      // Navigate to Dashboard
      Get.offAllNamed(AppRoutes.dashboard);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showError(msg);
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------------------------------------------------
  // Forgot Password
  // -------------------------------------------------------------
  Future<void> sendPasswordReset() async {
    if (isLoading.value) return;
    errorMessage.value = '';

    final email = forgotEmailController.text.trim();
    if (email.isEmpty || !isValidEmail(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    try {
      isLoading.value = true;
      final token = await _authService.requestPasswordReset(email);

      // Pre-fill reset code if returned for seamless local testing
      resetCodeController.text = token;

      Get.snackbar(
        'Instructions Sent',
        'Reset instructions have been sent to your email ($email). Verification code: $token',
        backgroundColor: AppColors.primary,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 8),
      );

      Get.toNamed(AppRoutes.resetPassword, arguments: {'email': email});
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showError(msg);
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------------------------------------------------
  // Reset Password
  // -------------------------------------------------------------
  Future<void> resetPassword() async {
    if (isLoading.value) return;
    errorMessage.value = '';

    final email = (Get.arguments != null && Get.arguments is Map)
        ? (Get.arguments['email'] as String? ?? forgotEmailController.text.trim())
        : forgotEmailController.text.trim();

    final code = resetCodeController.text.trim();
    final newPassword = resetNewPasswordController.text;
    final confirmPassword = resetConfirmPasswordController.text;

    if (code.isEmpty) {
      _showError('Please enter the 6-digit verification code.');
      return;
    }

    final pwdErr = validatePassword(newPassword);
    if (pwdErr != null) {
      _showError(pwdErr);
      return;
    }

    if (newPassword != confirmPassword) {
      _showError('Passwords do not match.');
      return;
    }

    try {
      isLoading.value = true;
      await _authService.resetPassword(
        email: email,
        token: code,
        newPassword: newPassword,
      );

      resetCodeController.clear();
      resetNewPasswordController.clear();
      resetConfirmPasswordController.clear();

      Get.snackbar(
        'Password Updated',
        'Password updated successfully. Please login with your new credentials.',
        backgroundColor: AppColors.credit,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );

      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showError(msg);
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------------------------------------------------
  // Profile Update
  // -------------------------------------------------------------
  Future<void> updateProfile() async {
    if (isLoading.value) return;

    final fullName = profileNameController.text.trim();
    final phone = profilePhoneController.text.trim();

    if (fullName.isEmpty || fullName.length < 2) {
      _showError('Please enter a valid full name.');
      return;
    }

    try {
      isLoading.value = true;
      await _authService.updateProfile(
        fullName: fullName,
        phone: phone.isNotEmpty ? phone : null,
      );

      Get.snackbar(
        'Profile Updated',
        'Your profile has been saved successfully.',
        backgroundColor: AppColors.credit,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showError(msg);
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------------------------------------------------
  // Logout with Confirmation Dialog
  // -------------------------------------------------------------
  Future<void> confirmLogout() async {
    final confirmed = await AppDialog.confirm(
      title: 'Logout?',
      message: 'Are you sure you want to logout? You will need to sign in again to access your company accounting data.',
      confirmText: 'Logout',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirmed == true) {
      await _authService.logout();
      Get.offAllNamed(AppRoutes.login);
    }
  }

  void _showError(String message) {
    errorMessage.value = message;
    Get.snackbar(
      'Authentication Error',
      message,
      backgroundColor: AppColors.debit,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    );
  }
}
