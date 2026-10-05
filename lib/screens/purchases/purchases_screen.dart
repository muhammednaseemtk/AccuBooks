import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/purchase_controller.dart';
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
import '../../models/purchase_invoice_model.dart';
import '../navigation/app_scaffold.dart';

class PurchasesScreen extends GetView<PurchaseController> {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Purchases & Bills',
      currentRoute: AppRoutes.purchases,
      actions: [
        AppButton(
          label: 'Record Purchase',
          icon: Icons.add,
          onPressed: () {
            controller.prepareNewPurchaseForm();
            Get.toNamed(AppRoutes.purchasesCreate);
          },
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Filters
            AppCard(
              padding: const EdgeInsets.all(12),
              child: ResponsiveRowColumn(
                spacing: 12,
                children: [
                  AppTextField(
                    hint: 'Search by purchase # or supplier...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    onChanged: controller.setSearch,
                  ),
                  Obx(() => AppDropdown<String>(
                        value: controller.selectedStatus.value,
                        items: ['All', AccountingConstants.paymentPaid, AccountingConstants.paymentPartiallyPaid, AccountingConstants.paymentUnpaid, AccountingConstants.paymentCancelled]
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => controller.setStatusFilter(v ?? 'All'),
                      )),
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

            // Purchases Table
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoadingWidget(message: 'Loading purchases...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return ErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.loadPurchases,
                  );
                }

                if (controller.purchases.isEmpty) {
                  return EmptyState(
                    title: 'No purchase records found',
                    subtitle: 'Record purchases from vendors to maintain inventory and payables.',
                    actionLabel: 'Record Purchase',
                    onAction: () {
                      controller.prepareNewPurchaseForm();
                      Get.toNamed(AppRoutes.purchasesCreate);
                    },
                  );
                }

                final columns = [
                  const AppTableColumn(title: 'Purchase #', width: 110),
                  const AppTableColumn(title: 'Date', width: 95),
                  const AppTableColumn(title: 'Supplier Name'),
                  const AppTableColumn(title: 'Grand Total', width: 130, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Balance Payable', width: 140, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Status', width: 110, alignment: Alignment.center),
                  const AppTableColumn(title: 'Actions', width: 110, alignment: Alignment.centerRight),
                ];

                final rows = controller.purchases.map((pur) {
                  Color statusColor = AppColors.debit;
                  if (pur.isPaid) statusColor = AppColors.credit;
                  if (pur.paymentStatus == AccountingConstants.paymentPartiallyPaid) statusColor = AppColors.warning;

                  return [
                    Text(pur.invoiceNumber, style: AppTextStyles.tableCellBold),
                    Text(AppDateUtils.format(pur.invoiceDate), style: AppTextStyles.tableCell),
                    Text(pur.supplierName ?? 'Supplier #${pur.supplierId}', style: AppTextStyles.tableCellBold),
                    Text(CurrencyUtils.format(pur.grandTotal), style: AppTextStyles.tableCellBold),
                    Text(
                      CurrencyUtils.format(pur.balanceAmount),
                      style: AppTextStyles.tableCellBold.copyWith(
                        color: pur.balanceAmount > 0 ? AppColors.debit : AppColors.credit,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pur.paymentStatus,
                        style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          tooltip: 'View Purchase Details',
                          splashRadius: 16,
                          onPressed: () => _showPurchaseDetailsDialog(context, pur),
                        ),
                        if (!pur.isCancelled)
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.debit),
                            tooltip: 'Cancel Purchase',
                            splashRadius: 16,
                            onPressed: () => _confirmCancelPurchase(context, pur),
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
                      minWidth: 850,
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

  void _showPurchaseDetailsDialog(BuildContext context, PurchaseInvoiceModel purchase) {
    Get.dialog(
      AppDialog(
        title: 'Purchase Bill: ${purchase.invoiceNumber}',
        maxWidth: 750,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.start,
              spacing: 16,
              runSpacing: 8,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Supplier:', style: AppTextStyles.caption),
                      Text(purchase.supplierName ?? 'Supplier', style: AppTextStyles.subtitle1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bill Date: ${AppDateUtils.format(purchase.invoiceDate)}', style: AppTextStyles.body2),
                    Text('Status: ${purchase.paymentStatus}', style: AppTextStyles.subtitle2),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Purchased Items:', style: AppTextStyles.subtitle2),
            const SizedBox(height: 8),
            AppTable(
              columns: const [
                AppTableColumn(title: 'Item'),
                AppTableColumn(title: 'Qty', width: 70, alignment: Alignment.centerRight),
                AppTableColumn(title: 'Rate', width: 90, alignment: Alignment.centerRight),
                AppTableColumn(title: 'Tax', width: 80, alignment: Alignment.centerRight),
                AppTableColumn(title: 'Total', width: 100, alignment: Alignment.centerRight),
              ],
              rows: purchase.items.map((i) => [
                Text(i.productName ?? 'Product', style: AppTextStyles.tableCellBold),
                Text('${i.quantity} ${i.unit ?? ''}', style: AppTextStyles.tableCell),
                Text(CurrencyUtils.format(i.rate), style: AppTextStyles.tableCell),
                Text(CurrencyUtils.format(i.taxAmount), style: AppTextStyles.tableCell),
                Text(CurrencyUtils.format(i.total), style: AppTextStyles.tableCellBold),
              ]).toList(),
              minWidth: 500,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariantLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _rowText('Subtotal', CurrencyUtils.format(purchase.subtotal)),
                      _rowText('Tax Amount', CurrencyUtils.format(purchase.taxAmount)),
                      const Divider(height: 12),
                      _rowText('Grand Total', CurrencyUtils.format(purchase.grandTotal), isBold: true),
                      _rowText('Paid Amount', CurrencyUtils.format(purchase.paidAmount)),
                      _rowText('Balance Due', CurrencyUtils.format(purchase.balanceAmount), isBold: true),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowText(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isBold ? AppTextStyles.tableCellBold : AppTextStyles.caption),
          Text(value, style: isBold ? AppTextStyles.tableCellBold : AppTextStyles.tableCell),
        ],
      ),
    );
  }

  void _confirmCancelPurchase(BuildContext context, PurchaseInvoiceModel purchase) {
    final reasonCtrl = TextEditingController(text: 'Goods returned / cancellation');

    Get.dialog(
      AppDialog(
        title: 'Cancel Purchase #${purchase.invoiceNumber}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cancelling this purchase will deduct the received items from your stock and record an accounting reversal.',
              style: AppTextStyles.body2,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Reason for Cancellation',
              controller: reasonCtrl,
            ),
          ],
        ),
        actions: [
          AppButton(label: 'Keep', type: AppButtonType.text, onPressed: () => Get.back()),
          AppButton(
            label: 'Confirm Cancellation',
            type: AppButtonType.danger,
            onPressed: () async {
              Get.back();
              await controller.cancelPurchase(purchase.id!, reasonCtrl.text.trim());
            },
          ),
        ],
      ),
    );
  }
}
