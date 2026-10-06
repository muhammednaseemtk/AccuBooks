import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/auth_controller.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallScreen = screenWidth < 400;
    final screenPadding = isSmallScreen ? 16.0 : 24.0;
    final cardPadding = isSmallScreen ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenPadding, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AppCard(
                padding: EdgeInsets.all(cardPadding),
                borderRadius: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Forgot Password?',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your email address and we will send you verification instructions to reset your password.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Email Field
                    AppTextField(
                      label: 'Enter your email:',
                      hint: 'name@company.com',
                      controller: controller.forgotEmailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      isRequired: true,
                      onSubmitted: (_) => controller.sendPasswordReset(),
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    Obx(() => AppButton(
                          text: controller.isLoading.value ? 'Sending instructions...' : 'Send Reset Link',
                          icon: controller.isLoading.value ? null : Icons.send_rounded,
                          isLoading: controller.isLoading.value,
                          isFullWidth: true,
                          height: 48,
                          onPressed: controller.isLoading.value ? null : () => controller.sendPasswordReset(),
                        )),
                    const SizedBox(height: 20),

                    // Back to Login
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Back to Login'),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
