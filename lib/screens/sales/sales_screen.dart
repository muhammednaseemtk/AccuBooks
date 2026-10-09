import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/sales_controller.dart';
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
import '../../models/sales_invoice_model.dart';
import '../navigation/app_scaffold.dart';

class SalesScreen extends GetView<SalesController> {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Sales Invoices',
      currentRoute: AppRoutes.sales,
      actions: [
        AppButton(
          label: 'Create Invoice',
          icon: Icons.add,
          onPressed: () {
            controller.prepareNewInvoiceForm();
            Get.toNamed(AppRoutes.salesCreate);
          },
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Tabs Bar: Sales Orders, Sales Invoices, Sales Returns
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Sales Orders'),
                      selected: false,
                      onSelected: (_) => Get.offNamed(AppRoutes.salesOrders, arguments: {'tab': 0}),
                      selectedColor: AppColors.primary,
                      labelStyle: AppTextStyles.button,
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Sales Invoices'),
                      selected: true,
                      onSelected: (_) {},
                      selectedColor: AppColors.primary,
                      labelStyle: AppTextStyles.button.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Sales Returns'),
                      selected: false,
                      onSelected: (_) => Get.offNamed(AppRoutes.salesOrders, arguments: {'tab': 1}),
                      selectedColor: AppColors.primary,
                      labelStyle: AppTextStyles.button,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Filters Bar
            AppCard(
              padding: const EdgeInsets.all(12),
              child: ResponsiveRowColumn(
                spacing: 12,
                children: [
                  AppTextField(
                    hint: 'Search by invoice # or customer...',
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

            // Invoices Table
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoadingWidget(message: 'Loading sales invoices...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return ErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.loadInvoices,
                  );
                }

                if (controller.invoices.isEmpty) {
                  return EmptyState(
                    title: 'No sales invoices found',
                    subtitle: 'Create a new invoice to start billing your customers.',
                    actionLabel: 'Create Sales Invoice',
                    onAction: () {
                      controller.prepareNewInvoiceForm();
                      Get.toNamed(AppRoutes.salesCreate);
                    },
                  );
                }

                final columns = [
                  const AppTableColumn(title: 'Invoice #', width: 110),
                  const AppTableColumn(title: 'Date', width: 95),
                  const AppTableColumn(title: 'Customer Name'),
                  const AppTableColumn(title: 'Grand Total', width: 130, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Balance Due', width: 130, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Status', width: 110, alignment: Alignment.center),
                  const AppTableColumn(title: 'Actions', width: 195, alignment: Alignment.centerRight),
                ];

                final rows = controller.invoices.map((inv) {
                  Color statusColor = AppColors.debit;
                  if (inv.isPaid) statusColor = AppColors.credit;
                  if (inv.paymentStatus == AccountingConstants.paymentPartiallyPaid) statusColor = AppColors.warning;

                  return [
                    Text(inv.invoiceNumber, style: AppTextStyles.tableCellBold),
                    Text(AppDateUtils.format(inv.invoiceDate), style: AppTextStyles.tableCell),
                    Text(inv.customerName ?? 'Customer #${inv.customerId}', style: AppTextStyles.tableCellBold),
                    Text(CurrencyUtils.format(inv.grandTotal), style: AppTextStyles.tableCellBold),
                    Text(
                      CurrencyUtils.format(inv.balanceAmount),
                      style: AppTextStyles.tableCellBold.copyWith(
                        color: inv.balanceAmount > 0 ? AppColors.warning : AppColors.credit,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        inv.paymentStatus,
                        style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          tooltip: 'View Invoice',
                          splashRadius: 16,
                          onPressed: () => _showInvoiceDetailsDialog(context, inv),
                        ),
                        if (!inv.isCancelled)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                            tooltip: 'Edit Invoice',
                            splashRadius: 16,
                            onPressed: () async {
                              await controller.loadInvoiceForEdit(inv);
                              Get.toNamed(AppRoutes.salesCreate);
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.print_outlined, size: 18),
                          tooltip: 'Print / PDF',
                          splashRadius: 16,
                          onPressed: () => controller.printCurrentInvoice(inv),
                        ),
                        if (!inv.isCancelled)
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.debit),
                            tooltip: 'Cancel Invoice',
                            splashRadius: 16,
                            onPressed: () => _confirmCancelInvoice(context, inv),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debit),
                          tooltip: 'Delete Invoice',
                          splashRadius: 16,
                          onPressed: () => _confirmDeleteInvoice(context, inv),
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
                      minWidth: 860,
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

  void _showInvoiceDetailsDialog(BuildContext context, SalesInvoiceModel invoice) {
    Get.dialog(
      AppDialog(
        title: 'Invoice Details: ${invoice.invoiceNumber}',
        maxWidth: 800,
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
                      Text('Customer:', style: AppTextStyles.caption),
                      Text(invoice.customerName ?? 'Customer', style: AppTextStyles.subtitle1, overflow: TextOverflow.ellipsis),
                      if (invoice.customerPhone != null) Text(invoice.customerPhone!, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invoice Date: ${AppDateUtils.format(invoice.invoiceDate)}', style: AppTextStyles.body2),
                    Text('Status: ${invoice.paymentStatus}', style: AppTextStyles.subtitle2),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Items:', style: AppTextStyles.subtitle2),
            const SizedBox(height: 8),
            AppTable(
              columns: const [
                AppTableColumn(title: 'Item'),
                AppTableColumn(title: 'Qty', width: 70, alignment: Alignment.centerRight),
                AppTableColumn(title: 'Rate', width: 90, alignment: Alignment.centerRight),
                AppTableColumn(title: 'Tax', width: 80, alignment: Alignment.centerRight),
                AppTableColumn(title: 'Total', width: 100, alignment: Alignment.centerRight),
              ],
              rows: invoice.items.map((i) => [
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
                      _rowText('Subtotal', CurrencyUtils.format(invoice.subtotal)),
                      if (invoice.discount > 0)
                        _rowText('Discount', '- ${CurrencyUtils.format(invoice.discount)}'),
                      _rowText('Tax Total', CurrencyUtils.format(invoice.taxAmount)),
                      const Divider(height: 12),
                      _rowText('Grand Total', CurrencyUtils.format(invoice.grandTotal), isBold: true),
                      _rowText('Paid Amount', CurrencyUtils.format(invoice.paidAmount)),
                      _rowText('Balance Due', CurrencyUtils.format(invoice.balanceAmount), isBold: true),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Delete Invoice',
            type: AppButtonType.danger,
            icon: Icons.delete_outline,
            onPressed: () {
              Get.back();
              _confirmDeleteInvoice(context, invoice);
            },
          ),
          if (!invoice.isCancelled)
            AppButton(
              label: 'Edit Invoice',
              icon: Icons.edit_outlined,
              type: AppButtonType.secondary,
              onPressed: () async {
                Get.back();
                await controller.loadInvoiceForEdit(invoice);
                Get.toNamed(AppRoutes.salesCreate);
              },
            ),
          AppButton(
            label: 'Close',
            type: AppButtonType.text,
            onPressed: () => Get.back(),
          ),
          AppButton(
            label: 'Export PDF',
            icon: Icons.picture_as_pdf,
            type: AppButtonType.outline,
            onPressed: () => controller.shareCurrentInvoicePdf(invoice),
          ),
          AppButton(
            label: 'Print Invoice',
            icon: Icons.print,
            onPressed: () => controller.printCurrentInvoice(invoice),
          ),
        ],
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

  void _confirmCancelInvoice(BuildContext context, SalesInvoiceModel invoice) {
    final reasonCtrl = TextEditingController(text: 'Customer requested cancellation');

    Get.dialog(
      AppDialog(
        title: 'Cancel Invoice #${invoice.invoiceNumber}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cancelling this invoice will restore inventory stock for all line items and generate an automatic reversal journal entry.',
              style: AppTextStyles.body2,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Cancellation Reason',
              controller: reasonCtrl,
            ),
          ],
        ),
        actions: [
          AppButton(label: 'Keep Invoice', type: AppButtonType.text, onPressed: () => Get.back()),
          AppButton(
            label: 'Confirm Cancellation',
            type: AppButtonType.danger,
            onPressed: () async {
              Get.back();
              await controller.cancelInvoice(invoice.id!, reasonCtrl.text.trim());
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteInvoice(BuildContext context, SalesInvoiceModel invoice) {
    Get.dialog(
      AppDialog(
        title: 'Delete Invoice #${invoice.invoiceNumber}?',
        maxWidth: 440,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete invoice #${invoice.invoiceNumber} for ${invoice.customerName ?? 'Customer'}?',
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 8),
            const Text(
              'Deleting this invoice will restore inventory stock and remove associated journal entries.',
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
              await controller.deleteInvoice(invoice);
            },
          ),
        ],
      ),
    );
  }
}
