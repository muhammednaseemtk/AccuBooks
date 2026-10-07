import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/supplier_controller.dart';
import '../../core/constants/accounting_constants.dart';
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
import '../../models/supplier_model.dart';
import '../navigation/app_scaffold.dart';

class SuppliersScreen extends GetView<SupplierController> {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Suppliers',
      currentRoute: AppRoutes.suppliers,
      actions: [
        AppButton(
          label: 'Add Supplier',
          icon: Icons.local_shipping_outlined,
          onPressed: () => _showSupplierFormDialog(context),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Search Bar
            AppCard(
              padding: const EdgeInsets.all(12),
              child: AppTextField(
                hint: 'Search suppliers by code, name, or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                onChanged: controller.setSearch,
              ),
            ),

            const SizedBox(height: 16),

            // Suppliers Table
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoadingWidget(message: 'Loading suppliers...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return ErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.loadSuppliers,
                  );
                }

                if (controller.suppliers.isEmpty) {
                  return EmptyState(
                    title: 'No suppliers found',
                    subtitle:
                        'Add your first supplier to record inventory purchases.',
                    actionLabel: 'Add Supplier',
                    onAction: () => _showSupplierFormDialog(context),
                  );
                }

                final columns = [
                  const AppTableColumn(title: 'Code', width: 90),
                  const AppTableColumn(title: 'Supplier Name'),
                  const AppTableColumn(title: 'Phone', width: 130),
                  const AppTableColumn(
                    title: 'Purchases',
                    width: 130,
                    alignment: Alignment.centerRight,
                  ),
                  const AppTableColumn(
                    title: 'Payments',
                    width: 130,
                    alignment: Alignment.centerRight,
                  ),
                  const AppTableColumn(
                    title: 'Outstanding Payable',
                    width: 160,
                    alignment: Alignment.centerRight,
                  ),
                  const AppTableColumn(
                    title: 'Actions',
                    width: 140,
                    alignment: Alignment.centerRight,
                  ),
                ];

                final rows = controller.suppliers.map((s) {
                  final hasDue = s.outstandingBalance > 0;

                  return [
                    Text(s.supplierCode, style: AppTextStyles.tableCellBold),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.name, style: AppTextStyles.tableCellBold),
                        if (s.email != null && s.email!.isNotEmpty)
                          Text(s.email!, style: AppTextStyles.caption),
                      ],
                    ),
                    Text(s.phone ?? '-', style: AppTextStyles.tableCell),
                    Text(
                      CurrencyUtils.format(s.totalPurchases),
                      style: AppTextStyles.tableCell,
                    ),
                    Text(
                      CurrencyUtils.format(s.totalPayments),
                      style: AppTextStyles.tableCell,
                    ),
                    Text(
                      CurrencyUtils.format(s.outstandingBalance),
                      style: AppTextStyles.tableCellBold.copyWith(
                        color: hasDue ? AppColors.debit : AppColors.credit,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.receipt_long, size: 18),
                          tooltip: 'Supplier Ledger / Statement',
                          splashRadius: 16,
                          onPressed: () =>
                              _showSupplierLedgerDialog(context, s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Supplier',
                          splashRadius: 16,
                          onPressed: () =>
                              _showSupplierFormDialog(context, supplier: s),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.debit,
                          ),
                          tooltip: 'Delete Supplier',
                          splashRadius: 16,
                          onPressed: () => _confirmDeleteSupplier(context, s),
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

  void _showSupplierFormDialog(
    BuildContext context, {
    SupplierModel? supplier,
  }) {
    final isEdit = supplier != null;
    final codeCtrl = TextEditingController(
      text:
          supplier?.supplierCode ??
          'SUP-${DateTime.now().millisecondsSinceEpoch % 100000}',
    );
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final emailCtrl = TextEditingController(text: supplier?.email ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final taxNumCtrl = TextEditingController(text: supplier?.taxNumber ?? '');
    final openingCtrl = TextEditingController(
      text: supplier?.openingBalance.toString() ?? '0',
    );
    final selectedObType =
        (supplier?.openingBalanceType ?? AccountingConstants.balanceCredit).obs;
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AppDialog(
        title: isEdit ? 'Edit Supplier' : 'Add New Supplier',
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 450,
                children: [
                  AppTextField(
                    label: 'Supplier Code',
                    controller: codeCtrl,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Code required' : null,
                  ),
                  AppTextField(
                    label: 'Supplier Name *',
                    hint: 'Vendor or Company Name',
                    controller: nameCtrl,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Name required' : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 450,
                children: [
                  AppTextField(
                    label: 'Phone Number',
                    hint: '+91 98765 00000',
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [AppInputFormatters.digitsOnly],
                  ),
                  AppTextField(
                    label: 'Email',
                    hint: 'vendor@domain.com',
                    controller: emailCtrl,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Address',
                hint: 'Warehouse, Street address, City',
                controller: addressCtrl,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              ResponsiveRowColumn(
                spacing: 12,
                breakpoint: 500,
                children: [
                  AppTextField(
                    label: 'GSTIN / Tax ID',
                    hint: 'e.g. 29ABCDE1234F1Z5',
                    controller: taxNumCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [AppInputFormatters.digitsOnly],
                    validator: (v) {
                      if (v != null &&
                          v.trim().isNotEmpty &&
                          !RegExp(r'^\d+$').hasMatch(v.trim())) {
                        return 'Tax ID must contain numbers only';
                      }
                      return null;
                    },
                  ),
                  if (!isEdit)
                    AppTextField(
                      label: 'Opening Balance',
                      hint: '0.00',
                      controller: openingCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [AppInputFormatters.decimal()],
                    ),
                  if (!isEdit)
                    Obx(
                      () => AppDropdown<String>(
                        label: 'Balance Type',
                        value: selectedObType.value,
                        items: const [
                          DropdownMenuItem(
                            value: AccountingConstants.balanceCredit,
                            child: Text('Credit (Payable)'),
                          ),
                          DropdownMenuItem(
                            value: AccountingConstants.balanceDebit,
                            child: Text('Debit (Advance)'),
                          ),
                        ],
                        onChanged: (v) => selectedObType.value =
                            v ?? AccountingConstants.balanceCredit,
                      ),
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
                _confirmDeleteSupplier(context, supplier);
              },
            ),
          AppButton(
            label: 'Cancel',
            type: AppButtonType.text,
            onPressed: () => Get.back(),
          ),
          Obx(
            () => AppButton(
              label: isEdit ? 'Update' : 'Save Supplier',
              isLoading: controller.isSubmitting.value,
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final cleanTax = taxNumCtrl.text.trim();
                if (cleanTax.isNotEmpty && !RegExp(r'^\d+$').hasMatch(cleanTax))
                  return;
                final opVal =
                    double.tryParse(openingCtrl.text.replaceAll(',', '')) ??
                    0.0;
                final sup = SupplierModel(
                  id: supplier?.id,
                  supplierCode: codeCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  taxNumber: cleanTax,
                  openingBalance: opVal,
                  openingBalanceType: selectedObType.value,
                );

                final ok = await controller.saveSupplier(sup);
                if (ok) {
                  if (isEdit) {
                    Get.back();
                  } else {
                    codeCtrl.clear();
                    nameCtrl.clear();
                    phoneCtrl.clear();
                    emailCtrl.clear();
                    addressCtrl.clear();
                    taxNumCtrl.clear();
                    openingCtrl.clear();
                    selectedObType.value = AccountingConstants.balanceCredit;
                    formKey.currentState?.reset();
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSupplier(BuildContext context, SupplierModel supplier) {
    Get.dialog(
      AppDialog(
        title: 'Delete Supplier?',
        maxWidth: 440,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete supplier "${supplier.name}" (${supplier.supplierCode})?',
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 8),
            Text(
              'Suppliers with active purchase invoices or payments cannot be deleted.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondaryLight,
              ),
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
              await controller.deleteSupplier(supplier);
            },
          ),
        ],
      ),
    );
  }

  void _showSupplierLedgerDialog(BuildContext context, SupplierModel supplier) {
    controller.loadSupplierDetails(supplier.id!);

    Get.dialog(
      AppDialog(
        title: '${supplier.name} - Statement of Account',
        maxWidth: 900,
        content: Obx(() {
          if (controller.isLoadingLedger.value) {
            return const LoadingWidget(
              message: 'Calculating supplier ledger...',
            );
          }

          final sup = controller.selectedSupplier.value ?? supplier;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      'Total Purchases',
                      CurrencyUtils.format(sup.totalPurchases),
                    ),
                    _buildSummaryItem(
                      'Total Payments',
                      CurrencyUtils.format(sup.totalPayments),
                    ),
                    _buildSummaryItem(
                      'Outstanding Payable',
                      CurrencyUtils.format(sup.outstandingBalance),
                      color: sup.outstandingBalance > 0
                          ? AppColors.debit
                          : AppColors.credit,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (controller.supplierLedger.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No transactions recorded for this supplier.'),
                  ),
                )
              else ...[
                const Text(
                  'Transaction History:',
                  style: AppTextStyles.subtitle2,
                ),
                const SizedBox(height: 8),
                AppTable(
                  columns: const [
                    AppTableColumn(title: 'Date', width: 95),
                    AppTableColumn(title: 'Ref #', width: 120),
                    AppTableColumn(title: 'Type', width: 110),
                    AppTableColumn(title: 'Description'),
                    AppTableColumn(
                      title: 'Debit (-)',
                      width: 100,
                      alignment: Alignment.centerRight,
                    ),
                    AppTableColumn(
                      title: 'Credit (+)',
                      width: 100,
                      alignment: Alignment.centerRight,
                    ),
                    AppTableColumn(
                      title: 'Balance',
                      width: 110,
                      alignment: Alignment.centerRight,
                    ),
                  ],
                  rows: controller.supplierLedger.map((row) {
                    final d = (row['debit'] as num).toDouble();
                    final c = (row['credit'] as num).toDouble();
                    final b = (row['balance'] as num).toDouble();

                    return [
                      Text(
                        row['date']?.toString().split(' ').first ?? '',
                        style: AppTextStyles.tableCell,
                      ),
                      Text(
                        row['reference'] ?? '',
                        style: AppTextStyles.tableCellBold,
                      ),
                      Text(row['type'] ?? '', style: AppTextStyles.tableCell),
                      Text(
                        row['description'] ?? '',
                        style: AppTextStyles.tableCell,
                      ),
                      Text(
                        d > 0 ? CurrencyUtils.format(d) : '-',
                        style: AppTextStyles.tableCell,
                      ),
                      Text(
                        c > 0 ? CurrencyUtils.format(c) : '-',
                        style: AppTextStyles.tableCell,
                      ),
                      Text(
                        CurrencyUtils.format(b),
                        style: AppTextStyles.tableCellBold,
                      ),
                    ];
                  }).toList(),
                  minWidth: 780,
                ),
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.metricMedium.copyWith(color: color)),
      ],
    );
  }
}
