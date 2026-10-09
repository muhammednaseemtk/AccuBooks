import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/payment_controller.dart';
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
import '../../models/payment_model.dart';
import '../../models/supplier_model.dart';
import '../navigation/app_scaffold.dart';

class PaymentsScreen extends GetView<PaymentController> {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Supplier Payments',
      currentRoute: AppRoutes.payments,
      actions: [
        AppButton(
          label: 'New Payment',
          icon: Icons.add,
          onPressed: () => _showPaymentFormDialog(context),
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
                    hint: 'Search by payment # or supplier...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    onChanged: controller.setSearch,
                  ),
                  Obx(() => AppDropdown<int>(
                        value: controller.selectedSupplierId.value,
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('All Suppliers')),
                          ...controller.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                        ],
                        onChanged: (v) => controller.setSupplierFilter(v ?? 0),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Payments Table
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoadingWidget(message: 'Loading payments...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return ErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.loadPayments,
                  );
                }

                if (controller.payments.isEmpty) {
                  return EmptyState(
                    title: 'No payments recorded',
                    subtitle: 'Record payments made to suppliers for bills and purchases.',
                    actionLabel: 'New Payment',
                    onAction: () => _showPaymentFormDialog(context),
                  );
                }

                final columns = [
                  const AppTableColumn(title: 'Payment #', width: 110),
                  const AppTableColumn(title: 'Date', width: 95),
                  const AppTableColumn(title: 'Supplier Name'),
                  const AppTableColumn(title: 'Paid From', width: 150),
                  const AppTableColumn(title: 'Method', width: 90),
                  const AppTableColumn(title: 'Amount Paid', width: 140, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Actions', width: 110, alignment: Alignment.centerRight),
                ];

                final rows = controller.payments.map((p) {
                  return [
                    Text(p.paymentNumber, style: AppTextStyles.tableCellBold),
                    Text(AppDateUtils.format(p.paymentDate), style: AppTextStyles.tableCell),
                    Text(p.supplierName ?? 'Supplier', style: AppTextStyles.tableCellBold),
                    Text(p.accountName ?? 'Cash/Bank', style: AppTextStyles.tableCell),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(p.paymentMethod, style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
                    ),
                    Text(
                      CurrencyUtils.format(p.amount),
                      style: AppTextStyles.tableCellBold.copyWith(color: AppColors.debit),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                          tooltip: 'Edit Payment',
                          splashRadius: 16,
                          onPressed: () => _showPaymentFormDialog(context, payment: p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debit),
                          tooltip: 'Delete Payment',
                          splashRadius: 16,
                          onPressed: () => _confirmDeletePayment(context, p),
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

  void _showPaymentFormDialog(BuildContext context, {PaymentModel? payment}) async {
    final isEdit = payment != null;
    if (isEdit) {
      await controller.prepareEditPaymentForm(payment);
    } else {
      await controller.prepareNewPaymentForm();
    }
    final amountCtrl = TextEditingController(text: isEdit ? payment.amount.toString() : '');
    final refCtrl = TextEditingController(text: isEdit ? (payment.reference ?? '') : '');
    final notesCtrl = TextEditingController(text: isEdit ? (payment.notes ?? '') : '');
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AppDialog(
        title: isEdit ? 'Edit Supplier Payment' : 'New Supplier Payment',
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
                        key: ValueKey('pmt_${controller.formNextPaymentNumber.value}'),
                        label: 'Payment #',
                        initialValue: controller.formNextPaymentNumber.value,
                        readOnly: true,
                      )),
                  Obx(() => AppDatePickerField(
                        label: 'Date',
                        value: controller.formPaymentDate.value,
                        onDateSelected: (d) => controller.formPaymentDate.value = d,
                      )),
                ],
              ),
              const SizedBox(height: 12),
              Obx(() => AppDropdown<SupplierModel>(
                    label: 'Supplier *',
                    hint: 'Select Supplier',
                    value: controller.formSelectedSupplier.value,
                    items: controller.suppliers.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text('${s.name} (Payable: ${CurrencyUtils.format(s.outstandingBalance)})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (s) {
                      controller.formSelectedSupplier.value = s;
                      if (!isEdit && s != null && s.outstandingBalance > 0) {
                        amountCtrl.text = s.outstandingBalance.toString();
                        controller.formAmount.value = s.outstandingBalance;
                      }
                    },
                  )),
              const SizedBox(height: 12),
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 480,
                children: [
                  Obx(() => AppDropdown<AccountModel>(
                        label: 'Paid From (Account) *',
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
                    label: 'Ref / Cheque / UTR #',
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
                label: isEdit ? 'Update Payment' : 'Save Payment',
                isLoading: controller.isSubmitting.value,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final ok = await controller.submitPayment();
                  if (ok) {
                    if (isEdit) {
                      Get.back();
                    } else {
                      await controller.prepareNewPaymentForm();
                      amountCtrl.clear();
                      refCtrl.clear();
                      notesCtrl.clear();
                      formKey.currentState?.reset();
                    }
                  }
                },
              )),
        ],
      ),
    );
  }

  void _confirmDeletePayment(BuildContext context, PaymentModel payment) {
    Get.dialog(
      AppDialog(
        title: 'Delete Payment #${payment.paymentNumber}?',
        maxWidth: 440,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete payment #${payment.paymentNumber} (${CurrencyUtils.format(payment.amount)}) to ${payment.supplierName ?? 'Supplier'}?',
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 8),
            const Text(
              'Deleting this payment will reverse the supplier balance disbursement and associated journal entries.',
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
              await controller.deletePayment(payment);
            },
          ),
        ],
      ),
    );
  }
}
