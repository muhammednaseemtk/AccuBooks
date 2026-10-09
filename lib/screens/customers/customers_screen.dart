import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/customer_controller.dart';
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
import '../../models/customer_model.dart';
import '../navigation/app_scaffold.dart';

class CustomersScreen extends GetView<CustomerController> {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Customers',
      currentRoute: AppRoutes.customers,
      actions: [
        AppButton(
          label: 'Add Customer',
          icon: Icons.person_add_alt,
          onPressed: () => _showCustomerFormDialog(context),
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
                hint: 'Search customers by code, name, or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                onChanged: controller.setSearch,
              ),
            ),

            const SizedBox(height: 16),

            // Customers Table
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoadingWidget(message: 'Loading customers...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return ErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.loadCustomers,
                  );
                }

                if (controller.customers.isEmpty) {
                  return EmptyState(
                    title: 'No customers found',
                    subtitle: 'Add your first customer to start creating sales invoices.',
                    actionLabel: 'Add Customer',
                    onAction: () => _showCustomerFormDialog(context),
                  );
                }

                final columns = [
                  const AppTableColumn(title: 'Code', width: 90),
                  const AppTableColumn(title: 'Customer Name'),
                  const AppTableColumn(title: 'Phone', width: 130),
                  const AppTableColumn(title: 'Total Sales', width: 130, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Receipts', width: 130, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Outstanding', width: 140, alignment: Alignment.centerRight),
                  const AppTableColumn(title: 'Actions', width: 140, alignment: Alignment.centerRight),
                ];

                final rows = controller.customers.map((c) {
                  final hasDue = c.outstandingBalance > 0;

                  return [
                    Text(c.customerCode, style: AppTextStyles.tableCellBold),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(c.name, style: AppTextStyles.tableCellBold),
                        if (c.email != null && c.email!.isNotEmpty)
                          Text(c.email!, style: AppTextStyles.caption),
                      ],
                    ),
                    Text(c.phone ?? '-', style: AppTextStyles.tableCell),
                    Text(CurrencyUtils.format(c.totalSales), style: AppTextStyles.tableCell),
                    Text(CurrencyUtils.format(c.totalReceipts), style: AppTextStyles.tableCell),
                    Text(
                      CurrencyUtils.format(c.outstandingBalance),
                      style: AppTextStyles.tableCellBold.copyWith(
                        color: hasDue ? AppColors.warning : AppColors.credit,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.receipt_long, size: 18),
                          tooltip: 'Customer Statement / Ledger',
                          splashRadius: 16,
                          onPressed: () => _showCustomerLedgerDialog(context, c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Customer',
                          splashRadius: 16,
                          onPressed: () => _showCustomerFormDialog(context, customer: c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.debit),
                          tooltip: 'Delete Customer',
                          splashRadius: 16,
                          onPressed: () => _confirmDeleteCustomer(context, c),
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

  void _showCustomerFormDialog(BuildContext context, {CustomerModel? customer}) {
    final isEdit = customer != null;
    final codeCtrl = TextEditingController(text: customer?.customerCode ?? 'CUST-${DateTime.now().millisecondsSinceEpoch % 100000}');
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final emailCtrl = TextEditingController(text: customer?.email ?? '');
    final addressCtrl = TextEditingController(text: customer?.address ?? '');
    final taxNumCtrl = TextEditingController(text: customer?.taxNumber ?? '');
    final openingCtrl = TextEditingController(text: customer?.openingBalance.toString() ?? '0');
    final selectedObType = (customer?.openingBalanceType ?? AccountingConstants.balanceDebit).obs;
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AppDialog(
        title: isEdit ? 'Edit Customer' : 'Add New Customer',
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
                    label: 'Customer Code',
                    controller: codeCtrl,
                    validator: (v) => v == null || v.isEmpty ? 'Code required' : null,
                  ),
                  AppTextField(
                    label: 'Customer Name *',
                    hint: 'Full Business or Individual Name',
                    controller: nameCtrl,
                    validator: (v) => v == null || v.isEmpty ? 'Name required' : null,
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
                    hint: 'customer@domain.com',
                    controller: emailCtrl,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Address',
                hint: 'Street address, City, Pincode',
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
                      if (v != null && v.trim().isNotEmpty && !RegExp(r'^\d+$').hasMatch(v.trim())) {
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [AppInputFormatters.decimal()],
                    ),
                  if (!isEdit)
                    Obx(() => AppDropdown<String>(
                          label: 'Balance Type',
                          value: selectedObType.value,
                          items: const [
                            DropdownMenuItem(value: AccountingConstants.balanceDebit, child: Text('Debit (Receivable)')),
                            DropdownMenuItem(value: AccountingConstants.balanceCredit, child: Text('Credit (Advance)')),
                          ],
                          onChanged: (v) => selectedObType.value = v ?? AccountingConstants.balanceDebit,
                        )),
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
                _confirmDeleteCustomer(context, customer);
              },
            ),
          AppButton(
            label: 'Cancel',
            type: AppButtonType.text,
            onPressed: () => Get.back(),
          ),
          Obx(() => AppButton(
                label: isEdit ? 'Update' : 'Save Customer',
                isLoading: controller.isSubmitting.value,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final cleanTax = taxNumCtrl.text.trim();
                  if (cleanTax.isNotEmpty && !RegExp(r'^\d+$').hasMatch(cleanTax)) return;
                  final opVal = double.tryParse(openingCtrl.text.replaceAll(',', '')) ?? 0.0;
                  final cust = customer != null
                      ? customer.copyWith(
                          customerCode: codeCtrl.text.trim(),
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          address: addressCtrl.text.trim(),
                          taxNumber: cleanTax,
                          openingBalance: opVal,
                          openingBalanceType: selectedObType.value,
                        )
                      : CustomerModel(
                          customerCode: codeCtrl.text.trim(),
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          address: addressCtrl.text.trim(),
                          taxNumber: cleanTax,
                          openingBalance: opVal,
                          openingBalanceType: selectedObType.value,
                        );

                  final ok = await controller.saveCustomer(cust);
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
                      selectedObType.value = AccountingConstants.balanceDebit;
                      formKey.currentState?.reset();
                    }
                  }
                },
              )),
        ],
      ),
    );
  }

  void _confirmDeleteCustomer(BuildContext context, CustomerModel customer) {
    Get.dialog(
      AppDialog(
        title: 'Delete Customer?',
        maxWidth: 440,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete customer "${customer.name}" (${customer.customerCode})?',
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 8),
            Text(
              'Customers with active invoices, receipts, or sales returns cannot be deleted.',
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
              await controller.deleteCustomer(customer);
            },
          ),
        ],
      ),
    );
  }

  void _showCustomerLedgerDialog(BuildContext context, CustomerModel customer) {
    controller.loadCustomerDetails(customer.id!);

    Get.dialog(
      AppDialog(
        title: '${customer.name} - Statement of Account',
        maxWidth: 900,
        content: Obx(() {
          if (controller.isLoadingLedger.value) {
            return const LoadingWidget(message: 'Calculating customer ledger...');
          }

          final cust = controller.selectedCustomer.value ?? customer;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Total Invoiced', CurrencyUtils.format(cust.totalSales)),
                    _buildSummaryItem('Total Receipts', CurrencyUtils.format(cust.totalReceipts)),
                    _buildSummaryItem(
                      'Outstanding Balance',
                      CurrencyUtils.format(cust.outstandingBalance),
                      color: cust.outstandingBalance > 0 ? AppColors.warning : AppColors.credit,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (controller.customerLedger.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No transactions recorded for this customer.')),
                )
              else ...[
                const Text('Transaction History:', style: AppTextStyles.subtitle2),
                const SizedBox(height: 8),
                AppTable(
                  columns: const [
                    AppTableColumn(title: 'Date', width: 95),
                    AppTableColumn(title: 'Ref #', width: 120),
                    AppTableColumn(title: 'Type', width: 110),
                    AppTableColumn(title: 'Description'),
                    AppTableColumn(title: 'Debit (+)', width: 100, alignment: Alignment.centerRight),
                    AppTableColumn(title: 'Credit (-)', width: 100, alignment: Alignment.centerRight),
                    AppTableColumn(title: 'Balance', width: 110, alignment: Alignment.centerRight),
                  ],
                  rows: controller.customerLedger.map((row) {
                    final d = (row['debit'] as num).toDouble();
                    final c = (row['credit'] as num).toDouble();
                    final b = (row['balance'] as num).toDouble();

                    return [
                      Text(row['date']?.toString().split(' ').first ?? '', style: AppTextStyles.tableCell),
                      Text(row['reference'] ?? '', style: AppTextStyles.tableCellBold),
                      Text(row['type'] ?? '', style: AppTextStyles.tableCell),
                      Text(row['description'] ?? '', style: AppTextStyles.tableCell),
                      Text(d > 0 ? CurrencyUtils.format(d) : '-', style: AppTextStyles.tableCell),
                      Text(c > 0 ? CurrencyUtils.format(c) : '-', style: AppTextStyles.tableCell),
                      Text(CurrencyUtils.format(b), style: AppTextStyles.tableCellBold),
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
