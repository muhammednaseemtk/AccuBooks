import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/receipt_controller.dart';
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
import '../../models/customer_model.dart';
import '../../models/receipt_model.dart';
import '../navigation/app_scaffold.dart';

class ReceiptsScreen extends GetView<ReceiptController> {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Customer Receipts',
      currentRoute: AppRoutes.receipts,
      actions: [
        AppButton(
          label: 'New Receipt',
          icon: Icons.add,
          onPressed: () => _showReceiptFormDialog(context),
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
                    hint: 'Search by receipt # or customer...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    onChanged: controller.setSearch,
                  ),
                  Obx(() => AppDropdown<int>(
                        value: controller.selectedCustomerId.value,
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('All Customers')),
                          ...controller.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (v) => controller.setCustomerFilter(v ?? 0),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Receipts Table
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoadingWidget(message: 'Loading receipts...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return ErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.loadReceipts,
                  );
                }

                if (controller.receipts.isEmpty) {
                  return EmptyState(
                    title: 'No receipts recorded',
                    subtitle: 'Record payments received from customers to settle invoices.',
                    actionLabel: 'New Receipt',
                    onAction: () => _showReceiptFormDialog(context),
                  );
                }

                final columns = [
                  const AppTableColumn(title: 'Receipt #', width: 110),
                  const AppTableColumn(title: 'Date', width: 95),
                  const AppTableColumn(title: 'Customer Name'),
                  const AppTableColumn(title: 'Deposited To', width: 150),
                  const AppTableColumn(title: 'Method', width: 90),
                  const AppTableColumn(title: 'Amount Received', width: 140, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Actions', width: 80, alignment: Alignment.centerRight),
                ];

                final rows = controller.receipts.map((r) {
                  return [
                    Text(r.receiptNumber, style: AppTextStyles.tableCellBold),
                    Text(AppDateUtils.format(r.receiptDate), style: AppTextStyles.tableCell),
                    Text(r.customerName ?? 'Customer', style: AppTextStyles.tableCellBold),
                    Text(r.accountName ?? 'Cash/Bank', style: AppTextStyles.tableCell),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(r.paymentMethod, style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
                    ),
                    Text(
                      CurrencyUtils.format(r.amount),
                      style: AppTextStyles.tableCellBold.copyWith(color: AppColors.credit),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debit),
                      tooltip: 'Delete Receipt',
                      splashRadius: 16,
                      onPressed: () => _confirmDeleteReceipt(context, r),
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

  void _showReceiptFormDialog(BuildContext context) {
    controller.prepareNewReceiptForm();
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AppDialog(
        title: 'New Customer Receipt',
        maxWidth: 600,
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
                        label: 'Receipt #',
                        initialValue: controller.formNextReceiptNumber.value,
                        readOnly: true,
                      )),
                  Obx(() => AppTextField(
                        label: 'Date',
                        initialValue: AppDateUtils.format(controller.formReceiptDate.value),
                        readOnly: true,
                      )),
                ],
              ),
              const SizedBox(height: 12),
              Obx(() => AppDropdown<CustomerModel>(
                    label: 'Customer *',
                    hint: 'Select Customer',
                    value: controller.formSelectedCustomer.value,
                    items: controller.customers.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text('${c.name} (Due: ${CurrencyUtils.format(c.outstandingBalance)})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (c) {
                      controller.formSelectedCustomer.value = c;
                      if (c != null && c.outstandingBalance > 0) {
                        amountCtrl.text = c.outstandingBalance.toString();
                        controller.formAmount.value = c.outstandingBalance;
                      }
                    },
                  )),
              const SizedBox(height: 12),
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 480,
                children: [
                  Obx(() => AppDropdown<AccountModel>(
                        label: 'Deposit To (Account) *',
                        value: controller.formSelectedAccount.value,
                        items: controller.bankCashAccounts.map((a) {
                          return DropdownMenuItem(value: a, child: Text(a.accountName));
                        }).toList(),
                        onChanged: (a) => controller.formSelectedAccount.value = a,
                      )),
                  Obx(() => AppDropdown<String>(
                        label: 'Payment Method',
                        value: controller.formPaymentMethod.value,
                        items: AccountingConstants.paymentMethods.map((m) {
                          return DropdownMenuItem(value: m, child: Text(m));
                        }).toList(),
                        onChanged: (m) => controller.formPaymentMethod.value = m ?? 'Cash',
                      )),
                ],
              ),
              const SizedBox(height: 12),
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 480,
                children: [
                  AppTextField(
                    label: 'Amount (₹) *',
                    hint: '0.00',
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [AppInputFormatters.decimal()],
                    validator: (v) => double.tryParse(v ?? '') == null ? 'Valid amount required' : null,
                    onChanged: (v) => controller.formAmount.value = double.tryParse(v) ?? 0.0,
                  ),
                  AppTextField(
                    label: 'Cheque / Ref #',
                    controller: refCtrl,
                    onChanged: (v) => controller.formReference.value = v,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Notes',
                controller: notesCtrl,
                onChanged: (v) => controller.formNotes.value = v,
              ),
            ],
          ),
        ),
        actions: [
          AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Get.back()),
          Obx(() => AppButton(
                label: 'Save Receipt',
                isLoading: controller.isSubmitting.value,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final ok = await controller.submitReceipt();
                  if (ok) Get.back();
                },
              )),
        ],
      ),
    );
  }

  void _confirmDeleteReceipt(BuildContext context, ReceiptModel receipt) {
    Get.dialog(
      AppDialog(
        title: 'Delete Receipt #${receipt.receiptNumber}?',
        maxWidth: 440,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete receipt #${receipt.receiptNumber} (${CurrencyUtils.format(receipt.amount)}) from ${receipt.customerName ?? 'Customer'}?',
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 8),
            const Text(
              'Deleting this receipt will reverse the customer balance payment and associated journal entries.',
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
              await controller.deleteReceipt(receipt);
            },
          ),
        ],
      ),
    );
  }
}
