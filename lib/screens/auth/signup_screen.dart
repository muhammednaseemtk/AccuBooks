import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/auth_controller.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import 'widgets/country_picker_dialog.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameFocusNode = FocusNode();
  final _companyFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _createButtonFocusNode = FocusNode();

  @override
  void dispose() {
    _fullNameFocusNode.dispose();
    _companyFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _createButtonFocusNode.dispose();
    super.dispose();
  }

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
              constraints: const BoxConstraints(maxWidth: 520),
              child: AppCard(
                padding: EdgeInsets.all(cardPadding),
                borderRadius: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // AccuBooks Branding Header
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: 52,
                              height: 52,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'AccuBooks',
                            style: AppTextStyles.h1.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'LOCAL ACCOUNTING',
                            style: AppTextStyles.caption.copyWith(
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Create your account',
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Register to start managing your company books in the cloud',
                      style: AppTextStyles.body2.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full Name Field
                    AppTextField(
                      label: 'Full Name',
                      hint: 'Full Name',
                      controller: controller.signupFullNameController,
                      focusNode: _fullNameFocusNode,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      isRequired: true,
                      onSubmitted: (_) => _companyFocusNode.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Company / Organization Name
                    AppTextField(
                      label: 'Company Name',
                      hint: 'ABC Traders Ltd.',
                      controller: controller.signupCompanyController,
                      focusNode: _companyFocusNode,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.business_outlined, size: 20),
                      isRequired: true,
                      onSubmitted: (_) => _emailFocusNode.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    AppTextField(
                      label: 'Email',
                      hint: 'Email',
                      controller: controller.signupEmailController,
                      focusNode: _emailFocusNode,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      isRequired: true,
                      onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Phone Number Field with Country Selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: 'Phone Number',
                            style: AppTextStyles.subtitle2.copyWith(
                              fontSize: 13,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            children: const [
                              TextSpan(
                                text: ' *',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 360;

                            final countrySelector = Obx(() {
                              final country = controller.signupCountry.value;
                              return InkWell(
                                onTap: () => showCountryPickerDialog(
                                  context,
                                  selectedCountry: country,
                                  onSelected: (selected) {
                                    controller.signupCountry.value = selected;
                                  },
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                    ),
                                  ),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            country.flag,
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            country.dialCode,
                                            style: AppTextStyles.body1.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.arrow_drop_down_rounded,
                                            size: 20,
                                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            });

                            final phoneField = Obx(() {
                              final country = controller.signupCountry.value;
                              return AppTextField(
                                hint: country.sampleNumber,
                                controller: controller.signupPhoneController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                                validator: (val) {
                                  if (val == null || val.isEmpty || !country.isValid(val)) {
                                    return 'Enter a valid phone number';
                                  }
                                  return null;
                                },
                              );
                            });

                            if (isCompact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  countrySelector,
                                  const SizedBox(height: 8),
                                  phoneField,
                                ],
                              );
                            } else {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 130,
                                    child: countrySelector,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: phoneField,
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    Obx(() => AppTextField(
                          label: 'Password',
                          hint: 'Min 8 chars, 1 uppercase, 1 lowercase, 1 number',
                          controller: controller.signupPasswordController,
                          focusNode: _passwordFocusNode,
                          textInputAction: TextInputAction.done,
                          obscureText: controller.signupObscurePassword.value,
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          isRequired: true,
                          suffixIcon: IconButton(
                            icon: Icon(
                              controller.signupObscurePassword.value
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                            onPressed: () => controller.signupObscurePassword.toggle(),
                            tooltip: controller.signupObscurePassword.value ? 'Show password' : 'Hide password',
                          ),
                          onSubmitted: (_) => _createButtonFocusNode.requestFocus(),
                        )),
                    const SizedBox(height: 28),

                    // Submit Button
                    Obx(() => AppButton(
                          focusNode: _createButtonFocusNode,
                          text: controller.isLoading.value ? 'Creating Account...' : 'Create Account',
                          icon: controller.isLoading.value ? null : Icons.arrow_forward_rounded,
                          isLoading: controller.isLoading.value,
                          isFullWidth: true,
                          height: 48,
                          onPressed: controller.isLoading.value ? null : () => controller.signup(),
                        )),
                    const SizedBox(height: 20),

                    // Login Link
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Already have an account?',
                          style: AppTextStyles.body2.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Get.toNamed(AppRoutes.login),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Login',
                            style: AppTextStyles.body2.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
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
