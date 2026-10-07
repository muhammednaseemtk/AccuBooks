import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/report_controller.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dropdown.dart';
import '../../core/widgets/app_table.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_widget.dart';
import '../../models/account_model.dart';
import '../navigation/app_scaffold.dart';

class ReportsScreen extends GetView<ReportController> {
  const ReportsScreen({super.key});

  static const List<String> reportCategories = [
    'Day Book',
    'General Ledger',
    'Trial Balance',
    'Profit & Loss',
    'Balance Sheet',
    'Receivables',
    'Payables',
    'Stock Report',
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Financial Reports',
      currentRoute: AppRoutes.reports,
      actions: [
        Obx(() => AppButton(
              label: 'Export to Excel',
              icon: Icons.table_view_outlined,
              isLoading: controller.isExporting.value,
              onPressed: () => controller.exportCurrentReportToExcel(),
            )),
      ],
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Report Selector Tabs Bar
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Obx(() => Row(
                      children: reportCategories.map((report) {
                        final isSelected = controller.activeReport.value == report;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(report),
                            selected: isSelected,
                            onSelected: (_) => controller.switchReport(report),
                            selectedColor: AppColors.primary,
                            labelStyle: AppTextStyles.button.copyWith(
                              color: isSelected ? Colors.white : null,
                            ),
                          ),
                        );
                      }).toList(),
                    )),
              ),
            ),

            const SizedBox(height: 16),

            // Date & Account Filter Controls (Contextual based on active report)
            Obx(() => _buildReportFilterBar(context)),

            const SizedBox(height: 16),

            // Report Content Display
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const LoadingWidget(message: 'Generating report from database records...');
                }

                if (controller.errorMessage.isNotEmpty) {
                  return ErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.refreshActiveReport,
                  );
                }

                switch (controller.activeReport.value) {
                  case 'Day Book':
                    return _buildDayBookView();
                  case 'General Ledger':
                    return _buildLedgerView();
                  case 'Trial Balance':
                    return _buildTrialBalanceView();
                  case 'Profit & Loss':
                    return _buildProfitLossView();
                  case 'Balance Sheet':
                    return _buildBalanceSheetView();
                  case 'Receivables':
                    return _buildReceivablesView();
                  case 'Payables':
                    return _buildPayablesView();
                  case 'Stock Report':
                    return _buildStockReportView();
                  default:
                    return const SizedBox.shrink();
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportFilterBar(BuildContext context) {
    final active = controller.activeReport.value;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          if (active == 'Day Book') ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('Date: ${AppDateUtils.format(controller.selectedDate.value)}', style: AppTextStyles.subtitle2),
                AppButton(
                  label: 'Select Date',
                  icon: Icons.calendar_today,
                  type: AppButtonType.outline,
                  onPressed: () async {
                    final picked = await AppDateUtils.pickDate(
                      context: context,
                      initialDate: controller.selectedDate.value,
                    );
                    if (picked != null) {
                      controller.selectedDate.value = picked;
                      controller.loadDayBook();
                    }
                  },
                ),
              ],
            ),
          ] else if (active == 'General Ledger') ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: AppDropdown<AccountModel>(
                label: 'Account',
                value: controller.selectedAccount.value,
                items: controller.accounts.map((a) {
                  return DropdownMenuItem(value: a, child: Text('${a.accountCode} - ${a.accountName}', overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (a) {
                  controller.selectedAccount.value = a;
                  controller.loadLedger();
                },
              ),
            ),
          ] else ...[
            Text('Financial Year As-of Today: ${AppDateUtils.formatShort(DateTime.now())}',
                style: AppTextStyles.subtitle2),
          ],
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: controller.refreshActiveReport,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // 1. Day Book
  Widget _buildDayBookView() {
    if (controller.dayBookData.isEmpty) {
      return const EmptyState(title: 'No transactions recorded on this date');
    }

    final columns = const [
      AppTableColumn(title: 'Time/Date', width: 95),
      AppTableColumn(title: 'Voucher #', width: 130),
      AppTableColumn(title: 'Type', width: 100),
      AppTableColumn(title: 'Account'),
      AppTableColumn(title: 'Particulars'),
      AppTableColumn(title: 'Debit', width: 110, alignment: Alignment.centerRight),
      AppTableColumn(title: 'Credit', width: 110, alignment: Alignment.centerRight),
    ];

    final rows = controller.dayBookData.map((d) {
      final debit = (d['debit'] as num).toDouble();
      final credit = (d['credit'] as num).toDouble();

      return [
        Text(d['transaction_date']?.toString().split(' ').first ?? '', style: AppTextStyles.tableCell),
        Text(d['transaction_number'] ?? '', style: AppTextStyles.tableCellBold),
        Text(d['transaction_type'] ?? '', style: AppTextStyles.tableCell),
        Text('${d['account_code']} - ${d['account_name']}', style: AppTextStyles.tableCellBold),
        Text(d['line_description'] ?? d['entry_description'] ?? '', style: AppTextStyles.tableCell),
        Text(debit > 0 ? CurrencyUtils.format(debit) : '-', style: AppTextStyles.tableCell),
        Text(credit > 0 ? CurrencyUtils.format(credit) : '-', style: AppTextStyles.tableCell),
      ];
    }).toList();

    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(child: AppTable(columns: columns, rows: rows, minWidth: 800)),
    );
  }

  // 2. General Ledger
  Widget _buildLedgerView() {
    if (controller.ledgerData.isEmpty) {
      return const EmptyState(title: 'No ledger transactions for this account');
    }

    final columns = const [
      AppTableColumn(title: 'Date', width: 100),
      AppTableColumn(title: 'Ref #', width: 130),
      AppTableColumn(title: 'Type', width: 110),
      AppTableColumn(title: 'Particulars'),
      AppTableColumn(title: 'Debit', width: 120, alignment: Alignment.centerRight),
      AppTableColumn(title: 'Credit', width: 120, alignment: Alignment.centerRight),
    ];

    final rows = controller.ledgerData.map((d) {
      final debit = (d['debit'] as num).toDouble();
      final credit = (d['credit'] as num).toDouble();

      return [
        Text(d['transaction_date']?.toString().split(' ').first ?? '', style: AppTextStyles.tableCell),
        Text(d['transaction_number'] ?? '', style: AppTextStyles.tableCellBold),
        Text(d['transaction_type'] ?? '', style: AppTextStyles.tableCell),
        Text(d['line_description'] ?? d['entry_description'] ?? '', style: AppTextStyles.tableCell),
        Text(debit > 0 ? CurrencyUtils.format(debit) : '-', style: AppTextStyles.tableCell),
        Text(credit > 0 ? CurrencyUtils.format(credit) : '-', style: AppTextStyles.tableCell),
      ];
    }).toList();

    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(child: AppTable(columns: columns, rows: rows, minWidth: 700)),
    );
  }

  // 3. Trial Balance
  Widget _buildTrialBalanceView() {
    final data = controller.trialBalanceData.value;
    if (data == null) return const LoadingWidget();

    final lines = (data['lines'] as List?) ?? [];
    final totalDebit = (data['total_debit'] as num?)?.toDouble() ?? 0.0;
    final totalCredit = (data['total_credit'] as num?)?.toDouble() ?? 0.0;
    final isBalanced = data['is_balanced'] as bool? ?? false;

    final columns = const [
      AppTableColumn(title: 'Account Code', width: 110),
      AppTableColumn(title: 'Account Name'),
      AppTableColumn(title: 'Category', width: 120),
      AppTableColumn(title: 'Debit Balance', width: 140, alignment: Alignment.centerRight),
      AppTableColumn(title: 'Credit Balance', width: 140, alignment: Alignment.centerRight),
    ];

    final rows = lines.map((l) {
      final d = (l['debit'] as num).toDouble();
      final c = (l['credit'] as num).toDouble();

      return [
        Text(l['account_code'], style: AppTextStyles.tableCellBold),
        Text(l['account_name'], style: AppTextStyles.tableCellBold),
        Text(l['account_type'], style: AppTextStyles.tableCell),
        Text(d > 0 ? CurrencyUtils.format(d) : '-', style: AppTextStyles.tableCell),
        Text(c > 0 ? CurrencyUtils.format(c) : '-', style: AppTextStyles.tableCell),
      ];
    }).toList();

    return Column(
      children: [
        Expanded(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(child: AppTable(columns: columns, rows: rows, minWidth: 700)),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isBalanced ? AppColors.credit.withValues(alpha: 0.1) : AppColors.debit.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isBalanced ? AppColors.credit : AppColors.debit),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('Total Debit: ${CurrencyUtils.format(totalDebit)}', style: AppTextStyles.h3),
              Text('Total Credit: ${CurrencyUtils.format(totalCredit)}', style: AppTextStyles.h3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isBalanced ? Icons.check_circle : Icons.error, color: isBalanced ? AppColors.credit : AppColors.debit),
                  const SizedBox(width: 8),
                  Text(isBalanced ? 'Trial Balance Matches' : 'Difference: ${CurrencyUtils.format((totalDebit - totalCredit).abs())}',
                      style: AppTextStyles.tableCellBold.copyWith(color: isBalanced ? AppColors.credit : AppColors.debit)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 4. Profit & Loss
  Widget _buildProfitLossView() {
    final data = controller.profitLossData.value;
    if (data == null) return const LoadingWidget();

    final income = (data['income_lines'] as List?) ?? [];
    final expenses = (data['expense_lines'] as List?) ?? [];
    final totalIncome = (data['total_income'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (data['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final netProfit = (data['net_profit'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Income Section
          AppCard(
            title: 'Operating Revenue & Income',
            child: Column(
              children: [
                ...income.map((i) => _reportLineItem(i['account_code'], i['account_name'], (i['amount'] as num).toDouble())),
                const Divider(),
                _reportTotalRow('Total Operating Income', totalIncome, color: AppColors.credit),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Expenses Section
          AppCard(
            title: 'Cost of Goods & Operating Expenses',
            child: Column(
              children: [
                ...expenses.map((e) => _reportLineItem(e['account_code'], e['account_name'], (e['amount'] as num).toDouble())),
                const Divider(),
                _reportTotalRow('Total Expenses', totalExpenses, color: AppColors.debit),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Net Profit Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: netProfit >= 0 ? AppColors.credit.withValues(alpha: 0.1) : AppColors.debit.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: netProfit >= 0 ? AppColors.credit : AppColors.debit),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(netProfit >= 0 ? 'NET PROFIT FOR PERIOD' : 'NET LOSS FOR PERIOD', style: AppTextStyles.h2),
                Text(CurrencyUtils.format(netProfit),
                    style: AppTextStyles.metricLarge.copyWith(color: netProfit >= 0 ? AppColors.credit : AppColors.debit)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. Balance Sheet
  Widget _buildBalanceSheetView() {
    final data = controller.balanceSheetData.value;
    if (data == null) return const LoadingWidget();

    final assets = (data['assets'] as List?) ?? [];
    final liabilities = (data['liabilities'] as List?) ?? [];
    final equity = (data['equity'] as List?) ?? [];
    final totalAssets = (data['total_assets'] as num?)?.toDouble() ?? 0.0;
    final totalLiab = (data['total_liabilities'] as num?)?.toDouble() ?? 0.0;
    final totalEq = (data['total_equity'] as num?)?.toDouble() ?? 0.0;
    final isBalanced = data['is_balanced'] as bool? ?? false;

    return SingleChildScrollView(
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 750;
              final assetsCard = AppCard(
                title: 'Assets',
                child: Column(
                  children: [
                    ...assets.map((a) => _reportLineItem(a['account_code'], a['account_name'], (a['amount'] as num).toDouble())),
                    const Divider(),
                    _reportTotalRow('Total Assets', totalAssets, color: AppColors.credit),
                  ],
                ),
              );

              final liabEquities = Column(
                children: [
                  AppCard(
                    title: 'Liabilities',
                    child: Column(
                      children: [
                        ...liabilities.map((l) => _reportLineItem(l['account_code'], l['account_name'], (l['amount'] as num).toDouble())),
                        const Divider(),
                        _reportTotalRow('Total Liabilities', totalLiab),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    title: "Equity & Retained Earnings",
                    child: Column(
                      children: [
                        ...equity.map((e) => _reportLineItem(e['account_code'], e['account_name'], (e['amount'] as num).toDouble())),
                        const Divider(),
                        _reportTotalRow('Total Equity', totalEq),
                      ],
                    ),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: assetsCard),
                    const SizedBox(width: 16),
                    Expanded(child: liabEquities),
                  ],
                );
              } else {
                return Column(
                  children: [
                    assetsCard,
                    const SizedBox(height: 16),
                    liabEquities,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // Balance Sheet Equation Verification
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isBalanced ? AppColors.credit.withValues(alpha: 0.1) : AppColors.debit.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isBalanced ? AppColors.credit : AppColors.debit),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Assets: ${CurrencyUtils.format(totalAssets)}', style: AppTextStyles.h3),
                Text('Liabilities + Equity: ${CurrencyUtils.format(totalLiab + totalEq)}', style: AppTextStyles.h3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isBalanced ? Icons.check_circle : Icons.error, color: isBalanced ? AppColors.credit : AppColors.debit),
                    const SizedBox(width: 8),
                    Text(isBalanced ? 'Accounting Equation Balanced' : 'Unbalanced Balance Sheet',
                        style: AppTextStyles.tableCellBold.copyWith(color: isBalanced ? AppColors.credit : AppColors.debit)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 6. Receivables Report
  Widget _buildReceivablesView() {
    if (controller.receivablesData.isEmpty) {
      return const EmptyState(title: 'No outstanding customer balances');
    }

    final columns = const [
      AppTableColumn(title: 'Code', width: 90),
      AppTableColumn(title: 'Customer Name'),
      AppTableColumn(title: 'Phone', width: 130),
      AppTableColumn(title: 'Open Invoices', width: 120, alignment: Alignment.center),
      AppTableColumn(title: 'Total Due (Receivable)', width: 170, alignment: Alignment.centerRight),
    ];

    final rows = controller.receivablesData.map((d) {
      return [
        Text(d['customer_code'] ?? '', style: AppTextStyles.tableCellBold),
        Text(d['name'] ?? '', style: AppTextStyles.tableCellBold),
        Text(d['phone'] ?? '-', style: AppTextStyles.tableCell),
        Text('${d['open_invoices']} invoices', style: AppTextStyles.tableCell),
        Text(CurrencyUtils.format((d['total_due'] as num).toDouble()),
            style: AppTextStyles.tableCellBold.copyWith(color: AppColors.warning)),
      ];
    }).toList();

    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(child: AppTable(columns: columns, rows: rows, minWidth: 700)),
    );
  }

  // 7. Payables Report
  Widget _buildPayablesView() {
    if (controller.payablesData.isEmpty) {
      return const EmptyState(title: 'No outstanding supplier payables');
    }

    final columns = const [
      AppTableColumn(title: 'Code', width: 90),
      AppTableColumn(title: 'Supplier Name'),
      AppTableColumn(title: 'Phone', width: 130),
      AppTableColumn(title: 'Open Bills', width: 120, alignment: Alignment.center),
      AppTableColumn(title: 'Total Payable', width: 170, alignment: Alignment.centerRight),
    ];

    final rows = controller.payablesData.map((d) {
      return [
        Text(d['supplier_code'] ?? '', style: AppTextStyles.tableCellBold),
        Text(d['name'] ?? '', style: AppTextStyles.tableCellBold),
        Text(d['phone'] ?? '-', style: AppTextStyles.tableCell),
        Text('${d['open_invoices']} bills', style: AppTextStyles.tableCell),
        Text(CurrencyUtils.format((d['total_due'] as num).toDouble()),
            style: AppTextStyles.tableCellBold.copyWith(color: AppColors.debit)),
      ];
    }).toList();

    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(child: AppTable(columns: columns, rows: rows, minWidth: 700)),
    );
  }

  // 8. Stock Report
  Widget _buildStockReportView() {
    if (controller.stockReportData.isEmpty) {
      return const EmptyState(title: 'No product inventory records');
    }

    final columns = const [
      AppTableColumn(title: 'Code', width: 90),
      AppTableColumn(title: 'Product Name'),
      AppTableColumn(title: 'Category', width: 120),
      AppTableColumn(title: 'Unit Cost', width: 120, alignment: Alignment.centerRight),
      AppTableColumn(title: 'Closing Stock', width: 120, alignment: Alignment.centerRight),
      AppTableColumn(title: 'Stock Valuation', width: 140, alignment: Alignment.centerRight),
    ];

    final rows = controller.stockReportData.map((d) {
      return [
        Text(d['product_code'] ?? '', style: AppTextStyles.tableCellBold),
        Text(d['name'] ?? '', style: AppTextStyles.tableCellBold),
        Text(d['category_name'] ?? '-', style: AppTextStyles.tableCell),
        Text(CurrencyUtils.format((d['purchase_price'] as num).toDouble()), style: AppTextStyles.tableCell),
        Text('${d['closing_stock']} ${d['unit']}', style: AppTextStyles.tableCellBold),
        Text(CurrencyUtils.format((d['stock_value'] as num).toDouble()),
            style: AppTextStyles.tableCellBold.copyWith(color: AppColors.primary)),
      ];
    }).toList();

    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(child: AppTable(columns: columns, rows: rows, minWidth: 750)),
    );
  }

  Widget _reportLineItem(String code, String name, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '$code - $name',
              style: AppTextStyles.body2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(CurrencyUtils.format(amount), style: AppTextStyles.tableCellBold),
        ],
      ),
    );
  }

  Widget _reportTotalRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.subtitle1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(CurrencyUtils.format(amount), style: AppTextStyles.metricMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}
