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
                    hint: 'Search...',
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
                  const AppTableColumn(title: 'Actions', width: 170, alignment: Alignment.centerRight),
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
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debit),
                          tooltip: 'Delete Product',
                          splashRadius: 16,
                          onPressed: () => _confirmDeleteProduct(context, p),
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
                    hint: 'Product Code',
                    controller: codeCtrl,
                    validator: (v) => v == null || v.isEmpty ? 'Code required' : null,
                  ),
                  AppTextField(
                    label: 'Barcode',
                    hint: 'Barcode',
                    controller: barcodeCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [AppInputFormatters.digitsOnly],
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty && !RegExp(r'^\d+$').hasMatch(v.trim())) {
                        return 'Barcode must contain numbers only';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Product Name *',
                hint: 'Product Name',
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
                        hint: 'Select Category',
                        value: selectedCat.value,
                        items: controller.categories.map((c) {
                          return DropdownMenuItem(value: c.id, child: Text(c.name));
                        }).toList(),
                        onChanged: (v) => selectedCat.value = v,
                      )),
                  AppTextField(
                    label: 'Unit',
                    hint: 'Unit',
                    controller: unitCtrl,
                  ),
                  AppTextField(
                    label: 'Tax Rate (%)',
                    hint: 'Tax Rate',
                    controller: taxRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [AppInputFormatters.decimal()],
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
                    hint: 'Purchase Price',
                    controller: purchasePriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [AppInputFormatters.decimal()],
                  ),
                  AppTextField(
                    label: 'Sales Price *',
                    hint: 'Selling Price',
                    controller: salesPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [AppInputFormatters.decimal()],
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
                      hint: 'Opening Stock',
                      controller: stockCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [AppInputFormatters.decimal()],
                    ),
                  AppTextField(
                    label: 'Minimum Stock Alert',
                    hint: 'Minimum Stock',
                    controller: minStockCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [AppInputFormatters.decimal()],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (isEdit)
            AppButton(
              label: 'Delete',
              type: AppButtonType.danger,
              icon: Icons.delete_outline,
              onPressed: () {
                Get.back();
                _confirmDeleteProduct(context, product);
              },
            ),
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
                  final cleanBarcode = barcodeCtrl.text.trim();
                  if (cleanBarcode.isNotEmpty && !RegExp(r'^\d+$').hasMatch(cleanBarcode)) return;
                  final pPrice = double.tryParse(purchasePriceCtrl.text.replaceAll(',', '')) ?? 0.0;
                  final sPrice = double.tryParse(salesPriceCtrl.text.replaceAll(',', '')) ?? 0.0;
                  final tRate = double.tryParse(taxRateCtrl.text.replaceAll(',', '')) ?? 0.0;
                  final qty = double.tryParse(stockCtrl.text.replaceAll(',', '')) ?? 0.0;
                  final minQty = double.tryParse(minStockCtrl.text.replaceAll(',', '')) ?? 5.0;

                  final prod = product != null
                      ? product.copyWith(
                          productCode: codeCtrl.text.trim(),
                          barcode: cleanBarcode.isNotEmpty ? cleanBarcode : null,
                          name: nameCtrl.text.trim(),
                          categoryId: selectedCat.value,
                          unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'Nos',
                          purchasePrice: pPrice,
                          salesPrice: sPrice,
                          taxRate: tRate,
                          stockQuantity: product.stockQuantity,
                          minimumStock: minQty,
                        )
                      : ProductModel(
                          productCode: codeCtrl.text.trim(),
                          barcode: cleanBarcode.isNotEmpty ? cleanBarcode : null,
                          name: nameCtrl.text.trim(),
                          categoryId: selectedCat.value,
                          unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'Nos',
                          purchasePrice: pPrice,
                          salesPrice: sPrice,
                          taxRate: tRate,
                          stockQuantity: qty,
                          minimumStock: minQty,
                        );

                  final ok = await controller.saveProduct(prod);
                  if (ok) {
                    if (isEdit) {
                      Get.back();
                    } else {
                      codeCtrl.text = 'PRD-${DateTime.now().millisecondsSinceEpoch % 100000}';
                      barcodeCtrl.clear();
                      nameCtrl.clear();
                      unitCtrl.text = 'Nos';
                      purchasePriceCtrl.text = '0';
                      salesPriceCtrl.text = '0';
                      taxRateCtrl.text = '18';
                      stockCtrl.text = '0';
                      minStockCtrl.text = '5';
                      selectedCat.value = controller.categories.isNotEmpty ? controller.categories.first.id : null;
                      formKey.currentState?.reset();
                    }
                  }
                },
              )),
        ],
      ),
    );
  }

  void _showCategoryDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final editingCategoryId = Rxn<int>();

    Get.dialog(
      AppDialog(
        title: 'Manage Categories',
        maxWidth: 550,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() => Text(
                  editingCategoryId.value != null ? 'Edit Category' : 'Add New Category',
                  style: AppTextStyles.subtitle2,
                )),
            const SizedBox(height: 10),
            AppTextField(
              label: 'Category Name *',
              hint: 'Category Name',
              controller: nameCtrl,
            ),
            const SizedBox(height: 10),
            AppTextField(
              label: 'Description',
              hint: 'Description',
              controller: descCtrl,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Obx(() => editingCategoryId.value != null
                    ? AppButton(
                        label: 'Cancel Edit',
                        type: AppButtonType.text,
                        onPressed: () {
                          editingCategoryId.value = null;
                          nameCtrl.clear();
                          descCtrl.clear();
                        },
                      )
                    : const SizedBox.shrink()),
                const SizedBox(width: 8),
                Obx(() => AppButton(
                      label: editingCategoryId.value != null ? 'Update Category' : 'Save Category',
                      icon: editingCategoryId.value != null ? Icons.save_outlined : Icons.add,
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        await controller.saveCategory(CategoryModel(
                          id: editingCategoryId.value,
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                        ));
                        editingCategoryId.value = null;
                        nameCtrl.clear();
                        descCtrl.clear();
                      },
                    )),
              ],
            ),
            const Divider(height: 28),
            Text('Existing Categories', style: AppTextStyles.subtitle2),
            const SizedBox(height: 10),
            Obx(() {
              if (controller.categories.isEmpty) {
                return const Text('No categories added yet.', style: AppTextStyles.caption);
              }
              return Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: controller.categories.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final cat = controller.categories[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(cat.name, style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: cat.description != null && cat.description!.isNotEmpty
                          ? Text(cat.description!, style: AppTextStyles.caption)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                            tooltip: 'Edit Category',
                            onPressed: () {
                              editingCategoryId.value = cat.id;
                              nameCtrl.text = cat.name;
                              descCtrl.text = cat.description ?? '';
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debit),
                            tooltip: 'Delete Category',
                            onPressed: () => _confirmDeleteCategory(context, cat),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ),
        actions: [
          AppButton(label: 'Done', type: AppButtonType.text, onPressed: () => Get.back()),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, CategoryModel category) {
    Get.dialog(
      AppDialog(
        title: 'Delete Category?',
        maxWidth: 420,
        content: Text(
          'Are you sure you want to delete category "${category.name}"? Products in this category will remain, but will no longer be assigned to this category.',
          style: AppTextStyles.body1,
        ),
        actions: [
          AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Get.back()),
          AppButton(
            label: 'Delete',
            type: AppButtonType.danger,
            icon: Icons.delete_outline,
            onPressed: () async {
              Get.back();
              await controller.deleteCategory(category.id!);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, ProductModel product) {
    Get.dialog(
      AppDialog(
        title: 'Delete Product?',
        maxWidth: 440,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${product.name}" (${product.productCode})?',
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 8),
            Text(
              'Products used in sales or purchase invoices cannot be deleted.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryLight),
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
              await controller.deleteProduct(product);
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
              hint: 'Quantity',
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [AppInputFormatters.decimal()],
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Reason for Adjustment',
              hint: 'Reason',
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
            AppTableColumn(title: 'Action', width: 70, alignment: Alignment.center),
          ];

          final rows = controller.stockTransactions.map((t) {
            return [
              Text(t.transactionDate.toString().split(' ').first, style: AppTextStyles.tableCell),
              Text(t.transactionType, style: AppTextStyles.tableCellBold),
              Text(t.quantityIn > 0 ? '+${t.quantityIn}' : '-', style: AppTextStyles.tableCell.copyWith(color: AppColors.credit)),
              Text(t.quantityOut > 0 ? '-${t.quantityOut}' : '-', style: AppTextStyles.tableCell.copyWith(color: AppColors.debit)),
              Text('${t.balanceQuantity} ${product.unit}', style: AppTextStyles.tableCellBold),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.debit),
                tooltip: 'Delete Movement',
                splashRadius: 14,
                onPressed: () => _confirmDeleteStockTransaction(context, t.id!, product),
              ),
            ];
          }).toList();

          return AppTable(columns: columns, rows: rows, minWidth: 700);
        }),
      ),
    );
  }

  void _confirmDeleteStockTransaction(BuildContext context, int transactionId, ProductModel product) {
    Get.dialog(
      AppDialog(
        title: 'Delete Stock Movement?',
        maxWidth: 420,
        content: const Text(
          'Are you sure you want to delete this stock movement record? The product stock quantity will be reversed accordingly.',
          style: AppTextStyles.body1,
        ),
        actions: [
          AppButton(label: 'Cancel', type: AppButtonType.text, onPressed: () => Get.back()),
          AppButton(
            label: 'Delete',
            type: AppButtonType.danger,
            icon: Icons.delete_outline,
            onPressed: () async {
              Get.back();
              await controller.deleteStockTransaction(transactionId, product);
            },
          ),
        ],
      ),
    );
  }
}
