import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import 'app_button.dart';

class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final double? maxHeight;
  final Widget? leadingIcon;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.maxWidth = 720.0,
    this.maxHeight,
    this.leadingIcon,
  });

  static Future<bool?> confirm({
    BuildContext? context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
    VoidCallback? onConfirm,
  }) {
    final ctx = context ?? Get.overlayContext ?? Get.context;
    if (ctx == null) return Future.value(false);
    return showConfirmation(
      context: ctx,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: isDestructive,
      onConfirm: onConfirm,
    );
  }

  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
    VoidCallback? onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: title,
        maxWidth: 480,
        content: Text(message, style: AppTextStyles.body1),
        actions: [
          AppButton(
            text: cancelText,
            type: AppButtonType.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            text: confirmText,
            type: isDestructive ? AppButtonType.danger : AppButtonType.primary,
            onPressed: () {
              Navigator.of(ctx).pop(true);
              onConfirm?.call();
            },
          ),
        ],
      ),
    );
  }

  static Future<void> showFormDialog({
    required BuildContext context,
    required String title,
    required Widget content,
    String confirmText = 'Save',
    String cancelText = 'Cancel',
    double maxWidth = 600,
    required Future<void> Function() onConfirm,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: title,
        maxWidth: maxWidth,
        content: content,
        actions: [
          AppButton(
            text: cancelText,
            type: AppButtonType.secondary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AppButton(
            text: confirmText,
            type: AppButtonType.primary,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await onConfirm();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final availableWidth = (screenWidth - 32).clamp(150.0, double.infinity);
    final availableHeight = (screenHeight - 48).clamp(150.0, double.infinity);
    final effectiveMaxHeight = (maxHeight ?? (screenHeight * 0.88)).clamp(150.0, availableHeight);
    final effectiveMaxWidth = maxWidth.clamp(150.0, availableWidth);

    return Dialog(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: effectiveMaxWidth,
          maxHeight: effectiveMaxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (leadingIcon != null) ...[
                    leadingIcon!,
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.h3.copyWith(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                    tooltip: 'Close (Esc)',
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: content,
              ),
            ),

            // Dialog Actions
            if (actions != null && actions!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                      : AppColors.surfaceVariantLight.withValues(alpha: 0.5),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
