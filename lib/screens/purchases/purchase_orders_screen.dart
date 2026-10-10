import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/purchase_order_controller.dart';
import '../../core/constants/accounting_constants.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_table.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/product_model.dart';
import '../../models/purchase_invoice_model.dart';
import '../../models/purchase_order_model.dart';
import '../../models/purchase_order_item_model.dart';
import '../../models/purchase_return_model.dart';
import '../../models/purchase_return_item_model.dart';
import '../../models/supplier_model.dart';
import '../navigation/app_scaffold.dart';

class PurchaseOrdersScreen extends GetView<PurchaseOrderController> {
  const PurchaseOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Get.arguments is Map && (Get.arguments as Map)['tab'] != null) {
      final tabIdx = (Get.arguments as Map)['tab'] as int;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.activeTabIndex.value != tabIdx) {
          controller.switchTab(tabIdx);
        }
      });
    }

    return AppScaffold(
      title: 'Purchase Orders & Returns',
      currentRoute: AppRoutes.purchaseOrders,
      actions: [
        Obx(() {
          if (controller.activeTabIndex.value == 0) {
            return AppButton(
              label: 'New Purchase Order',
              icon: Icons.add,
              onPressed: () => _showCreateOrderDialog(context),
            );
          } else {
            return AppButton(
              label: 'New Purchase Return',
              icon: Icons.assignment_return_outlined,
              onPressed: () => _showCreateReturnDialog(context),
            );
          }
        }),
      ],
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Tabs Bar: Purchase Orders, Purchase Invoices, Purchase Returns
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Obx(() => Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Purchase Orders'),
                      selected: controller.activeTabIndex.value == 0,
                      onSelected: (_) => controller.switchTab(0),
                      selectedColor: AppColors.primary,
                      labelStyle: AppTextStyles.button.copyWith(
                        color: controller.activeTabIndex.value == 0 ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Purchase Invoices'),
                      selected: false,
                      onSelected: (_) => Get.offNamed(AppRoutes.purchases),
                      selectedColor: AppColors.primary,
                      labelStyle: AppTextStyles.button,
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Purchase Returns'),
                      selected: controller.activeTabIndex.value == 1,
                      onSelected: (_) => controller.switchTab(1),
                      selectedColor: AppColors.primary,
                      labelStyle: AppTextStyles.button.copyWith(
                        color: controller.activeTabIndex.value == 1 ? Colors.white : null,
                      ),
                    ),
                  ],
                )),
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
                    hint: 'Search...',
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
                  Obx(() {
                    if (controller.activeTabIndex.value == 0) {
                      return AppDropdown<String>(
                        value: controller.selectedStatus.value,
                        items: ['All', AccountingConstants.statusPending, AccountingConstants.statusConfirmed, AccountingConstants.statusCompleted, AccountingConstants.statusCancelled]
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => controller.setStatusFilter(v ?? 'All'),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // List Table View
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoadingWidget(message: 'Loading records...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return Center(child: Text(controller.errorMessage.value, style: AppTextStyles.body1.copyWith(color: AppColors.debit)));
                }

                if (controller.activeTabIndex.value == 0) {
                  return _buildOrdersList(context);
                } else {
                  return _buildReturnsList(context);
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context) {
    if (controller.orders.isEmpty) {
      return EmptyState(
        title: 'No purchase orders found',
        subtitle: 'Create a new order to place purchase requests with suppliers before billing.',
        actionLabel: 'Create Purchase Order',
        onAction: () => _showCreateOrderDialog(context),
      );
    }

    final columns = const [
      AppTableColumn(title: 'Order #', width: 130),
      AppTableColumn(title: 'Date', width: 110),
      AppTableColumn(title: 'Supplier', width: 180),
      AppTableColumn(title: 'Delivery', width: 110),
      AppTableColumn(title: 'Items', width: 70, alignment: Alignment.center),
      AppTableColumn(title: 'Grand Total', width: 130, alignment: Alignment.centerRight),
      AppTableColumn(title: 'Status', width: 120, alignment: Alignment.center),
      AppTableColumn(title: 'Actions', width: 130, alignment: Alignment.center),
    ];

    final rows = List.generate(controller.orders.length, (index) {
      final order = controller.orders[index];
      return [
        Text(order.orderNumber, style: AppTextStyles.tableCellBold),
        Text(AppDateUtils.format(order.orderDate), style: AppTextStyles.tableCell),
        Text(order.supplierName ?? 'Supplier #${order.supplierId}', style: AppTextStyles.tableCell),
        Text(order.expectedDeliveryDate != null ? AppDateUtils.format(order.expectedDeliveryDate!) : '-', style: AppTextStyles.tableCell),
        Text('${order.items.length}', style: AppTextStyles.tableCell),
        Text(CurrencyUtils.format(order.grandTotal), style: AppTextStyles.tableCellBold),
        _buildStatusBadge(order.status),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
              tooltip: 'View Details',
              onPressed: () => _showOrderDetailsDialog(context, order),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
              tooltip: 'Edit Order',
              onPressed: () async {
                await controller.prepareEditOrderForm(order);
                if (context.mounted) _showCreateOrderDialog(context, isEditing: true);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debit),
              tooltip: 'Delete Order',
              onPressed: () => _confirmDeleteOrder(context, order),
            ),
          ],
        ),
      ];
    });

    return AppTable(columns: columns, rows: rows, minWidth: 980);
  }

  Widget _buildReturnsList(BuildContext context) {
    if (controller.returns.isEmpty) {
      return EmptyState(
        title: 'No purchase returns found',
        subtitle: 'Process return of purchased items back to suppliers and deduct payables.',
        actionLabel: 'Create Purchase Return',
        onAction: () => _showCreateReturnDialog(context),
      );
    }

    final columns = const [
      AppTableColumn(title: 'Return #', width: 130),
      AppTableColumn(title: 'Date', width: 110),
      AppTableColumn(title: 'Supplier', width: 180),
      AppTableColumn(title: 'Ref Invoice', width: 130),
      AppTableColumn(title: 'Items', width: 70, alignment: Alignment.center),
      AppTableColumn(title: 'Return Total', width: 130, alignment: Alignment.centerRight),
      AppTableColumn(title: 'Status', width: 110, alignment: Alignment.center),
      AppTableColumn(title: 'Actions', width: 130, alignment: Alignment.center),
    ];

    final rows = List.generate(controller.returns.length, (index) {
      final ret = controller.returns[index];
      return [
        Text(ret.returnNumber, style: AppTextStyles.tableCellBold),
        Text(AppDateUtils.format(ret.returnDate), style: AppTextStyles.tableCell),
        Text(ret.supplierName ?? 'Supplier #${ret.supplierId}', style: AppTextStyles.tableCell),
        Text(ret.referenceInvoiceNumber ?? '-', style: AppTextStyles.tableCell),
        Text('${ret.items.length}', style: AppTextStyles.tableCell),
        Text(CurrencyUtils.format(ret.grandTotal), style: AppTextStyles.tableCellBold),
        _buildStatusBadge(ret.status),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
              tooltip: 'View Details',
              onPressed: () => _showReturnDetailsDialog(context, ret),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
              tooltip: 'Edit Return',
              onPressed: () async {
                await controller.prepareEditReturnForm(ret);
                if (context.mounted) _showCreateReturnDialog(context, isEditing: true);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debit),
              tooltip: 'Delete Return',
              onPressed: () => _confirmDeleteReturn(context, ret),
            ),
          ],
        ),
      ];
    });

    return AppTable(columns: columns, rows: rows, minWidth: 980);
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case AccountingConstants.statusConfirmed:
        bg = AppColors.primary.withValues(alpha: 0.15);
        fg = AppColors.primary;
        break;
      case AccountingConstants.statusCompleted:
        bg = AppColors.credit.withValues(alpha: 0.15);
        fg = AppColors.credit;
        break;
      case AccountingConstants.statusCancelled:
        bg = AppColors.neutral.withValues(alpha: 0.2);
        fg = AppColors.neutral;
        break;
      case AccountingConstants.statusPending:
      default:
        bg = AppColors.warning.withValues(alpha: 0.15);
        fg = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: AppTextStyles.caption.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }

  // ===================== DIALOG: CREATE PURCHASE ORDER =====================

  void _showCreateOrderDialog(BuildContext context, {bool isEditing = false}) {
    if (!isEditing) {
      controller.prepareNewOrderForm();
    }

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AppDialog(
            title: isEditing ? 'Edit Purchase Order' : 'New Purchase Order',
            maxWidth: 860,
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ResponsiveRowColumn(
                    spacing: 12,
                    breakpoint: 450,
                    children: [
                      Obx(() => AppTextField(
                            label: 'Order Number',
                            hint: 'Order Number',
                            initialValue: controller.formOrderNumber.value,
                            readOnly: true,
                          )),
                      Obx(() => AppDropdown<SupplierModel>(
                            label: 'Supplier *',
                            hint: 'Select Supplier',
                            value: controller.formOrderSupplier.value,
                            items: controller.suppliers.map((s) {
                              return DropdownMenuItem(value: s, child: Text(s.name));
                            }).toList(),
                            onChanged: (s) => controller.formOrderSupplier.value = s,
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ResponsiveRowColumn(
                    spacing: 12,
                    breakpoint: 450,
                    children: [
                      Obx(() => AppDatePickerField(
                            label: 'Order Date',
                            value: controller.formOrderDate.value,
                            onDateSelected: (d) => controller.formOrderDate.value = d,
                          )),
                      Obx(() => AppDatePickerField(
                            label: 'Expected Delivery Date',
                            hint: 'Select date',
                            value: controller.formExpectedDeliveryDate.value,
                            initialPickerDate: DateTime.now().add(const Duration(days: 7)),
                            onDateSelected: (d) => controller.formExpectedDeliveryDate.value = d,
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Obx(() => AppDropdown<String>(
                        label: 'Order Status',
                        value: controller.formOrderStatus.value,
                        items: [
                          AccountingConstants.statusPending,
                          AccountingConstants.statusConfirmed,
                          AccountingConstants.statusCompleted,
                          AccountingConstants.statusCancelled,
                        ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (s) => controller.formOrderStatus.value = s ?? AccountingConstants.statusPending,
                      )),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Line Items section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order Items', style: AppTextStyles.subtitle2),
                      AppButton(
                        label: 'Add Product',
                        icon: Icons.add,
                        type: AppButtonType.outline,
                        onPressed: () => _showAddOrderItemDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Obx(() {
                    if (controller.formOrderItems.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('No product items added yet. Click "+ Add Product".', style: AppTextStyles.caption),
                        ),
                      );
                    }

                    return Column(
                      children: List.generate(controller.formOrderItems.length, (i) {
                        final item = controller.formOrderItems[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName ?? 'Product', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold)),
                                      Text('${item.quantity} ${item.unit ?? ''} @ ${CurrencyUtils.format(item.rate)} | Tax: ${CurrencyUtils.format(item.taxAmount)}', style: AppTextStyles.caption),
                                    ],
                                  ),
                                ),
                                Text(CurrencyUtils.format(item.total), style: AppTextStyles.metricMedium),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                  onPressed: () => _showAddOrderItemDialog(context, editIndex: i, existingItem: item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debit),
                                  onPressed: () => controller.removeOrderItem(i),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    );
                  }),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Totals
                  Obx(() => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _calcRow('Subtotal', CurrencyUtils.format(controller.formOrderSubtotal)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Order Discount', style: AppTextStyles.caption),
                                SizedBox(
                                  width: 110,
                                  child: AppTextField(
                                    hint: 'Discount',
                                    initialValue: controller.formOrderDiscount.value == 0
                                        ? '0'
                                        : controller.formOrderDiscount.value.toStringAsFixed(2),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [AppInputFormatters.decimal()],
                                    onChanged: (v) => controller.formOrderDiscount.value = double.tryParse(v) ?? 0.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _calcRow('Tax Total', CurrencyUtils.format(controller.formOrderTaxTotal)),
                            const Divider(height: 12),
                            _calcRow('Grand Total', CurrencyUtils.format(controller.formOrderGrandTotal), isBold: true),
                          ],
                        ),
                      )),

                  const SizedBox(height: 12),
                  Obx(() => AppTextField(
                        label: 'Notes / Memo',
                        hint: 'Enter notes',
                        initialValue: controller.formOrderNotes.value,
                        onChanged: (v) => controller.formOrderNotes.value = v,
                      )),
                ],
              ),
            ),
            actions: [
              AppButton(
                label: 'Cancel / Clear',
                type: AppButtonType.text,
                onPressed: () {
                  controller.resetOrderForm();
                  Get.back();
                },
              ),
              Obx(() => AppButton(
                    label: isEditing ? 'Update Purchase Order' : 'Create Purchase Order',
                    icon: Icons.check,
                    isLoading: controller.isSubmitting.value,
                    onPressed: controller.isSubmitting.value
                        ? null
                        : () async {
                            final ok = await controller.submitOrder();
                            if (ok) {
                              Get.back();
                            }
                          },
                  )),
            ],
          );
        },
      ),
    );
  }

  void _showAddOrderItemDialog(
    BuildContext context, {
    int? editIndex,
    PurchaseOrderItemModel? existingItem,
  }) {
    ProductModel? selectedProd;
    if (existingItem != null) {
      selectedProd = controller.products.firstWhereOrNull((p) => p.id == existingItem.productId);
      selectedProd ??= controller.products.firstWhereOrNull((p) => p.name == existingItem.productName);
    }
    final qtyCtrl = TextEditingController(text: existingItem != null ? existingItem.quantity.toString() : '1');
    final rateCtrl = TextEditingController(text: existingItem != null ? existingItem.rate.toString() : '');
    final discountCtrl = TextEditingController(text: existingItem != null ? existingItem.discount.toString() : '0');
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AppDialog(
            title: editIndex != null ? 'Edit Product Item' : 'Add Product Item',
            maxWidth: 500,
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppDropdown<ProductModel>(
                    label: 'Product *',
                    hint: 'Select Product',
                    value: selectedProd,
                    items: controller.products.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p.name));
                    }).toList(),
                    onChanged: (p) {
                      setState(() {
                        selectedProd = p;
                        if (p != null) rateCtrl.text = p.purchasePrice.toString();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ResponsiveRowColumn(
                    spacing: 12,
                    breakpoint: 400,
                    children: [
                      AppTextField(
                        label: 'Quantity *',
                        hint: 'Quantity',
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [AppInputFormatters.decimal()],
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Quantity must be > 0' : null,
                      ),
                      AppTextField(
                        label: 'Purchase Price *',
                        hint: 'Purchase Price',
                        controller: rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [AppInputFormatters.decimal()],
                        validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Valid price required' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Discount (₹)',
                    hint: 'Discount',
                    controller: discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [AppInputFormatters.decimal()],
                  ),
                ],
              ),
            ),
            actions: [
              AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Get.back()),
              AppButton(
                label: editIndex != null ? 'Update Item' : 'Add to Order',
                onPressed: () {
                  if (selectedProd == null) {
                    Get.snackbar('Error', 'Please select a product', snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  if (!formKey.currentState!.validate()) return;

                  final q = double.tryParse(qtyCtrl.text.replaceAll(',', '')) ?? 1.0;
                  final r = double.tryParse(rateCtrl.text.replaceAll(',', '')) ?? selectedProd!.purchasePrice;
                  final d = double.tryParse(discountCtrl.text.replaceAll(',', '')) ?? 0.0;

                  if (editIndex != null) {
                    controller.updateOrderItem(editIndex, q, r, d);
                  } else {
                    controller.addOrderItem(selectedProd!, q, r, d);
                  }
                  Get.back();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ===================== DIALOG: CREATE PURCHASE RETURN =====================

  void _showCreateReturnDialog(BuildContext context, {bool isEditing = false}) {
    if (!isEditing) {
      controller.prepareNewReturnForm();
    }

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AppDialog(
            title: isEditing ? 'Edit Purchase Return' : 'New Purchase Return',
            maxWidth: 860,
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ResponsiveRowColumn(
                    spacing: 12,
                    breakpoint: 450,
                    children: [
                      Obx(() => AppTextField(
                            label: 'Return Number',
                            hint: 'Return Number',
                            initialValue: controller.formReturnNumber.value,
                            readOnly: true,
                          )),
                      Obx(() => AppDropdown<SupplierModel>(
                            label: 'Supplier *',
                            hint: 'Select Supplier',
                            value: controller.formReturnSupplier.value,
                            items: controller.suppliers.map((s) {
                              return DropdownMenuItem(value: s, child: Text(s.name));
                            }).toList(),
                            onChanged: (s) => controller.formReturnSupplier.value = s,
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ResponsiveRowColumn(
                    spacing: 12,
                    breakpoint: 450,
                    children: [
                      Obx(() => AppDatePickerField(
                            label: 'Return Date',
                            value: controller.formReturnDate.value,
                            onDateSelected: (d) => controller.formReturnDate.value = d,
                          )),
                      Obx(() => AppDropdown<PurchaseInvoiceModel>(
                            label: 'Reference Invoice (Optional)',
                            hint: 'Select Purchase Invoice',
                            value: controller.formReferenceInvoice.value,
                            items: controller.recentInvoices.map((inv) {
                              return DropdownMenuItem(
                                value: inv,
                                child: Text('${inv.invoiceNumber} (${CurrencyUtils.format(inv.grandTotal)})'),
                              );
                            }).toList(),
                            onChanged: (inv) => controller.onSelectReferenceInvoice(inv),
                          )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Returned Items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Returned Items', style: AppTextStyles.subtitle2),
                      AppButton(
                        label: 'Add Returned Product',
                        icon: Icons.add,
                        type: AppButtonType.outline,
                        onPressed: () => _showAddReturnItemDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Obx(() {
                    if (controller.formReturnItems.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('No returned items added yet. Click "+ Add Returned Product".', style: AppTextStyles.caption),
                        ),
                      );
                    }

                    return Column(
                      children: List.generate(controller.formReturnItems.length, (i) {
                        final item = controller.formReturnItems[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName ?? 'Product', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold)),
                                      Text('Return Qty: ${item.quantity} ${item.unit ?? ''} @ ${CurrencyUtils.format(item.rate)} | Tax: ${CurrencyUtils.format(item.taxAmount)}', style: AppTextStyles.caption),
                                    ],
                                  ),
                                ),
                                Text(CurrencyUtils.format(item.total), style: AppTextStyles.metricMedium.copyWith(color: AppColors.debit)),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                  onPressed: () => _showAddReturnItemDialog(context, editIndex: i, existingItem: item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debit),
                                  onPressed: () => controller.removeReturnItem(i),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    );
                  }),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Totals
                  Obx(() => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _calcRow('Return Subtotal', CurrencyUtils.format(controller.formReturnSubtotal)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Extra Discount', style: AppTextStyles.caption),
                                SizedBox(
                                  width: 110,
                                  child: AppTextField(
                                    hint: 'Discount',
                                    initialValue: controller.formReturnDiscount.value == 0
                                        ? '0'
                                        : controller.formReturnDiscount.value.toStringAsFixed(2),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [AppInputFormatters.decimal()],
                                    onChanged: (v) => controller.formReturnDiscount.value = double.tryParse(v) ?? 0.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _calcRow('Return Tax', CurrencyUtils.format(controller.formReturnTaxTotal)),
                            const Divider(height: 12),
                            _calcRow('Return Total (Reversal Credit)', CurrencyUtils.format(controller.formReturnGrandTotal), isBold: true),
                          ],
                        ),
                      )),

                  const SizedBox(height: 12),
                  Obx(() => AppTextField(
                        label: 'Reason for Return / Notes',
                        hint: 'Enter notes',
                        initialValue: controller.formReturnReason.value,
                        onChanged: (v) => controller.formReturnReason.value = v,
                      )),
                ],
              ),
            ),
            actions: [
              AppButton(
                label: 'Cancel / Clear',
                type: AppButtonType.text,
                onPressed: () {
                  controller.resetReturnForm();
                  Get.back();
                },
              ),
              Obx(() => AppButton(
                    label: isEditing ? 'Update Purchase Return' : 'Create Purchase Return',
                    icon: Icons.check,
                    isLoading: controller.isSubmitting.value,
                    onPressed: controller.isSubmitting.value
                        ? null
                        : () async {
                            final ok = await controller.submitReturn();
                            if (ok) {
                              Get.back();
                            }
                          },
                  )),
            ],
          );
        },
      ),
    );
  }

  void _showAddReturnItemDialog(
    BuildContext context, {
    int? editIndex,
    PurchaseReturnItemModel? existingItem,
  }) {
    ProductModel? selectedProd;
    if (existingItem != null) {
      selectedProd = controller.products.firstWhereOrNull((p) => p.id == existingItem.productId);
      selectedProd ??= controller.products.firstWhereOrNull((p) => p.name == existingItem.productName);
    }
    final qtyCtrl = TextEditingController(text: existingItem != null ? existingItem.quantity.toString() : '1');
    final rateCtrl = TextEditingController(text: existingItem != null ? existingItem.rate.toString() : '');
    final discountCtrl = TextEditingController(text: existingItem != null ? existingItem.discount.toString() : '0');
    final formKey = GlobalKey<FormState>();

    final refInvoice = controller.formReferenceInvoice.value;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AppDialog(
            title: editIndex != null ? 'Edit Return Item' : 'Add Return Item',
            maxWidth: 500,
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppDropdown<ProductModel>(
                    label: 'Product to Return *',
                    hint: 'Select Product',
                    value: selectedProd,
                    items: controller.products.map((p) {
                      return DropdownMenuItem(value: p, child: Text('${p.name} (Stock: ${p.stockQuantity})'));
                    }).toList(),
                    onChanged: (p) {
                      setState(() {
                        selectedProd = p;
                        if (p != null) {
                          if (refInvoice != null) {
                            final invItem = refInvoice.items.firstWhereOrNull((i) => i.productId == p.id);
                            if (invItem != null) {
                              rateCtrl.text = invItem.rate.toString();
                              qtyCtrl.text = invItem.quantity.toString();
                            } else {
                              rateCtrl.text = p.purchasePrice.toString();
                            }
                          } else {
                            rateCtrl.text = p.purchasePrice.toString();
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ResponsiveRowColumn(
                    spacing: 12,
                    breakpoint: 400,
                    children: [
                      AppTextField(
                        label: 'Returned Quantity *',
                        hint: 'Quantity',
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [AppInputFormatters.decimal()],
                        validator: (v) {
                          final q = double.tryParse(v ?? '') ?? 0;
                          if (q <= 0) return 'Quantity must be > 0';
                          return null;
                        },
                      ),
                      AppTextField(
                        label: 'Purchase Price *',
                        hint: 'Purchase Price',
                        controller: rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [AppInputFormatters.decimal()],
                        validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Valid price required' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Discount (₹)',
                    hint: 'Discount',
                    controller: discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [AppInputFormatters.decimal()],
                  ),
                ],
              ),
            ),
            actions: [
              AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Get.back()),
              AppButton(
                label: editIndex != null ? 'Update Item' : 'Add to Return',
                onPressed: () {
                  if (selectedProd == null) {
                    Get.snackbar('Error', 'Please select a product', snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  if (!formKey.currentState!.validate()) return;

                  final q = double.tryParse(qtyCtrl.text.replaceAll(',', '')) ?? 1.0;
                  final r = double.tryParse(rateCtrl.text.replaceAll(',', '')) ?? selectedProd!.purchasePrice;
                  final d = double.tryParse(discountCtrl.text.replaceAll(',', '')) ?? 0.0;

                  if (editIndex != null) {
                    controller.updateReturnItem(editIndex, q, r, d);
                  } else {
                    controller.addReturnItem(selectedProd!, q, r, d);
                  }
                  Get.back();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ===================== DETAILS DIALOGS =====================

  void _showOrderDetailsDialog(BuildContext context, PurchaseOrderModel order) {
    Get.dialog(
      AppDialog(
        title: 'Purchase Order: ${order.orderNumber}',
        maxWidth: 700,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date: ${AppDateUtils.format(order.orderDate)}', style: AppTextStyles.body2),
                _buildStatusBadge(order.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('Supplier: ${order.supplierName ?? 'Supplier #${order.supplierId}'}', style: AppTextStyles.subtitle2),
            if (order.expectedDeliveryDate != null)
              Text('Expected Delivery: ${AppDateUtils.format(order.expectedDeliveryDate!)}', style: AppTextStyles.caption),
            const SizedBox(height: 12),
            const Divider(),
            const Text('Items', style: AppTextStyles.subtitle2),
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${item.productName ?? 'Product'} (${item.quantity} ${item.unit ?? ''} @ ${CurrencyUtils.format(item.rate)})', style: AppTextStyles.body2),
                      ),
                      Text(CurrencyUtils.format(item.total), style: AppTextStyles.tableCellBold),
                    ],
                  ),
                )),
            const Divider(),
            _calcRow('Subtotal', CurrencyUtils.format(order.subtotal)),
            _calcRow('Tax', CurrencyUtils.format(order.taxAmount)),
            _calcRow('Grand Total', CurrencyUtils.format(order.grandTotal), isBold: true),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: ${order.notes}', style: AppTextStyles.caption),
            ],
          ],
        ),
        actions: [
          AppButton(
            label: 'Delete',
            type: AppButtonType.danger,
            icon: Icons.delete_outline,
            onPressed: () {
              Get.back();
              _confirmDeleteOrder(context, order);
            },
          ),
          AppButton(
            label: 'Edit Order',
            type: AppButtonType.secondary,
            icon: Icons.edit_outlined,
            onPressed: () async {
              Get.back();
              await controller.prepareEditOrderForm(order);
              if (context.mounted) _showCreateOrderDialog(context, isEditing: true);
            },
          ),
          AppButton(label: 'Close', onPressed: () => Get.back()),
        ],
      ),
    );
  }

  void _confirmDeleteOrder(BuildContext context, PurchaseOrderModel order) {
    Get.dialog(
      AppDialog(
        title: 'Delete Purchase Order?',
        maxWidth: 440,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete Purchase Order "${order.orderNumber}" (${CurrencyUtils.format(order.grandTotal)})?',
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            type: AppButtonType.text,
            onPressed: () => Get.back(),
          ),
          AppButton(
            label: 'Delete',
            type: AppButtonType.danger,
            icon: Icons.delete_outline,
            onPressed: () async {
              Get.back();
              await controller.deletePurchaseOrder(order);
            },
          ),
        ],
      ),
    );
  }

  void _showReturnDetailsDialog(BuildContext context, PurchaseReturnModel ret) {
    Get.dialog(
      AppDialog(
        title: 'Purchase Return: ${ret.returnNumber}',
        maxWidth: 700,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date: ${AppDateUtils.format(ret.returnDate)}', style: AppTextStyles.body2),
                _buildStatusBadge(ret.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('Supplier: ${ret.supplierName ?? 'Supplier #${ret.supplierId}'}', style: AppTextStyles.subtitle2),
            if (ret.referenceInvoiceNumber != null)
              Text('Reference Invoice: ${ret.referenceInvoiceNumber}', style: AppTextStyles.caption),
            const SizedBox(height: 12),
            const Divider(),
            const Text('Returned Items (Stock Deducted)', style: AppTextStyles.subtitle2),
            const SizedBox(height: 8),
            ...ret.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${item.productName ?? 'Product'} (${item.quantity} ${item.unit ?? ''} @ ${CurrencyUtils.format(item.rate)})', style: AppTextStyles.body2),
                      ),
                      Text(CurrencyUtils.format(item.total), style: AppTextStyles.tableCellBold),
                    ],
                  ),
                )),
            const Divider(),
            _calcRow('Return Subtotal', CurrencyUtils.format(ret.subtotal)),
            _calcRow('Return Tax', CurrencyUtils.format(ret.taxAmount)),
            _calcRow('Return Total', CurrencyUtils.format(ret.grandTotal), isBold: true),
            if (ret.reason != null && ret.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Reason: ${ret.reason}', style: AppTextStyles.caption),
            ],
          ],
        ),
        actions: [
          AppButton(
            label: 'Delete',
            type: AppButtonType.danger,
            icon: Icons.delete_outline,
            onPressed: () {
              Get.back();
              _confirmDeleteReturn(context, ret);
            },
          ),
          AppButton(
            label: 'Edit Return',
            type: AppButtonType.secondary,
            icon: Icons.edit_outlined,
            onPressed: () async {
              Get.back();
              await controller.prepareEditReturnForm(ret);
              if (context.mounted) _showCreateReturnDialog(context, isEditing: true);
            },
          ),
          AppButton(label: 'Close', onPressed: () => Get.back()),
        ],
      ),
    );
  }

  void _confirmDeleteReturn(BuildContext context, PurchaseReturnModel ret) {
    Get.dialog(
      AppDialog(
        title: 'Delete Purchase Return?',
        maxWidth: 440,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete Purchase Return "${ret.returnNumber}" (${CurrencyUtils.format(ret.grandTotal)})?',
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 8),
            Text(
              'Deleting this return will revert stock deductions and accounting ledger entries.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            type: AppButtonType.text,
            onPressed: () => Get.back(),
          ),
          AppButton(
            label: 'Delete',
            type: AppButtonType.danger,
            icon: Icons.delete_outline,
            onPressed: () async {
              Get.back();
              await controller.deletePurchaseReturn(ret);
            },
          ),
        ],
      ),
    );
  }

  Widget _calcRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: isBold ? AppTextStyles.subtitle2 : AppTextStyles.body2),
        Text(value, style: isBold ? AppTextStyles.metricMedium : AppTextStyles.body1),
      ],
    );
  }
}
