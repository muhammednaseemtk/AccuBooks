import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/expense_controller.dart';
import '../../core/constants/accounting_constants.dart';
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
import '../../models/expense_model.dart';
import '../navigation/app_scaffold.dart';

class ExpensesScreen extends GetView<ExpenseController> {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Expenses',
      currentRoute: AppRoutes.expenses,
      actions: [
        AppButton(
          label: 'Record Expense',
          icon: Icons.add,
          onPressed: () => _showExpenseFormDialog(context),
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
                    hint: 'Search...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    onChanged: controller.setSearch,
                  ),
                  Obx(() => AppDropdown<int>(
                        value: controller.selectedAccountId.value,
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('All Expense Accounts')),
                          ...controller.expenseAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.accountName))),
                        ],
                        onChanged: (v) => controller.setAccountFilter(v ?? 0),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Expenses Table
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoadingWidget(message: 'Loading expenses...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return ErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.loadExpenses,
                  );
                }

                if (controller.expenses.isEmpty) {
                  return EmptyState(
                    title: 'No expenses recorded',
                    subtitle: 'Track rent, utility bills, salaries, and operational costs.',
                    actionLabel: 'Record Expense',
                    onAction: () => _showExpenseFormDialog(context),
                  );
                }

                final columns = [
                  const AppTableColumn(title: 'Expense #', width: 110),
                  const AppTableColumn(title: 'Date', width: 95),
                  const AppTableColumn(title: 'Expense Category'),
                  const AppTableColumn(title: 'Description'),
                  const AppTableColumn(title: 'Paid Via', width: 140),
                  const AppTableColumn(title: 'Amount', width: 130, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Actions', width: 100, alignment: Alignment.centerRight),
                ];

                final rows = controller.expenses.map((e) {
                  return [
                    Text(e.expenseNumber, style: AppTextStyles.tableCellBold),
                    Text(AppDateUtils.format(e.expenseDate), style: AppTextStyles.tableCell),
                    Text(e.expenseAccountName ?? 'Expense', style: AppTextStyles.tableCellBold),
                    Text(e.description ?? '-', style: AppTextStyles.tableCell),
                    Text(e.paymentAccountName ?? e.paymentMethod, style: AppTextStyles.tableCell),
                    Text(
                      CurrencyUtils.format(e.amount + e.taxAmount),
                      style: AppTextStyles.tableCellBold.copyWith(color: AppColors.debit),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                          tooltip: 'Edit Expense',
                          splashRadius: 16,
                          onPressed: () => _showExpenseFormDialog(context, expense: e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debit),
                          tooltip: 'Delete Expense',
                          splashRadius: 16,
                          onPressed: () => _confirmDeleteExpense(context, e),
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
                      minWidth: 720,
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

  void _showExpenseFormDialog(BuildContext context, {ExpenseModel? expense}) async {
    final isEdit = expense != null;
    if (isEdit) {
      await controller.prepareEditExpenseForm(expense);
    } else {
      await controller.prepareNewExpenseForm();
    }
    final amountCtrl = TextEditingController(text: isEdit ? expense.amount.toString() : '');
    final taxCtrl = TextEditingController(text: isEdit ? expense.taxAmount.toString() : '0');
    final descCtrl = TextEditingController(text: isEdit ? (expense.description ?? '') : '');
    final refCtrl = TextEditingController(text: isEdit ? (expense.reference ?? '') : '');
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AppDialog(
        title: isEdit ? 'Edit Business Expense' : 'Record Business Expense',
        maxWidth: 620,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 480,
                children: [
                  Obx(() => AppTextField(
                        key: ValueKey('exp_${controller.formNextExpenseNumber.value}'),
                        label: 'Expense #',
                        hint: 'Reference Number',
                        initialValue: controller.formNextExpenseNumber.value,
                        readOnly: true,
                      )),
                  Obx(() => AppDatePickerField(
                        label: 'Expense Date',
                        hint: 'Select date',
                        value: controller.formExpenseDate.value,
                        onDateSelected: (d) => controller.formExpenseDate.value = d,
                      )),
                ],
              ),
              const SizedBox(height: 12),
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 480,
                children: [
                  Obx(() => AppDropdown<AccountModel>(
                        label: 'Expense Account *',
                        hint: 'Select Account',
                        value: controller.formSelectedExpenseAccount.value,
                        items: controller.expenseAccounts.map((a) {
                          return DropdownMenuItem(value: a, child: Text(a.accountName));
                        }).toList(),
                        onChanged: (a) => controller.formSelectedExpenseAccount.value = a,
                      )),
                  Obx(() => AppDropdown<AccountModel>(
                        label: 'Payment Account (Cash/Bank) *',
                        hint: 'Select Account',
                        value: controller.formSelectedPaymentAccount.value,
                        items: controller.paymentAccounts.map((a) {
                          return DropdownMenuItem(value: a, child: Text(a.accountName));
                        }).toList(),
                        onChanged: (a) => controller.formSelectedPaymentAccount.value = a,
                      )),
                ],
              ),
              const SizedBox(height: 12),
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 480,
                children: [
                  AppTextField(
                    label: 'Expense Amount (₹) *',
                    hint: 'Amount',
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [AppInputFormatters.decimal()],
                    validator: (v) => double.tryParse(v ?? '') == null ? 'Valid amount required' : null,
                    onChanged: (v) => controller.formAmount.value = double.tryParse(v) ?? 0.0,
                  ),
                  AppTextField(
                    label: 'Tax (₹)',
                    hint: 'Tax',
                    controller: taxCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [AppInputFormatters.decimal()],
                    onChanged: (v) => controller.formTaxAmount.value = double.tryParse(v) ?? 0.0,
                  ),
                  Obx(() => AppDropdown<String>(
                        label: 'Method',
                        hint: 'Select Payment Method',
                        value: controller.formPaymentMethod.value,
                        items: AccountingConstants.paymentMethods.map((m) {
                          return DropdownMenuItem(value: m, child: Text(m));
                        }).toList(),
                        onChanged: (m) => controller.formPaymentMethod.value = m ?? 'Cash',
                      )),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Description / Purpose *',
                hint: 'Description',
                controller: descCtrl,
                onChanged: (v) => controller.formDescription.value = v,
                validator: (v) => v == null || v.isEmpty ? 'Description required' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Receipt / Voucher / Ref #',
                hint: 'Reference Number',
                controller: refCtrl,
                onChanged: (v) => controller.formReference.value = v,
              ),
            ],
          ),
        ),
        actions: [
          AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Get.back()),
          Obx(() => AppButton(
                label: isEdit ? 'Update Expense' : 'Save Expense',
                isLoading: controller.isSubmitting.value,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final ok = await controller.submitExpense();
                  if (ok) {
                    if (isEdit) {
                      Get.back();
                    } else {
                      await controller.prepareNewExpenseForm();
                      amountCtrl.clear();
                      taxCtrl.clear();
                      descCtrl.clear();
                      refCtrl.clear();
                      formKey.currentState?.reset();
                    }
                  }
                },
              )),
        ],
      ),
    );
  }

  void _confirmDeleteExpense(BuildContext context, ExpenseModel expense) {
    Get.dialog(
      AppDialog(
        title: 'Delete Expense #${expense.expenseNumber}?',
        maxWidth: 440,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete expense #${expense.expenseNumber} (${CurrencyUtils.format(expense.amount + expense.taxAmount)}) for ${expense.expenseAccountName ?? 'Expense'}?',
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 8),
            const Text(
              'Deleting this expense will reverse the payment account deduction and associated journal entries.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        actions: [
          AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Get.back()),
          AppButton(
            label: 'Delete',
            type: AppButtonType.danger,
            icon: Icons.delete_outline,
            onPressed: () async {
              Get.back();
              await controller.deleteExpense(expense);
            },
          ),
        ],
      ),
    );
  }
}
