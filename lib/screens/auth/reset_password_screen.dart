import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/auth_controller.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final email = (Get.arguments != null && Get.arguments is Map)
        ? (Get.arguments['email'] as String? ?? '')
        : '';

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
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.vpn_key_rounded,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Reset Password',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email.isNotEmpty
                          ? 'Enter the verification code sent to $email along with your new password.'
                          : 'Enter your verification code and choose a new password.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Verification Code Field
                    AppTextField(
                      label: 'Verification Code',
                      hint: 'Verification Code',
                      controller: controller.resetCodeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        AppInputFormatters.digitsOnly,
                        AppInputFormatters.length(6),
                      ],
                      prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),

                    // New Password Field
                    Obx(() => AppTextField(
                          label: 'New Password',
                          hint: 'New Password',
                          controller: controller.resetNewPasswordController,
                          obscureText: controller.resetObscurePassword.value,
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          isRequired: true,
                          suffixIcon: IconButton(
                            icon: Icon(
                              controller.resetObscurePassword.value
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                            onPressed: () => controller.resetObscurePassword.toggle(),
                          ),
                        )),
                    const SizedBox(height: 8),

                    // Dynamic Strength Meter
                    Obx(() {
                      final strength = controller.passwordStrength.value;
                      final progress = controller.passwordStrengthProgress.value;
                      final color = controller.passwordStrengthColor.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              Text(
                                'Password Strength:',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                              Text(
                                strength,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: isDark ? AppColors.surfaceVariantDark : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    Obx(() => AppTextField(
                          label: 'Confirm Password',
                          hint: 'Confirm Password',
                          controller: controller.resetConfirmPasswordController,
                          obscureText: controller.resetObscureConfirmPassword.value,
                          prefixIcon: const Icon(Icons.lock_reset_outlined, size: 20),
                          isRequired: true,
                          suffixIcon: IconButton(
                            icon: Icon(
                              controller.resetObscureConfirmPassword.value
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                            onPressed: () => controller.resetObscureConfirmPassword.toggle(),
                          ),
                          onSubmitted: (_) => controller.resetPassword(),
                        )),
                    const SizedBox(height: 28),

                    // Submit Button
                    Obx(() => AppButton(
                          text: controller.isLoading.value ? 'Updating Password...' : 'Reset Password',
                          icon: controller.isLoading.value ? null : Icons.check_circle_outline,
                          isLoading: controller.isLoading.value,
                          isFullWidth: true,
                          height: 48,
                          onPressed: controller.isLoading.value ? null : () => controller.resetPassword(),
                        )),
                    const SizedBox(height: 20),

                    // Back to Login Link
                    Center(
                      child: TextButton(
                        onPressed: () => Get.offAllNamed(AppRoutes.login),
                        child: Text(
                          'Back to Login',
                          style: AppTextStyles.body2.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                          ),
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
