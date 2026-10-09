import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/purchase_controller.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_table.dart';
import '../../core/widgets/app_text_field.dart';
import '../../models/product_model.dart';
import '../../models/supplier_model.dart';
import '../navigation/app_scaffold.dart';

class PurchasesCreateScreen extends GetView<PurchaseController> {
  const PurchasesCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (controller.formNextPurchaseNumber.value.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.formNextPurchaseNumber.value.isEmpty) {
          controller.prepareNewPurchaseForm();
        }
      });
    }

    return Obx(() => AppScaffold(
      title: controller.isEditing ? 'Edit Purchase Bill' : 'Record Purchase Bill',
      currentRoute: AppRoutes.purchasesCreate,
      actions: [
        AppButton(
          label: 'Cancel',
          type: AppButtonType.text,
          onPressed: () {
            controller.resetForm();
            Get.back();
          },
        ),
        const SizedBox(width: 8),
        AppButton(
          label: controller.isEditing ? 'Update Bill' : 'Save Bill',
          icon: Icons.check,
          isLoading: controller.isSubmitting.value,
          onPressed: controller.isSubmitting.value
              ? null
              : () async {
                  final ok = await controller.submitPurchase();
                  if (ok) {
                    Get.back();
                  }
                },
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Details Card
            AppCard(
              title: 'Purchase Bill Details',
              child: ResponsiveRowColumn(
                spacing: 16,
                children: [
                  Obx(() => AppTextField(
                        key: ValueKey('purch_num_${controller.formNextPurchaseNumber.value}'),
                        label: 'Purchase Bill #',
                        initialValue: controller.formNextPurchaseNumber.value,
                        readOnly: true,
                      )),
                  Obx(() => AppDropdown<SupplierModel>(
                        label: 'Supplier / Vendor *',
                        hint: 'Select Supplier',
                        value: controller.formSelectedSupplier.value,
                        items: controller.suppliers.map((s) {
                          return DropdownMenuItem(value: s, child: Text(s.name));
                        }).toList(),
                        onChanged: (s) => controller.formSelectedSupplier.value = s,
                      )),
                  Obx(() => AppDatePickerField(
                        label: 'Date',
                        value: controller.formPurchaseDate.value,
                        onDateSelected: (d) => controller.formPurchaseDate.value = d,
                      )),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Products Line Items Card
            AppCard(
              title: 'Purchased Items',
              trailing: AppButton(
                label: 'Add Item',
                icon: Icons.add,
                type: AppButtonType.outline,
                onPressed: () => _showAddItemDialog(context),
              ),
              child: Obx(() {
                if (controller.formItems.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.inventory_outlined, size: 36, color: AppColors.neutral),
                          const SizedBox(height: 8),
                          const Text('No items added yet.', style: AppTextStyles.body2),
                          const SizedBox(height: 12),
                          AppButton(
                            label: 'Add Product Item',
                            icon: Icons.add,
                            onPressed: () => _showAddItemDialog(context),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final columns = const [
                  AppTableColumn(title: 'Product', width: 220),
                  AppTableColumn(title: 'Qty', width: 80, alignment: Alignment.centerRight),
                  AppTableColumn(title: 'Rate', width: 110, alignment: Alignment.centerRight),
                  AppTableColumn(title: 'Tax', width: 90, alignment: Alignment.centerRight),
                  AppTableColumn(title: 'Total', width: 120, alignment: Alignment.centerRight),
                  AppTableColumn(title: '', width: 50, alignment: Alignment.center),
                ];

                final rows = List.generate(controller.formItems.length, (index) {
                  final item = controller.formItems[index];
                  return [
                    Text(item.productName ?? 'Product', style: AppTextStyles.tableCellBold),
                    Text('${item.quantity} ${item.unit ?? ''}', style: AppTextStyles.tableCell),
                    Text(CurrencyUtils.format(item.rate), style: AppTextStyles.tableCell),
                    Text(CurrencyUtils.format(item.taxAmount), style: AppTextStyles.tableCell),
                    Text(CurrencyUtils.format(item.total), style: AppTextStyles.tableCellBold),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debit),
                      splashRadius: 16,
                      onPressed: () => controller.removeFormItem(index),
                    ),
                  ];
                });

                return AppTable(columns: columns, rows: rows, minWidth: 760);
              }),
            ),

            const SizedBox(height: 20),

            // Summary Card
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 800;

                final notesWidget = Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      key: ValueKey('purch_notes_${controller.formNextPurchaseNumber.value}'),
                      label: 'Notes / References',
                      initialValue: controller.formNotes.value,
                      hint: 'Supplier reference #, challan #, transport details...',
                      maxLines: 3,
                      onChanged: (v) => controller.formNotes.value = v,
                    ),
                  ],
                ));

                final totalsWidget = Obx(() => Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.surfaceVariantDark
                            : AppColors.surfaceVariantLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          _totalRow('Subtotal', CurrencyUtils.format(controller.formSubtotal)),
                          const SizedBox(height: 6),
                          _totalRow('Tax Amount', CurrencyUtils.format(controller.formTaxTotal)),
                          const Divider(height: 16),
                          _totalRow('Grand Total', CurrencyUtils.format(controller.formGrandTotal), isBold: true),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Flexible(
                                child: Text('Paid Amount', style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 110,
                                child: AppTextField(
                                  key: ValueKey('purch_paid_${controller.formNextPurchaseNumber.value}'),
                                  initialValue: '0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [AppInputFormatters.decimal()],
                                  onChanged: (v) => controller.formPaidAmount.value = double.tryParse(v) ?? 0.0,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          _totalRow(
                            'Balance Payable',
                            CurrencyUtils.format(controller.formBalanceAmount),
                            isBold: true,
                            color: controller.formBalanceAmount > 0 ? AppColors.debit : AppColors.credit,
                          ),
                        ],
                      ),
                    ));

                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: notesWidget),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: totalsWidget),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      totalsWidget,
                      const SizedBox(height: 16),
                      notesWidget,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    ));
  }

  Widget _totalRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: isBold ? AppTextStyles.subtitle2 : AppTextStyles.body2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: isBold
              ? AppTextStyles.metricMedium.copyWith(color: color)
              : AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _showAddItemDialog(BuildContext context) {
    ProductModel? selectedProd;
    final qtyCtrl = TextEditingController(text: '1');
    final rateCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AppDialog(
            title: 'Add Purchase Item',
            maxWidth: 550,
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppDropdown<ProductModel>(
                    label: 'Product Item *',
                    hint: 'Select Product',
                    value: selectedProd,
                    items: controller.products.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text('${p.name} (Stock: ${p.stockQuantity} ${p.unit})'),
                      );
                    }).toList(),
                    onChanged: (p) {
                      setState(() {
                        selectedProd = p;
                        if (p != null) {
                          rateCtrl.text = p.purchasePrice.toString();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  ResponsiveRowColumn(
                    spacing: 12,
                    breakpoint: 450,
                    children: [
                      AppTextField(
                        label: 'Quantity *',
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [AppInputFormatters.decimal()],
                        validator: (v) => double.tryParse(v ?? '') == null ? 'Valid qty required' : null,
                      ),
                      AppTextField(
                        label: 'Purchase Cost/Rate *',
                        controller: rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [AppInputFormatters.decimal()],
                        validator: (v) => double.tryParse(v ?? '') == null ? 'Valid rate required' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ResponsiveRowColumn(
                    spacing: 12,
                    breakpoint: 450,
                    children: [
                      AppTextField(
                        label: 'Discount (₹)',
                        controller: discountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [AppInputFormatters.decimal()],
                      ),
                      AppTextField(
                        label: 'Tax Rate (%)',
                        initialValue: selectedProd?.taxRate.toString() ?? '18',
                        readOnly: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Get.back()),
              AppButton(
                label: 'Add to Bill',
                onPressed: () {
                  if (selectedProd == null) {
                    Get.snackbar('Error', 'Please select a product', snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  if (!formKey.currentState!.validate()) return;

                  final q = double.tryParse(qtyCtrl.text.replaceAll(',', '')) ?? 1.0;
                  final r = double.tryParse(rateCtrl.text.replaceAll(',', '')) ?? selectedProd!.purchasePrice;
                  final d = double.tryParse(discountCtrl.text.replaceAll(',', '')) ?? 0.0;

                  controller.addFormItem(selectedProd!, q, r, d);
                  Get.back();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
