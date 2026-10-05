import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/account_controller.dart';
import '../../core/constants/accounting_constants.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_table.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_widget.dart';
import '../../models/account_model.dart';
import '../navigation/app_scaffold.dart';

class AccountsScreen extends GetView<AccountController> {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Chart of Accounts',
      currentRoute: AppRoutes.accounts,
      actions: [
        AppButton(
          label: 'New Account',
          icon: Icons.add,
          onPressed: () => _showAccountFormDialog(context),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Search and Type Filter Bar
            AppCard(
              padding: const EdgeInsets.all(12),
              child: ResponsiveRowColumn(
                spacing: 12,
                children: [
                  AppTextField(
                    hint: 'Search by account name or code...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    onChanged: controller.setSearch,
                  ),
                  Obx(() => AppDropdown<String>(
                        value: controller.selectedTypeFilter.value,
                        items: ['All', ...AccountingConstants.accountTypes].map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (val) => controller.setTypeFilter(val ?? 'All'),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Accounts Table
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoadingWidget(message: 'Loading chart of accounts...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return ErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.loadAccounts,
                  );
                }

                if (controller.accounts.isEmpty) {
                  return EmptyState(
                    title: 'No accounts found',
                    subtitle: 'Create a new account or change your search filter.',
                    actionLabel: 'Create Account',
                    onAction: () => _showAccountFormDialog(context),
                  );
                }

                final columns = [
                  const AppTableColumn(title: 'Code', width: 90),
                  const AppTableColumn(title: 'Account Name'),
                  const AppTableColumn(title: 'Type', width: 120),
                  const AppTableColumn(title: 'Balance', width: 150, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Status', width: 100, alignment: Alignment.center),
                  const AppTableColumn(title: 'Actions', width: 120, alignment: Alignment.centerRight),
                ];

                final rows = controller.accounts.map((acc) {
                  final balance = acc.currentBalance ?? 0.0;
                  final isPositive = balance >= 0;

                  return [
                    Text(acc.accountCode, style: AppTextStyles.tableCellBold),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            acc.accountName,
                            style: AppTextStyles.tableCellBold,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (acc.isSystemAccount) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SYSTEM',
                              style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(acc.accountType, style: AppTextStyles.tableCell),
                    Text(
                      CurrencyUtils.format(balance),
                      style: AppTextStyles.tableCellBold.copyWith(
                        color: isPositive ? AppColors.credit : AppColors.debit,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: acc.isActive ? AppColors.credit.withValues(alpha: 0.1) : AppColors.debit.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        acc.isActive ? 'Active' : 'Inactive',
                        style: AppTextStyles.caption.copyWith(
                          color: acc.isActive ? AppColors.credit : AppColors.debit,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.list_alt, size: 18),
                          tooltip: 'Ledger History',
                          splashRadius: 16,
                          onPressed: () => _showAccountLedgerDialog(context, acc),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Account',
                          splashRadius: 16,
                          onPressed: () => _showAccountFormDialog(context, account: acc),
                        ),
                      ],
                    ),
                  ];
                }).toList();

                return AppCard(
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    child: AppTable(
                      columns: columns,
                      rows: rows,
                      minWidth: 780,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountFormDialog(BuildContext context, {AccountModel? account}) {
    final isEdit = account != null;
    final codeCtrl = TextEditingController(text: account?.accountCode ?? '');
    final nameCtrl = TextEditingController(text: account?.accountName ?? '');
    final openingCtrl = TextEditingController(text: account?.openingBalance.toString() ?? '0');
    final selectedType = (account?.accountType ?? AccountingConstants.typeAsset).obs;
    final selectedObType = (account?.openingBalanceType ?? AccountingConstants.balanceDebit).obs;
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AppDialog(
        title: isEdit ? 'Edit Account' : 'New Account',
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResponsiveRowColumn(
                children: [
                  AppTextField(
                    label: 'Account Code',
                    hint: 'e.g. 1040',
                    controller: codeCtrl,
                    readOnly: isEdit && account.isSystemAccount,
                    validator: (v) => v == null || v.isEmpty ? 'Code required' : null,
                  ),
                  Obx(() => AppDropdown<String>(
                        label: 'Account Type',
                        value: selectedType.value,
                        items: AccountingConstants.accountTypes.map((t) {
                          return DropdownMenuItem(value: t, child: Text(t));
                        }).toList(),
                        onChanged: (v) => selectedType.value = v ?? AccountingConstants.typeAsset,
                      )),
                ],
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Account Name',
                hint: 'e.g. Petty Cash / Office Rent',
                controller: nameCtrl,
                validator: (v) => v == null || v.isEmpty ? 'Name required' : null,
              ),
              if (!isEdit) ...[
                const SizedBox(height: 14),
                ResponsiveRowColumn(
                  children: [
                    AppTextField(
                      label: 'Opening Balance',
                      hint: '0.00',
                      controller: openingCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    Obx(() => AppDropdown<String>(
                          label: 'Balance Type',
                          value: selectedObType.value,
                          items: const [
                            DropdownMenuItem(value: AccountingConstants.balanceDebit, child: Text('Debit')),
                            DropdownMenuItem(value: AccountingConstants.balanceCredit, child: Text('Credit')),
                          ],
                          onChanged: (v) => selectedObType.value = v ?? AccountingConstants.balanceDebit,
                        )),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            type: AppButtonType.text,
            onPressed: () => Get.back(),
          ),
          Obx(() => AppButton(
                label: isEdit ? 'Update' : 'Create',
                isLoading: controller.isSubmitting.value,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final opVal = double.tryParse(openingCtrl.text.replaceAll(',', '')) ?? 0.0;
                  final acc = AccountModel(
                    id: account?.id,
                    accountCode: codeCtrl.text.trim(),
                    accountName: nameCtrl.text.trim(),
                    accountType: selectedType.value,
                    openingBalance: opVal,
                    openingBalanceType: selectedObType.value,
                    isSystemAccount: account?.isSystemAccount ?? false,
                  );

                  final ok = await controller.saveAccount(acc);
                  if (ok) Get.back();
                },
              )),
        ],
      ),
    );
  }

  void _showAccountLedgerDialog(BuildContext context, AccountModel account) {
    controller.loadAccountLedger(account);

    Get.dialog(
      AppDialog(
        title: '${account.accountName} - General Ledger',
        maxWidth: 850,
        content: Obx(() {
          if (controller.isLoadingLedger.value) {
            return const LoadingWidget(message: 'Loading ledger...');
          }

          if (controller.accountLedger.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No journal transactions recorded for this account.')),
            );
          }

          final columns = [
            const AppTableColumn(title: 'Date', width: 100),
            const AppTableColumn(title: 'Transaction #', width: 130),
            const AppTableColumn(title: 'Type', width: 100),
            const AppTableColumn(title: 'Description'),
            const AppTableColumn(title: 'Debit', width: 110, alignment: Alignment.centerRight),
            const AppTableColumn(title: 'Credit', width: 110, alignment: Alignment.centerRight),
          ];

          final rows = controller.accountLedger.map((row) {
            final debit = (row['debit'] as num).toDouble();
            final credit = (row['credit'] as num).toDouble();

            return [
              Text(row['transaction_date']?.toString().split(' ').first ?? '', style: AppTextStyles.tableCell),
              Text(row['transaction_number'] ?? '', style: AppTextStyles.tableCellBold),
              Text(row['transaction_type'] ?? '', style: AppTextStyles.tableCell),
              Text(row['line_description'] ?? row['entry_description'] ?? '', style: AppTextStyles.tableCell),
              Text(debit > 0 ? CurrencyUtils.format(debit) : '-', style: AppTextStyles.tableCell),
              Text(credit > 0 ? CurrencyUtils.format(credit) : '-', style: AppTextStyles.tableCell),
            ];
          }).toList();

          return AppTable(columns: columns, rows: rows, minWidth: 700);
        }),
      ),
    );
  }
}
