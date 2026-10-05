import 'package:get/get.dart';
import '../services/report_service.dart';

class DashboardController extends GetxController {
  final ReportService _reportService;

  DashboardController({ReportService? reportService})
      : _reportService = reportService ?? ReportService();

  final isLoading = true.obs;
  final errorMessage = ''.obs;

  // Metrics
  final todaySales = 0.0.obs;
  final todayPurchases = 0.0.obs;
  final cashBalance = 0.0.obs;
  final bankBalance = 0.0.obs;
  final totalReceivables = 0.0.obs;
  final totalPayables = 0.0.obs;
  final totalExpenses = 0.0.obs;
  final totalIncome = 0.0.obs;
  final netProfit = 0.0.obs;

  // Recent lists
  final recentSales = <Map<String, dynamic>>[].obs;
  final recentPurchases = <Map<String, dynamic>>[].obs;
  final lowStockProducts = <dynamic>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final data = await _reportService.getDashboardMetrics();

      todaySales.value = data['today_sales'] as double;
      todayPurchases.value = data['today_purchases'] as double;
      cashBalance.value = data['cash_balance'] as double;
      bankBalance.value = data['bank_balance'] as double;
      totalReceivables.value = data['total_receivables'] as double;
      totalPayables.value = data['total_payables'] as double;
      totalExpenses.value = data['total_expenses'] as double;
      totalIncome.value = data['total_income'] as double;
      netProfit.value = data['net_profit'] as double;

      recentSales.assignAll(List<Map<String, dynamic>>.from(data['recent_sales'] as List));
      recentPurchases.assignAll(List<Map<String, dynamic>>.from(data['recent_purchases'] as List));
      lowStockProducts.assignAll(data['low_stock_products'] as List);
    } catch (e) {
      errorMessage.value = 'Failed to load dashboard data: $e';
    } finally {
      isLoading.value = false;
    }
  }
}
