import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/dashboard_controller.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/loading_widget.dart';
import '../navigation/app_scaffold.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Dashboard',
      currentRoute: AppRoutes.dashboard,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: () => controller.loadDashboardData(),
          tooltip: 'Refresh Data',
        ),
        const SizedBox(width: 8),
        AppButton(
          label: 'New Sale',
          icon: Icons.add,
          onPressed: () => Get.toNamed(AppRoutes.salesCreate),
        ),
      ],
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingWidget(message: 'Calculating financial metrics from database...');
        }

        if (controller.errorMessage.isNotEmpty) {
          return ErrorState(
            message: controller.errorMessage.value,
            onRetry: () => controller.loadDashboardData(),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Metric Cards Grid
                _buildMetricsGrid(context),

                const SizedBox(height: 24),

                // 2. Recent Activity & Low Stock
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 1000;
                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildRecentSalesCard(context)),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: _buildLowStockCard(context)),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildRecentSalesCard(context),
                          const SizedBox(height: 20),
                          _buildLowStockCard(context),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 24),

                // 3. Recent Purchases
                _buildRecentPurchasesCard(context),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 1;
        if (width >= 900) {
          columns = 4;
        } else if (width >= 480) {
          columns = 2;
        }

        final metrics = [
          _MetricData(
            title: "Today's Sales",
            value: CurrencyUtils.format(controller.todaySales.value),
            icon: Icons.trending_up,
            color: AppColors.credit,
          ),
          _MetricData(
            title: "Today's Purchases",
            value: CurrencyUtils.format(controller.todayPurchases.value),
            icon: Icons.shopping_bag_outlined,
            color: AppColors.primary,
          ),
          _MetricData(
            title: 'Total Receivables',
            value: CurrencyUtils.format(controller.totalReceivables.value),
            icon: Icons.call_received,
            color: AppColors.warning,
          ),
          _MetricData(
            title: 'Total Payables',
            value: CurrencyUtils.format(controller.totalPayables.value),
            icon: Icons.call_made,
            color: AppColors.debit,
          ),
          _MetricData(
            title: 'Cash in Hand',
            value: CurrencyUtils.format(controller.cashBalance.value),
            icon: Icons.payments_outlined,
            color: AppColors.secondary,
          ),
          _MetricData(
            title: 'Bank Balance',
            value: CurrencyUtils.format(controller.bankBalance.value),
            icon: Icons.account_balance,
            color: AppColors.info,
          ),
          _MetricData(
            title: 'Total Expenses',
            value: CurrencyUtils.format(controller.totalExpenses.value),
            icon: Icons.receipt_long,
            color: AppColors.debit,
          ),
          _MetricData(
            title: 'Net Profit',
            value: CurrencyUtils.format(controller.netProfit.value),
            icon: Icons.monetization_on_outlined,
            color: controller.netProfit.value >= 0 ? AppColors.credit : AppColors.debit,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 96,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final m = metrics[index];
            return AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          m.title,
                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: m.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(m.icon, size: 16, color: m.color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      m.value,
                      style: AppTextStyles.metricLarge.copyWith(color: m.color),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentSalesCard(BuildContext context) {
    return AppCard(
      title: 'Recent Sales Invoices',
      subtitle: 'Latest customer transactions',
      trailing: TextButton(
        onPressed: () => Get.toNamed(AppRoutes.sales),
        style: TextButton.styleFrom(textStyle: AppTextStyles.button),
        child: const Text('View All'),
      ),
      child: controller.recentSales.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No sales recorded yet.')),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.recentSales.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final sale = controller.recentSales[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.credit.withValues(alpha: 0.1),
                    child: const Icon(Icons.receipt_outlined, color: AppColors.credit, size: 18),
                  ),
                  title: Text(
                    '${sale['customer_name']} (${sale['invoice_number']})',
                    style: AppTextStyles.subtitle2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    sale['invoice_date']?.toString().split(' ').first ?? '',
                    style: AppTextStyles.caption,
                  ),
                  trailing: Text(
                    CurrencyUtils.format((sale['grand_total'] as num?)?.toDouble()),
                    style: AppTextStyles.tableCellBold,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildLowStockCard(BuildContext context) {
    return AppCard(
      title: 'Low Stock Alerts',
      subtitle: 'Products below reorder level',
      trailing: TextButton(
        onPressed: () => Get.toNamed(AppRoutes.products),
        style: TextButton.styleFrom(textStyle: AppTextStyles.button),
        child: const Text('Manage Stock'),
      ),
      child: controller.lowStockProducts.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: AppColors.credit),
                    Text('All stock levels healthy!'),
                  ],
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.lowStockProducts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final prod = controller.lowStockProducts[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                    child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                  ),
                  title: Text(prod.name, style: AppTextStyles.subtitle2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Min: ${prod.minimumStock} ${prod.unit}', style: AppTextStyles.caption),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.debit.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${prod.stockQuantity} ${prod.unit}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.debit, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildRecentPurchasesCard(BuildContext context) {
    return AppCard(
      title: 'Recent Purchases',
      subtitle: 'Latest vendor orders & bills',
      trailing: TextButton(
        onPressed: () => Get.toNamed(AppRoutes.purchases),
        style: TextButton.styleFrom(textStyle: AppTextStyles.button),
        child: const Text('View All'),
      ),
      child: controller.recentPurchases.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No purchases recorded yet.')),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.recentPurchases.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final pur = controller.recentPurchases[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 18),
                  ),
                  title: Text(
                    '${pur['supplier_name']} (${pur['invoice_number']})',
                    style: AppTextStyles.subtitle2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    pur['invoice_date']?.toString().split(' ').first ?? '',
                    style: AppTextStyles.caption,
                  ),
                  trailing: Text(
                    CurrencyUtils.format((pur['grand_total'] as num?)?.toDouble()),
                    style: AppTextStyles.tableCellBold,
                  ),
                );
              },
            ),
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
