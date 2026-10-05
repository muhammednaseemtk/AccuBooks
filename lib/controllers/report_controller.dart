import 'package:get/get.dart';
import '../models/account_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/journal_repository.dart';
import '../services/report_service.dart';

class ReportController extends GetxController {
  final ReportService _reportService;
  final AccountRepository _accountRepo;
  final JournalRepository _journalRepo;

  ReportController({
    ReportService? reportService,
    AccountRepository? accountRepo,
    JournalRepository? journalRepo,
  })  : _reportService = reportService ?? ReportService(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _journalRepo = journalRepo ?? JournalRepository();

  final accounts = <AccountModel>[].obs;
  final isLoading = false.obs;
  final isExporting = false.obs;
  final errorMessage = ''.obs;

  // Active Tab/Report
  final activeReport = 'Day Book'.obs;

  // Filters
  final selectedDate = DateTime.now().obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();
  final selectedAccount = Rxn<AccountModel>();

  // Report Data Stores
  final dayBookData = <Map<String, dynamic>>[].obs;
  final ledgerData = <Map<String, dynamic>>[].obs;
  final trialBalanceData = Rxn<Map<String, dynamic>>();
  final profitLossData = Rxn<Map<String, dynamic>>();
  final balanceSheetData = Rxn<Map<String, dynamic>>();
  final receivablesData = <Map<String, dynamic>>[].obs;
  final payablesData = <Map<String, dynamic>>[].obs;
  final stockReportData = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadAccounts();
    loadDayBook();
  }

  Future<void> loadAccounts() async {
    try {
      final list = await _accountRepo.getAllAccounts(activeOnly: true);
      accounts.assignAll(list);
      if (accounts.isNotEmpty && selectedAccount.value == null) {
        selectedAccount.value = accounts.first;
      }
    } catch (_) {}
  }

  void switchReport(String reportName) {
    activeReport.value = reportName;
    refreshActiveReport();
  }

  Future<void> refreshActiveReport() async {
    switch (activeReport.value) {
      case 'Day Book':
        await loadDayBook();
        break;
      case 'General Ledger':
        await loadLedger();
        break;
      case 'Trial Balance':
        await loadTrialBalance();
        break;
      case 'Profit & Loss':
        await loadProfitLoss();
        break;
      case 'Balance Sheet':
        await loadBalanceSheet();
        break;
      case 'Receivables':
        await loadReceivables();
        break;
      case 'Payables':
        await loadPayables();
        break;
      case 'Stock Report':
        await loadStockReport();
        break;
    }
  }

  Future<void> loadDayBook() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _reportService.getDayBook(selectedDate.value);
      dayBookData.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load Day Book: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadLedger() async {
    if (selectedAccount.value == null) return;
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final lines = await _journalRepo.getGeneralLedgerLines(
        accountId: selectedAccount.value!.id!,
        fromDate: fromDate.value,
        toDate: toDate.value,
      );
      ledgerData.assignAll(lines);
    } catch (e) {
      errorMessage.value = 'Failed to load Ledger: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadTrialBalance() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final data = await _reportService.getTrialBalance(asOfDate: toDate.value);
      trialBalanceData.value = data;
    } catch (e) {
      errorMessage.value = 'Failed to load Trial Balance: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadProfitLoss() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final data = await _reportService.getProfitAndLoss(
        fromDate: fromDate.value,
        toDate: toDate.value,
      );
      profitLossData.value = data;
    } catch (e) {
      errorMessage.value = 'Failed to load Profit & Loss: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadBalanceSheet() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final data = await _reportService.getBalanceSheet(asOfDate: toDate.value);
      balanceSheetData.value = data;
    } catch (e) {
      errorMessage.value = 'Failed to load Balance Sheet: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadReceivables() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _reportService.getReceivables();
      receivablesData.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load Receivables: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadPayables() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _reportService.getPayables();
      payablesData.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load Payables: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadStockReport() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _reportService.getStockReport();
      stockReportData.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load Stock Report: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportCurrentReportToExcel() async {
    try {
      isExporting.value = true;
      String sheetName = activeReport.value;
      String fileName = '${activeReport.value.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
      List<String> headers = [];
      List<List<dynamic>> rows = [];

      switch (activeReport.value) {
        case 'Day Book':
          headers = ['Date', 'Transaction #', 'Type', 'Description', 'Account Code', 'Account Name', 'Debit', 'Credit'];
          rows = dayBookData.map((d) => [
            d['transaction_date'],
            d['transaction_number'],
            d['transaction_type'],
            d['entry_description'],
            d['account_code'],
            d['account_name'],
            d['debit'],
            d['credit'],
          ]).toList();
          break;

        case 'General Ledger':
          headers = ['Date', 'Transaction #', 'Type', 'Description', 'Debit', 'Credit'];
          rows = ledgerData.map((d) => [
            d['transaction_date'],
            d['transaction_number'],
            d['transaction_type'],
            d['entry_description'] ?? d['line_description'],
            d['debit'],
            d['credit'],
          ]).toList();
          break;

        case 'Trial Balance':
          headers = ['Account Code', 'Account Name', 'Account Type', 'Debit', 'Credit'];
          final lines = (trialBalanceData.value?['lines'] as List?) ?? [];
          rows = lines.map((l) => [
            l['account_code'],
            l['account_name'],
            l['account_type'],
            l['debit'],
            l['credit'],
          ]).toList();
          break;

        case 'Profit & Loss':
          headers = ['Account Code', 'Account Name', 'Amount'];
          final inc = (profitLossData.value?['income_lines'] as List?) ?? [];
          final exp = (profitLossData.value?['expense_lines'] as List?) ?? [];
          rows = [
            ['INCOME', '', ''],
            ...inc.map((l) => [l['account_code'], l['account_name'], l['amount']]),
            ['EXPENSES', '', ''],
            ...exp.map((l) => [l['account_code'], l['account_name'], l['amount']]),
            ['NET PROFIT', '', profitLossData.value?['net_profit'] ?? 0.0],
          ];
          break;

        case 'Balance Sheet':
          headers = ['Account Code', 'Account Name', 'Amount'];
          final assets = (balanceSheetData.value?['assets'] as List?) ?? [];
          final liab = (balanceSheetData.value?['liabilities'] as List?) ?? [];
          final eq = (balanceSheetData.value?['equity'] as List?) ?? [];
          rows = [
            ['ASSETS', '', ''],
            ...assets.map((l) => [l['account_code'], l['account_name'], l['amount']]),
            ['LIABILITIES', '', ''],
            ...liab.map((l) => [l['account_code'], l['account_name'], l['amount']]),
            ['EQUITY', '', ''],
            ...eq.map((l) => [l['account_code'], l['account_name'], l['amount']]),
          ];
          break;

        case 'Receivables':
          headers = ['Customer Code', 'Name', 'Phone', 'Credit Limit', 'Total Due', 'Open Invoices'];
          rows = receivablesData.map((d) => [
            d['customer_code'],
            d['name'],
            d['phone'],
            d['credit_limit'],
            d['total_due'],
            d['open_invoices'],
          ]).toList();
          break;

        case 'Payables':
          headers = ['Supplier Code', 'Name', 'Phone', 'Credit Limit', 'Total Due', 'Open Invoices'];
          rows = payablesData.map((d) => [
            d['supplier_code'],
            d['name'],
            d['phone'],
            d['credit_limit'],
            d['total_due'],
            d['open_invoices'],
          ]).toList();
          break;

        case 'Stock Report':
          headers = ['Product Code', 'Product Name', 'Category', 'Unit', 'Purchase Price', 'Sales Price', 'Closing Stock', 'Inventory Value'];
          rows = stockReportData.map((d) => [
            d['product_code'],
            d['name'],
            d['category_name'],
            d['unit'],
            d['purchase_price'],
            d['sales_price'],
            d['closing_stock'],
            d['stock_value'],
          ]).toList();
          break;
      }

      final path = await _reportService.exportToExcel(
        sheetName: sheetName,
        fileName: fileName,
        headers: headers,
        dataRows: rows,
      );

      if (path != null) {
        Get.snackbar(
          'Export Successful',
          'Excel file saved at: $path',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to export report: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isExporting.value = false;
    }
  }
}
