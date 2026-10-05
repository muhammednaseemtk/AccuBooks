import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/product_controller.dart';
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
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../navigation/app_scaffold.dart';

class ProductsScreen extends GetView<ProductController> {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Products & Inventory',
      currentRoute: AppRoutes.products,
      actions: [
        AppButton(
          label: 'Add Category',
          icon: Icons.category_outlined,
          type: AppButtonType.outline,
          onPressed: () => _showCategoryDialog(context),
        ),
        const SizedBox(width: 8),
        AppButton(
          label: 'Add Product',
          icon: Icons.add_box_outlined,
          onPressed: () => _showProductFormDialog(context),
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
                    hint: 'Search by product name, code, barcode...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    onChanged: controller.setSearch,
                  ),
                  Obx(() => AppDropdown<int>(
                        value: controller.selectedCategoryId.value,
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('All Categories')),
                          ...controller.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (val) => controller.setCategoryFilter(val ?? 0),
                      )),
                  Obx(() => InkWell(
                        onTap: controller.toggleLowStockFilter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: controller.isLowStockOnly.value
                                ? AppColors.debit.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: controller.isLowStockOnly.value ? AppColors.debit : AppColors.borderLight,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: controller.isLowStockOnly.value ? AppColors.debit : AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Low Stock Only',
                                style: AppTextStyles.button.copyWith(
                                  color: controller.isLowStockOnly.value ? AppColors.debit : AppColors.textPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Products Table
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoadingWidget(message: 'Loading inventory products...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return ErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.loadProducts,
                  );
                }

                if (controller.products.isEmpty) {
                  return EmptyState(
                    title: 'No products found',
                    subtitle: 'Add products and items to manage catalog and track inventory.',
                    actionLabel: 'Add Product',
                    onAction: () => _showProductFormDialog(context),
                  );
                }

                final columns = [
                  const AppTableColumn(title: 'Code', width: 90),
                  const AppTableColumn(title: 'Product Name'),
                  const AppTableColumn(title: 'Category', width: 120),
                  const AppTableColumn(title: 'Purchase Price', width: 130, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Sales Price', width: 130, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Stock Qty', width: 130, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Actions', width: 140, alignment: Alignment.centerRight),
                ];

                final rows = controller.products.map((p) {
                  final isLow = p.isLowStock;

                  return [
                    Text(p.productCode, style: AppTextStyles.tableCellBold),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.name, style: AppTextStyles.tableCellBold),
                        if (p.barcode != null && p.barcode!.isNotEmpty)
                          Text('Barcode: ${p.barcode}', style: AppTextStyles.caption),
                      ],
                    ),
                    Text(p.categoryName ?? '-', style: AppTextStyles.tableCell),
                    Text(CurrencyUtils.format(p.purchasePrice), style: AppTextStyles.tableCell),
                    Text(CurrencyUtils.format(p.salesPrice), style: AppTextStyles.tableCellBold),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isLow) ...[
                          const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.debit),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          '${p.stockQuantity} ${p.unit}',
                          style: AppTextStyles.tableCellBold.copyWith(
                            color: isLow ? AppColors.debit : null,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.tune, size: 18),
                          tooltip: 'Adjust Stock',
                          splashRadius: 16,
                          onPressed: () => _showStockAdjustDialog(context, p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.history, size: 18),
                          tooltip: 'Stock Movement History',
                          splashRadius: 16,
                          onPressed: () => _showStockHistoryDialog(context, p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Product',
                          splashRadius: 16,
                          onPressed: () => _showProductFormDialog(context, product: p),
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
                      minWidth: 880,
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

  void _showProductFormDialog(BuildContext context, {ProductModel? product}) {
    final isEdit = product != null;
    final codeCtrl = TextEditingController(text: product?.productCode ?? 'PRD-${DateTime.now().millisecondsSinceEpoch % 100000}');
    final barcodeCtrl = TextEditingController(text: product?.barcode ?? '');
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final unitCtrl = TextEditingController(text: product?.unit ?? 'Nos');
    final purchasePriceCtrl = TextEditingController(text: product?.purchasePrice.toString() ?? '0');
    final salesPriceCtrl = TextEditingController(text: product?.salesPrice.toString() ?? '0');
    final taxRateCtrl = TextEditingController(text: product?.taxRate.toString() ?? '18');
    final stockCtrl = TextEditingController(text: product?.stockQuantity.toString() ?? '0');
    final minStockCtrl = TextEditingController(text: product?.minimumStock.toString() ?? '5');
    final selectedCat = (product?.categoryId ?? (controller.categories.isNotEmpty ? controller.categories.first.id : null)).obs;
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AppDialog(
        title: isEdit ? 'Edit Product' : 'Add New Product',
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 480,
                children: [
                  AppTextField(
                    label: 'Product Code *',
                    controller: codeCtrl,
                    validator: (v) => v == null || v.isEmpty ? 'Code required' : null,
                  ),
                  AppTextField(
                    label: 'Barcode',
                    controller: barcodeCtrl,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Product Name *',
                hint: 'e.g. Wireless Mouse, Dell Monitor, Steel Bar',
                controller: nameCtrl,
                validator: (v) => v == null || v.isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 480,
                children: [
                  Obx(() => AppDropdown<int>(
                        label: 'Category',
                        value: selectedCat.value,
                        items: controller.categories.map((c) {
                          return DropdownMenuItem(value: c.id, child: Text(c.name));
                        }).toList(),
                        onChanged: (v) => selectedCat.value = v,
                      )),
                  AppTextField(
                    label: 'Unit',
                    hint: 'Nos, Pcs, Kg, Box',
                    controller: unitCtrl,
                  ),
                  AppTextField(
                    label: 'Tax Rate (%)',
                    hint: '18',
                    controller: taxRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 480,
                children: [
                  AppTextField(
                    label: 'Purchase Price',
                    hint: '0.00',
                    controller: purchasePriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  AppTextField(
                    label: 'Sales Price *',
                    hint: '0.00',
                    controller: salesPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v == null || v.isEmpty ? 'Sales price required' : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 480,
                children: [
                  if (!isEdit)
                    AppTextField(
                      label: 'Opening Stock',
                      hint: '0',
                      controller: stockCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  AppTextField(
                    label: 'Minimum Stock Alert',
                    hint: '5',
                    controller: minStockCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
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
                label: isEdit ? 'Update' : 'Save Product',
                isLoading: controller.isSubmitting.value,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final pPrice = double.tryParse(purchasePriceCtrl.text.replaceAll(',', '')) ?? 0.0;
                  final sPrice = double.tryParse(salesPriceCtrl.text.replaceAll(',', '')) ?? 0.0;
                  final tRate = double.tryParse(taxRateCtrl.text.replaceAll(',', '')) ?? 0.0;
                  final qty = double.tryParse(stockCtrl.text.replaceAll(',', '')) ?? 0.0;
                  final minQty = double.tryParse(minStockCtrl.text.replaceAll(',', '')) ?? 5.0;

                  final prod = ProductModel(
                    id: product?.id,
                    productCode: codeCtrl.text.trim(),
                    barcode: barcodeCtrl.text.trim().isNotEmpty ? barcodeCtrl.text.trim() : null,
                    name: nameCtrl.text.trim(),
                    categoryId: selectedCat.value,
                    unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'Nos',
                    purchasePrice: pPrice,
                    salesPrice: sPrice,
                    taxRate: tRate,
                    stockQuantity: isEdit ? (product.stockQuantity) : qty,
                    minimumStock: minQty,
                  );

                  final ok = await controller.saveProduct(prod);
                  if (ok) Get.back();
                },
              )),
        ],
      ),
    );
  }

  void _showCategoryDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    Get.dialog(
      AppDialog(
        title: 'Add Category',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'Category Name',
              hint: 'e.g. Electronics, Hardware, Furniture',
              controller: nameCtrl,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Description',
              controller: descCtrl,
            ),
          ],
        ),
        actions: [
          AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Get.back()),
          AppButton(
            label: 'Save',
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await controller.saveCategory(CategoryModel(
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
              ));
              Get.back();
            },
          ),
        ],
      ),
    );
  }

  void _showStockAdjustDialog(BuildContext context, ProductModel product) {
    final qtyCtrl = TextEditingController(text: product.stockQuantity.toString());
    final reasonCtrl = TextEditingController(text: 'Physical Stock Count');

    Get.dialog(
      AppDialog(
        title: 'Adjust Stock: ${product.name}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: ${product.stockQuantity} ${product.unit}', style: AppTextStyles.subtitle2),
            const SizedBox(height: 16),
            AppTextField(
              label: 'New Physical Quantity',
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Reason for Adjustment',
              controller: reasonCtrl,
            ),
          ],
        ),
        actions: [
          AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Get.back()),
          AppButton(
            label: 'Save Adjustment',
            onPressed: () async {
              final newQ = double.tryParse(qtyCtrl.text.replaceAll(',', '')) ?? product.stockQuantity;
              await controller.adjustStock(product.id!, newQ, reasonCtrl.text.trim());
              Get.back();
            },
          ),
        ],
      ),
    );
  }

  void _showStockHistoryDialog(BuildContext context, ProductModel product) {
    controller.loadProductHistory(product);

    Get.dialog(
      AppDialog(
        title: '${product.name} - Stock Movement History',
        maxWidth: 750,
        content: Obx(() {
          if (controller.isLoadingTransactions.value) {
            return const LoadingWidget(message: 'Loading movement audit...');
          }

          if (controller.stockTransactions.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No movement history recorded yet.')),
            );
          }

          final columns = const [
            AppTableColumn(title: 'Date', width: 100),
            AppTableColumn(title: 'Movement Type', width: 140),
            AppTableColumn(title: 'Qty In', width: 90, alignment: Alignment.centerRight),
            AppTableColumn(title: 'Qty Out', width: 90, alignment: Alignment.centerRight),
            AppTableColumn(title: 'Balance', width: 110, alignment: Alignment.centerRight),
          ];

          final rows = controller.stockTransactions.map((t) {
            return [
              Text(t.transactionDate.toString().split(' ').first, style: AppTextStyles.tableCell),
              Text(t.transactionType, style: AppTextStyles.tableCellBold),
              Text(t.quantityIn > 0 ? '+${t.quantityIn}' : '-', style: AppTextStyles.tableCell.copyWith(color: AppColors.credit)),
              Text(t.quantityOut > 0 ? '-${t.quantityOut}' : '-', style: AppTextStyles.tableCell.copyWith(color: AppColors.debit)),
              Text('${t.balanceQuantity} ${product.unit}', style: AppTextStyles.tableCellBold),
            ];
          }).toList();

          return AppTable(columns: columns, rows: rows, minWidth: 650);
        }),
      ),
    );
  }
}
