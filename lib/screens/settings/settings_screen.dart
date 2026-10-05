import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../controllers/settings_controller.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/loading_widget.dart';
import '../../models/company_model.dart';
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

        final comp = controller.company.value;

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
                  _buildCompanySection(context, controller, comp, theme),
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
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
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

  Widget _buildCompanySection(
    BuildContext context,
    SettingsController controller,
    CompanyModel? comp,
    ThemeData theme,
  ) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.business_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Company Information',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                AppButton(
                  text: 'Edit Company',
                  icon: Icons.edit_outlined,
                  type: AppButtonType.secondary,
                  onPressed: () => _showEditCompanyDialog(context, controller, comp),
                ),
              ],
            ),
            const Divider(height: 24),
            if (comp == null)
              const Text('No company profile found')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 650;
                  return Wrap(
                    spacing: 32,
                    runSpacing: 16,
                    children: [
                      _buildInfoTile('Company Name', comp.name, isWide),
                      _buildInfoTile('Tax / GST Number', comp.taxNumber?.isNotEmpty == true ? comp.taxNumber! : 'N/A', isWide),
                      _buildInfoTile('Phone', comp.phone?.isNotEmpty == true ? comp.phone! : 'N/A', isWide),
                      _buildInfoTile('Email', comp.email?.isNotEmpty == true ? comp.email! : 'N/A', isWide),
                      _buildInfoTile('Address', comp.address?.isNotEmpty == true ? comp.address! : 'N/A', isWide),
                      _buildInfoTile('Currency Symbol', comp.currency, isWide),
                      _buildInfoTile(
                        'Financial Year Start',
                        comp.financialYearStart != null ? AppDateUtils.formatDisplay(comp.financialYearStart!) : '01-04-2026',
                        isWide,
                      ),
                      _buildInfoTile(
                        'Financial Year End',
                        comp.financialYearEnd != null ? AppDateUtils.formatDisplay(comp.financialYearEnd!) : '31-03-2027',
                        isWide,
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, bool isWide) {
    return SizedBox(
      width: isWide ? 220 : double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
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
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Database Engine: SQLite FFI (100% Local)',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Path: ${info['path'] ?? 'Local Database'}',
                    style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Size: ${info['size'] ?? '0 KB'}   •   Modified: ${info['lastModified'] ?? 'N/A'}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
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
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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

  void _showEditCompanyDialog(
    BuildContext context,
    SettingsController controller,
    CompanyModel? comp,
  ) {
    final nameCtrl = TextEditingController(text: comp?.name ?? '');
    final taxCtrl = TextEditingController(text: comp?.taxNumber ?? '');
    final phoneCtrl = TextEditingController(text: comp?.phone ?? '');
    final emailCtrl = TextEditingController(text: comp?.email ?? '');
    final addrCtrl = TextEditingController(text: comp?.address ?? '');
    final currCtrl = TextEditingController(text: comp?.currency ?? '₹');

    AppDialog.showFormDialog(
      context: context,
      title: 'Edit Company Profile',
      confirmText: 'Save Changes',
      content: SingleChildScrollView(
        child: Column(
          children: [
            AppTextField(
              label: 'Company Name',
              controller: nameCtrl,
              prefixIcon: const Icon(Icons.business_outlined),
              isRequired: true,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'GST / Tax Number',
              controller: taxCtrl,
              prefixIcon: const Icon(Icons.numbers_outlined),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Phone Number',
              controller: phoneCtrl,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Email Address',
              controller: emailCtrl,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Business Address',
              controller: addrCtrl,
              prefixIcon: const Icon(Icons.location_on_outlined),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Currency Symbol',
              controller: currCtrl,
              prefixIcon: const Icon(Icons.currency_rupee_outlined),
            ),
          ],
        ),
      ),
      onConfirm: () async {
        if (nameCtrl.text.trim().isEmpty) return;
        final updated = (comp ?? CompanyModel(name: nameCtrl.text.trim())).copyWith(
          name: nameCtrl.text.trim(),
          taxNumber: taxCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          address: addrCtrl.text.trim(),
          currency: currCtrl.text.trim(),
          updatedAt: DateTime.now(),
        );
        await controller.updateCompany(updated);
      },
    );
  }
}
