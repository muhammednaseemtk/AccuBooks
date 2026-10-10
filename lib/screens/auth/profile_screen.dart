import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/auth_controller.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../navigation/app_scaffold.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppScaffold(
      title: 'User Profile & Account',
      currentRoute: AppRoutes.profile,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Obx(() {
              final user = controller.currentUser;
              final org = controller.currentOrganization;
              final previewPath = controller.selectedImagePreviewPath.value;
              final isMarkedForRemoval = controller.isImageMarkedForRemoval.value;

              ImageProvider? imageProvider;
              if (previewPath != null && File(previewPath).existsSync()) {
                imageProvider = FileImage(File(previewPath));
              } else if (!isMarkedForRemoval &&
                  user?.profileImage != null &&
                  File(user!.profileImage!).existsSync()) {
                imageProvider = FileImage(File(user.profileImage!));
              }

              final hasImage = imageProvider != null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Overview Card
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 38,
                              backgroundColor: AppColors.primary,
                              backgroundImage: imageProvider,
                              child: hasImage
                                  ? null
                                  : Text(
                                      (user?.fullName.isNotEmpty ?? false)
                                          ? user!.fullName[0].toUpperCase()
                                          : 'U',
                                      style: AppTextStyles.h1.copyWith(
                                        color: Colors.white,
                                        fontSize: 28,
                                      ),
                                    ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => controller.pickProfileImage(),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? AppColors.surfaceDark : Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'User Profile',
                                style: AppTextStyles.h2.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? '',
                                style: AppTextStyles.body2.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.primaryLight.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      user?.roleDisplayName ?? 'Owner',
                                      style: AppTextStyles.caption.copyWith(
                                        color: isDark
                                            ? AppColors.primaryLight
                                            : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.surfaceVariantDark
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.business_rounded,
                                          size: 14,
                                          color: AppColors.secondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          org?.name ?? 'Company',
                                          style: AppTextStyles.caption.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(
                                      Icons.photo_library_outlined,
                                      size: 14,
                                    ),
                                    label: Text(
                                      hasImage ? 'Change Photo' : 'Select Photo',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () => controller.pickProfileImage(),
                                  ),
                                  if (hasImage)
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.delete_outline, size: 14),
                                      label: const Text(
                                        'Remove Photo',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () => controller.removeProfileImage(),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Editable Personal Information
                  AppCard(
                    title: 'Personal Information',
                    subtitle: controller.isEditingProfile.value
                        ? 'Modify your profile details and save changes'
                        : 'Your personal account details',
                    trailing: !controller.isEditingProfile.value
                        ? AppButton(
                            text: 'Edit Profile',
                            icon: Icons.edit_outlined,
                            type: AppButtonType.secondary,
                            onPressed: () => controller.startEditingProfile(),
                          )
                        : null,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: 'Full Name',
                          hint: 'Full Name',
                          controller: controller.profileNameController,
                          enabled: controller.isEditingProfile.value,
                          readOnly: !controller.isEditingProfile.value,
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Email',
                          hint: 'Email',
                          controller: controller.profileEmailController,
                          enabled: controller.isEditingProfile.value,
                          readOnly: !controller.isEditingProfile.value,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Phone Number',
                          hint: 'Phone Number',
                          controller: controller.profilePhoneController,
                          enabled: controller.isEditingProfile.value,
                          readOnly: !controller.isEditingProfile.value,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [AppInputFormatters.digitsOnly],
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        ),
                        const SizedBox(height: 24),
                        if (!controller.isEditingProfile.value)
                          Align(
                            alignment: Alignment.centerRight,
                            child: AppButton(
                              text: 'Edit Profile',
                              icon: Icons.edit_outlined,
                              onPressed: () => controller.startEditingProfile(),
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AppButton(
                                text: 'Cancel',
                                type: AppButtonType.secondary,
                                onPressed: () => controller.cancelEditingProfile(),
                              ),
                              const SizedBox(width: 12),
                              AppButton(
                                text: controller.isLoading.value
                                    ? 'Saving Changes...'
                                    : 'Save Changes',
                                icon: Icons.save_outlined,
                                isLoading: controller.isLoading.value,
                                onPressed: () => controller.updateProfile(),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Organization Details Card
                  AppCard(
                    title: 'Company & Multi-Tenant Details',
                    subtitle: 'SaaS tenant organization settings',
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Company Name', org?.name ?? 'N/A', isDark),
                        const Divider(height: 20),
                        _buildInfoRow('Organization ID', '#${user?.organizationId ?? 1}', isDark),
                        const Divider(height: 20),
                        _buildInfoRow('Assigned Role', user?.roleDisplayName ?? 'Owner', isDark),
                        const Divider(height: 20),
                        _buildInfoRow('Base Currency', org?.currency ?? '₹', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Danger / Session Zone: Logout
                  AppCard(
                    title: 'Account Session',
                    subtitle: 'Manage your active application session',
                    borderColor: Colors.red.withValues(alpha: 0.3),
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sign Out of AccuBooks',
                                style: AppTextStyles.subtitle2.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Securely terminate your current session on this device.',
                                style: AppTextStyles.caption.copyWith(
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        AppButton(
                          text: 'Logout',
                          icon: Icons.logout_rounded,
                          type: AppButtonType.danger,
                          onPressed: () => controller.confirmLogout(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body2.copyWith(
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
