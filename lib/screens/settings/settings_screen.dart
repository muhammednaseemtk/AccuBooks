import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../controllers/settings_controller.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/loading_widget.dart';
import '../navigation/app_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Settings & Administration',
      currentRoute: AppRoutes.settings,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingWidget(message: 'Loading settings...');
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildThemeSection(context, controller, theme),
                  const SizedBox(height: 24),
                  _buildDatabaseSection(context, controller, theme),
                  const SizedBox(height: 24),
                  _buildAboutSection(context, theme),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildThemeSection(
    BuildContext context,
    SettingsController controller,
    ThemeData theme,
  ) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Appearance & Theme',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dark Theme',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Switch between sleek modern dark mode and light theme',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Obx(
                  () => Switch(
                    value: controller.isDarkMode.value,
                    onChanged: (val) => controller.toggleTheme(val),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseSection(
    BuildContext context,
    SettingsController controller,
    ThemeData theme,
  ) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Database & Backup Management',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Obx(() {
              final info = controller.dbInfo;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Path: ${info['path'] ?? 'Local Database'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Size: ${info['size'] ?? '0 KB'}   •   Modified: ${info['lastModified'] ?? 'N/A'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                AppButton(
                  text: 'Backup Database (.db)',
                  icon: Icons.backup_outlined,
                  onPressed: () => controller.createBackup(),
                ),
                AppButton(
                  text: 'Restore From Backup',
                  icon: Icons.restore_outlined,
                  type: AppButtonType.secondary,
                  onPressed: () => _confirmRestore(context, controller),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context, ThemeData theme) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'About AccuBooks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'AccuBooks - Desktop Accounting Application',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0 • Production Release',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'AccuBooks is a standalone, local-first double-entry accounting system designed for small and medium businesses. '
              'It provides real-time general ledgers, trial balance, profit & loss, balance sheet, inventory tracking with stock journals, and PDF invoicing without any cloud or internet dependency.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRestore(BuildContext context, SettingsController controller) {
    AppDialog.showConfirmation(
      context: context,
      title: 'Restore Database',
      message:
          'Restoring a database will replace your current accounting records with the selected backup file. Any changes made after the backup will be lost.\n\nAre you sure you want to proceed?',
      confirmText: 'Choose Backup File',
      isDestructive: true,
      onConfirm: () => controller.restoreBackup(),
    );
  }
}
