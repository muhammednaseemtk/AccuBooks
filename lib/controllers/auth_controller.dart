import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../app/routes/app_routes.dart';
import '../app/theme/app_colors.dart';
import '../core/database/database_helper.dart';
import '../core/widgets/app_dialog.dart';
import '../models/country_model.dart';
import '../models/organization_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';

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
  final Rx<Country> signupCountry = Countries.defaultCountry.obs;

  String get fullSignupPhoneNumber => Countries.formatFullPhoneNumber(
        signupPhoneController.text.trim(),
        signupCountry.value.dialCode,
      );

  // Controllers: Forgot Password
  final forgotEmailController = TextEditingController();

  // Controllers: Reset Password
  final resetCodeController = TextEditingController();
  final resetNewPasswordController = TextEditingController();
  final resetConfirmPasswordController = TextEditingController();

  // Controllers: Profile
  final profileNameController = TextEditingController();
  final profileEmailController = TextEditingController();
  final profilePhoneController = TextEditingController();
  final RxBool isEditingProfile = false.obs;
  final Rx<String?> selectedImagePreviewPath = Rx<String?>(null);
  final RxBool isImageMarkedForRemoval = false.obs;

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
      if (user != null && !isEditingProfile.value) {
        profileNameController.text = user.fullName;
        profileEmailController.text = user.email;
        profilePhoneController.text = user.phone ?? '';
      }
    });

    final initialUser = _authService.currentUser.value;
    if (initialUser != null) {
      profileNameController.text = initialUser.fullName;
      profileEmailController.text = initialUser.email;
      profilePhoneController.text = initialUser.phone ?? '';
    }
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
    profileEmailController.dispose();
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

  static bool isValidPhone(String phone, [Country? country]) {
    if (country != null) {
      return country.isValid(phone);
    }
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

      // Initialize the correct user's data context and verify database access
      try {
        AuthService.clearUserControllers();
        await DatabaseHelper().database;
        final reportService = ReportService();
        await reportService.getDashboardMetrics();
      } catch (dataInitError) {
        // Safe fallback: rollback authentication state if user data context fails
        await _authService.logout();
        throw Exception('Failed to initialize user accounting workspace. Please try again.');
      }

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
    if (phone.isEmpty || !signupCountry.value.isValid(phone)) {
      _showError('Enter a valid phone number');
      return;
    }

    // 4. Password Requirement Validation
    final pwdErr = validatePassword(password);
    if (pwdErr != null) {
      _showError(pwdErr);
      return;
    }

    // 5. Company Name Validation
    if (companyName.isEmpty || companyName.length < 2) {
      _showError('Please enter your company / organization name.');
      return;
    }

    final fullPhoneNumber = Countries.formatFullPhoneNumber(
      phone,
      signupCountry.value.dialCode,
    );

    try {
      isLoading.value = true;
      await _authService.signup(
        fullName: fullName,
        email: email,
        phone: fullPhoneNumber,
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
  // Profile Management & Image
  // -------------------------------------------------------------
  void startEditingProfile() {
    final user = currentUser;
    if (user != null) {
      profileNameController.text = user.fullName;
      profileEmailController.text = user.email;
      profilePhoneController.text = user.phone ?? '';
    }
    selectedImagePreviewPath.value = null;
    isImageMarkedForRemoval.value = false;
    isEditingProfile.value = true;
  }

  void cancelEditingProfile() {
    final user = currentUser;
    if (user != null) {
      profileNameController.text = user.fullName;
      profileEmailController.text = user.email;
      profilePhoneController.text = user.phone ?? '';
    }
    selectedImagePreviewPath.value = null;
    isImageMarkedForRemoval.value = false;
    isEditingProfile.value = false;
  }

  Future<void> pickProfileImage() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Select Profile Photo',
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      );

      if (result.isEmpty) {
        return; // Canceled by user
      }

      final file = result.first;
      final path = file.path;
      if (path == null) {
        _showError('Unable to access selected image file.');
        return;
      }

      final ext = (file.extension ?? p.extension(path).replaceFirst('.', '')).toLowerCase();
      const validExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
      if (!validExtensions.contains(ext)) {
        _showError('Invalid file type. Please select a JPG, PNG, WEBP, or GIF image.');
        return;
      }

      final ioFile = File(path);
      if (!await ioFile.exists()) {
        _showError('Selected file does not exist.');
        return;
      }

      final fileSize = await ioFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        _showError('Image size exceeds 5MB limit. Please choose a smaller image.');
        return;
      }

      selectedImagePreviewPath.value = path;
      isImageMarkedForRemoval.value = false;
      isEditingProfile.value = true;
    } catch (e) {
      debugPrint('Error picking profile image: $e');
      _showError('Failed to select image: $e');
    }
  }

  void removeProfileImage() {
    selectedImagePreviewPath.value = null;
    isImageMarkedForRemoval.value = true;
  }

  Future<void> updateProfile() async {
    if (isLoading.value) return;

    final user = currentUser;
    if (user == null || user.id == null) {
      _showError('No active user session found.');
      return;
    }

    final fullName = profileNameController.text.trim();
    final email = profileEmailController.text.trim();
    final phone = profilePhoneController.text.trim();

    if (fullName.isEmpty || fullName.length < 2) {
      _showError('Please enter a valid full name (minimum 2 characters).');
      return;
    }

    if (email.isEmpty || !isValidEmail(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    try {
      isLoading.value = true;

      String? persistentImagePath;
      final clearImage = isImageMarkedForRemoval.value;

      if (clearImage) {
        // Remove image
        if (user.profileImage != null) {
          final oldFile = File(user.profileImage!);
          if (await oldFile.exists()) {
            try {
              await oldFile.delete();
            } catch (_) {}
          }
        }
        persistentImagePath = null;
      } else if (selectedImagePreviewPath.value != null) {
        // Persist newly selected preview image
        final previewFile = File(selectedImagePreviewPath.value!);
        if (await previewFile.exists()) {
          final docDir = await getApplicationDocumentsDirectory();
          final storageDir = Directory(p.join(docDir.path, 'AccuBooks', 'profile_images'));
          if (!await storageDir.exists()) {
            await storageDir.create(recursive: true);
          }

          final ext = p.extension(selectedImagePreviewPath.value!).toLowerCase();
          final targetFileName = 'user_${user.id}_profile_${DateTime.now().millisecondsSinceEpoch}$ext';
          final targetFile = File(p.join(storageDir.path, targetFileName));

          await previewFile.copy(targetFile.path);

          // Clean up old avatar file if different
          if (user.profileImage != null && user.profileImage != targetFile.path) {
            final oldFile = File(user.profileImage!);
            if (await oldFile.exists()) {
              try {
                await oldFile.delete();
              } catch (_) {}
            }
          }

          persistentImagePath = targetFile.path;
        }
      } else {
        // Retain existing profile image
        persistentImagePath = user.profileImage;
      }

      await _authService.updateProfile(
        fullName: fullName,
        email: email,
        phone: phone.isNotEmpty ? phone : null,
        profileImage: persistentImagePath,
        clearProfileImage: clearImage,
      );

      selectedImagePreviewPath.value = null;
      isImageMarkedForRemoval.value = false;
      isEditingProfile.value = false;

      if (Get.context != null) {
        Get.snackbar(
          'Success',
          'Profile updated successfully',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showError(msg);
      // NOTE: User's entered data is preserved!
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
      profileNameController.clear();
      profileEmailController.clear();
      profilePhoneController.clear();
      loginPasswordController.clear();
      selectedImagePreviewPath.value = null;
      isEditingProfile.value = false;
      isImageMarkedForRemoval.value = false;
      errorMessage.value = '';
      successMessage.value = '';
      Get.offAllNamed(AppRoutes.login);
    }
  }

  void _showError(String message) {
    errorMessage.value = message;
    if (Get.overlayContext != null) {
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
}
