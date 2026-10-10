import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

enum AppButtonType { primary, secondary, outline, text, danger }

class AppButton extends StatelessWidget {
  final String? label;
  final String? text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;
  final double height;
  final FocusNode? focusNode;

  const AppButton({
    super.key,
    this.label,
    this.text,
    this.onPressed,
    this.icon,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
    this.height = 42,
    this.focusNode,
  });

  String get effectiveLabel => label ?? text ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget child;
    if (isLoading) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          if (effectiveLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                effectiveLabel,
                style: AppTextStyles.button,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Flexible(child: Text(effectiveLabel, style: AppTextStyles.button, overflow: TextOverflow.ellipsis)),
        ],
      );
    } else {
      child = Text(effectiveLabel, style: AppTextStyles.button, overflow: TextOverflow.ellipsis);
    }

    Widget button;
    switch (type) {
      case AppButtonType.primary:
        button = ElevatedButton(
          focusNode: focusNode,
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: Size(width ?? (isFullWidth ? double.infinity : 80), height),
          ),
          child: child,
        );
        break;

      case AppButtonType.secondary:
        button = ElevatedButton(
          focusNode: focusNode,
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
            foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            minimumSize: Size(width ?? (isFullWidth ? double.infinity : 80), height),
          ),
          child: child,
        );
        break;

      case AppButtonType.outline:
        button = OutlinedButton(
          focusNode: focusNode,
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
            side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            minimumSize: Size(width ?? (isFullWidth ? double.infinity : 80), height),
          ),
          child: child,
        );
        break;

      case AppButtonType.danger:
        button = ElevatedButton(
          focusNode: focusNode,
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.debit,
            foregroundColor: Colors.white,
            minimumSize: Size(width ?? (isFullWidth ? double.infinity : 80), height),
          ),
          child: child,
        );
        break;

      case AppButtonType.text:
        button = TextButton(
          focusNode: focusNode,
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size(width ?? (isFullWidth ? double.infinity : 60), height),
          ),
          child: child,
        );
        break;
    }

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
