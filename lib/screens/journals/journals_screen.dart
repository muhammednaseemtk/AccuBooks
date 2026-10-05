import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/journal_controller.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
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
import '../../models/journal_entry_model.dart';
import '../navigation/app_scaffold.dart';

class JournalsScreen extends GetView<JournalController> {
  const JournalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Journal Entries',
      currentRoute: AppRoutes.journals,
      actions: [
        AppButton(
          label: 'New Journal Entry',
          icon: Icons.add,
          onPressed: () => _showJournalEntryDialog(context),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Filter Bar
            AppCard(
              padding: const EdgeInsets.all(12),
              child: ResponsiveRowColumn(
                spacing: 12,
                children: [
                  AppTextField(
                    hint: 'Search by transaction # or description...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    onChanged: controller.setSearch,
                  ),
                  Obx(() => AppDropdown<String>(
                        value: controller.selectedType.value,
                        items: ['All', 'Journal', 'Sales', 'Purchase', 'Receipt', 'Payment', 'Expense', 'Opening Balance']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) => controller.setTypeFilter(v ?? 'All'),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Journal Entries Table
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoadingWidget(message: 'Loading journal entries...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return ErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.loadJournalEntries,
                  );
                }

                if (controller.journalEntries.isEmpty) {
                  return EmptyState(
                    title: 'No journal entries found',
                    subtitle: 'Post adjusting or manual double-entry vouchers.',
                    actionLabel: 'New Journal Entry',
                    onAction: () => _showJournalEntryDialog(context),
                  );
                }

                final columns = [
                  const AppTableColumn(title: 'Voucher #', width: 140),
                  const AppTableColumn(title: 'Date', width: 95),
                  const AppTableColumn(title: 'Type', width: 110),
                  const AppTableColumn(title: 'Description'),
                  const AppTableColumn(title: 'Total Amount', width: 130, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Actions', width: 90, alignment: Alignment.centerRight),
                ];

                final rows = controller.journalEntries.map((j) {
                  return [
                    Text(j.transactionNumber, style: AppTextStyles.tableCellBold),
                    Text(AppDateUtils.format(j.transactionDate), style: AppTextStyles.tableCell),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(j.transactionType, style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
                    ),
                    Text(j.description ?? '-', style: AppTextStyles.tableCell),
                    Text(
                      CurrencyUtils.format(j.totalDebit),
                      style: AppTextStyles.tableCellBold,
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      tooltip: 'View Journal Lines',
                      splashRadius: 16,
                      onPressed: () => _showJournalDetailsDialog(context, j),
                    ),
                  ];
                }).toList();

                return AppCard(
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    child: AppTable(
                      columns: columns,
                      rows: rows,
                      minWidth: 750,
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

  void _showJournalEntryDialog(BuildContext context) {
    controller.prepareNewJournalForm();

    Get.dialog(
      AppDialog(
        title: 'New Double-Entry Journal Voucher',
        maxWidth: 880,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveRowColumn(
              spacing: 12,
              breakpoint: 480,
              children: [
                Obx(() => AppTextField(
                      label: 'Voucher #',
                      initialValue: controller.formNextNumber.value,
                      readOnly: true,
                    )),
                Obx(() => AppTextField(
                      label: 'Date',
                      initialValue: AppDateUtils.format(controller.formDate.value),
                      readOnly: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: controller.formDate.value,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) controller.formDate.value = picked;
                        },
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Narration / Description *',
              hint: 'Describe transaction or adjusting entry reason...',
              onChanged: (v) => controller.formDescription.value = v,
            ),
            const SizedBox(height: 16),

            // Journal Lines
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Journal Lines (Debit must equal Credit):',
                    style: AppTextStyles.subtitle2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Line'),
                  onPressed: controller.addLine,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Obx(() => ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.formLines.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final line = controller.formLines[index];
                    final debitCtrl = TextEditingController(text: line.debit > 0 ? line.debit.toString() : '');
                    final creditCtrl = TextEditingController(text: line.credit > 0 ? line.credit.toString() : '');

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.surfaceVariantDark
                            : AppColors.surfaceVariantLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 500) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppDropdown<AccountModel>(
                                        value: line.account,
                                        hint: 'Select Account',
                                        items: controller.accounts.map((a) {
                                          return DropdownMenuItem(
                                            value: a,
                                            child: Text('${a.accountCode} - ${a.accountName}', overflow: TextOverflow.ellipsis),
                                          );
                                        }).toList(),
                                        onChanged: (a) => line.account = a,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      splashRadius: 16,
                                      onPressed: () => controller.removeLine(index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        hint: 'Debit',
                                        controller: debitCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (v) {
                                          line.debit = double.tryParse(v) ?? 0.0;
                                          if (line.debit > 0) {
                                            line.credit = 0.0;
                                            creditCtrl.text = '';
                                          }
                                          controller.formLines.refresh();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: AppTextField(
                                        hint: 'Credit',
                                        controller: creditCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (v) {
                                          line.credit = double.tryParse(v) ?? 0.0;
                                          if (line.credit > 0) {
                                            line.debit = 0.0;
                                            debitCtrl.text = '';
                                          }
                                          controller.formLines.refresh();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: AppDropdown<AccountModel>(
                                  value: line.account,
                                  hint: 'Select Account',
                                  items: controller.accounts.map((a) {
                                    return DropdownMenuItem(value: a, child: Text('${a.accountCode} - ${a.accountName}', overflow: TextOverflow.ellipsis));
                                  }).toList(),
                                  onChanged: (a) => line.account = a,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: AppTextField(
                                  hint: 'Debit',
                                  controller: debitCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) {
                                    line.debit = double.tryParse(v) ?? 0.0;
                                    if (line.debit > 0) {
                                      line.credit = 0.0;
                                      creditCtrl.text = '';
                                    }
                                    controller.formLines.refresh();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: AppTextField(
                                  hint: 'Credit',
                                  controller: creditCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) {
                                    line.credit = double.tryParse(v) ?? 0.0;
                                    if (line.credit > 0) {
                                      line.debit = 0.0;
                                      debitCtrl.text = '';
                                    }
                                    controller.formLines.refresh();
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                splashRadius: 16,
                                onPressed: () => controller.removeLine(index),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                )),

            const SizedBox(height: 16),

            // Live Balancing Verification Banner
            Obx(() {
              final debit = controller.formTotalDebit;
              final credit = controller.formTotalCredit;
              final diff = controller.formDifference;
              final isBalanced = controller.isFormBalanced;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isBalanced
                      ? AppColors.credit.withValues(alpha: 0.1)
                      : AppColors.debit.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isBalanced ? AppColors.credit : AppColors.debit,
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text('Total Debit: ${CurrencyUtils.format(debit)}', style: AppTextStyles.tableCellBold),
                    Text('Total Credit: ${CurrencyUtils.format(credit)}', style: AppTextStyles.tableCellBold),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBalanced ? Icons.check_circle : Icons.error_outline,
                          size: 18,
                          color: isBalanced ? AppColors.credit : AppColors.debit,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isBalanced ? 'Balanced' : 'Difference: ${CurrencyUtils.format(diff)}',
                          style: AppTextStyles.tableCellBold.copyWith(
                            color: isBalanced ? AppColors.credit : AppColors.debit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Get.back()),
          Obx(() => AppButton(
                label: 'Post Journal',
                isLoading: controller.isSubmitting.value,
                onPressed: controller.isFormBalanced
                    ? () async {
                        final ok = await controller.submitJournalEntry();
                        if (ok) Get.back();
                      }
                    : null,
              )),
        ],
      ),
    );
  }

  void _showJournalDetailsDialog(BuildContext context, JournalEntryModel entry) {
    Get.dialog(
      AppDialog(
        title: '${entry.transactionNumber} - ${entry.transactionType}',
        maxWidth: 700,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${AppDateUtils.format(entry.transactionDate)}', style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text('Description: ${entry.description ?? '-'}', style: AppTextStyles.subtitle2),
            const SizedBox(height: 16),
            AppTable(
              columns: const [
                AppTableColumn(title: 'Account Code', width: 110),
                AppTableColumn(title: 'Account Name'),
                AppTableColumn(title: 'Debit', width: 120, alignment: Alignment.centerRight),
                AppTableColumn(title: 'Credit', width: 120, alignment: Alignment.centerRight),
              ],
              rows: entry.lines.map((l) {
                return [
                  Text(l.accountCode ?? '', style: AppTextStyles.tableCell),
                  Text(l.accountName ?? '', style: AppTextStyles.tableCellBold),
                  Text(l.debit > 0 ? CurrencyUtils.format(l.debit) : '-', style: AppTextStyles.tableCell),
                  Text(l.credit > 0 ? CurrencyUtils.format(l.credit) : '-', style: AppTextStyles.tableCell),
                ];
              }).toList(),
              minWidth: 500,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text('Total Debit: ${CurrencyUtils.format(entry.totalDebit)}', style: AppTextStyles.tableCellBold),
                  Text('Total Credit: ${CurrencyUtils.format(entry.totalCredit)}', style: AppTextStyles.tableCellBold),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
