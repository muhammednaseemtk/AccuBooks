import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/settings_controller.dart';
import '../../core/utils/responsive_utils.dart';

class NavItem {
  final String title;
  final IconData icon;
  final String route;

  const NavItem({
    required this.title,
    required this.icon,
    required this.route,
  });
}

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final String currentRoute;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.currentRoute = '',
    this.actions,
    this.floatingActionButton,
  });

  static const List<NavItem> navItems = [
    NavItem(title: 'Dashboard', icon: Icons.dashboard_outlined, route: AppRoutes.dashboard),
    NavItem(title: 'Accounts', icon: Icons.account_balance_outlined, route: AppRoutes.accounts),
    NavItem(title: 'Customers', icon: Icons.people_outline, route: AppRoutes.customers),
    NavItem(title: 'Suppliers', icon: Icons.local_shipping_outlined, route: AppRoutes.suppliers),
    NavItem(title: 'Products', icon: Icons.inventory_2_outlined, route: AppRoutes.products),
    NavItem(title: 'Sales', icon: Icons.point_of_sale_outlined, route: AppRoutes.sales),
    NavItem(title: 'Purchases', icon: Icons.shopping_cart_outlined, route: AppRoutes.purchases),
    NavItem(title: 'Receipts', icon: Icons.receipt_long_outlined, route: AppRoutes.receipts),
    NavItem(title: 'Payments', icon: Icons.payments_outlined, route: AppRoutes.payments),
    NavItem(title: 'Expenses', icon: Icons.trending_down_outlined, route: AppRoutes.expenses),
    NavItem(title: 'Journals', icon: Icons.menu_book_outlined, route: AppRoutes.journals),
    NavItem(title: 'Reports', icon: Icons.analytics_outlined, route: AppRoutes.reports),
    NavItem(title: 'Settings', icon: Icons.settings_outlined, route: AppRoutes.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    final settingsCtrl = Get.find<SettingsController>();

    return Scaffold(
      appBar: !isDesktop
          ? AppBar(
              title: Text(title, style: AppTextStyles.h3, overflow: TextOverflow.ellipsis),
              actions: [
                ...?actions,
                Obx(() => IconButton(
                      icon: Icon(settingsCtrl.isDarkMode.value ? Icons.light_mode : Icons.dark_mode),
                      onPressed: () => settingsCtrl.toggleTheme(!settingsCtrl.isDarkMode.value),
                      tooltip: 'Toggle Theme',
                    )),
                const SizedBox(width: 8),
              ],
            )
          : null,
      drawer: !isDesktop && !isTablet
          ? Drawer(
              child: _buildNavContent(context, settingsCtrl, isCollapsed: false),
            )
          : null,
      body: Row(
        children: [
          // Desktop permanent sidebar
          if (isDesktop)
            Container(
              width: 240,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  right: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: _buildNavContent(context, settingsCtrl, isCollapsed: false),
            ),

          // Tablet collapsed rail
          if (isTablet)
            Container(
              width: 72,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  right: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: _buildNavContent(context, settingsCtrl, isCollapsed: true),
            ),

          // Main Screen Content Area
          Expanded(
            child: Column(
              children: [
                // Desktop Top App Bar
                if (isDesktop)
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: AppTextStyles.h2.copyWith(
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...?actions,
                                const SizedBox(width: 12),
                                Obx(() => IconButton(
                                      icon: Icon(
                                        settingsCtrl.isDarkMode.value ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                        size: 20,
                                      ),
                                      onPressed: () => settingsCtrl.toggleTheme(!settingsCtrl.isDarkMode.value),
                                      tooltip: 'Toggle Theme',
                                    )),
                                const SizedBox(width: 8),
                                Obx(() {
                                  final comp = settingsCtrl.company.value;
                                  return Chip(
                                    avatar: const Icon(Icons.business, size: 16, color: AppColors.primary),
                                    label: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 150),
                                      child: Text(
                                        comp?.name ?? 'AccuBooks',
                                        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                                    side: BorderSide.none,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Body
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildNavContent(BuildContext context, SettingsController settingsCtrl, {required bool isCollapsed}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // App Logo & Brand Header
        Container(
          height: 64,
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 20),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AccuBooks',
                      style: AppTextStyles.subtitle1.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Local Accounting',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Navigation Items List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            itemCount: navItems.length,
            itemBuilder: (context, index) {
              final item = navItems[index];
              final isSelected = currentRoute == item.route;

              final itemWidget = Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    if (!ResponsiveUtils.isDesktop(context) && !ResponsiveUtils.isTablet(context)) {
                      Navigator.of(context).pop(); // close drawer
                    }
                    if (currentRoute != item.route) {
                      Get.offNamed(item.route);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? AppColors.primaryLight.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.1))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isCollapsed ? 0 : 12,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color: isSelected
                              ? (isDark ? AppColors.primaryLight : AppColors.primary)
                              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        ),
                        if (!isCollapsed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTextStyles.button.copyWith(
                                color: isSelected
                                    ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );

              if (isCollapsed) {
                return Tooltip(
                  message: item.title,
                  preferBelow: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: itemWidget,
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: itemWidget,
              );
            },
          ),
        ),

        // Bottom status / Quick Info
        if (!isCollapsed)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_outlined, size: 16, color: AppColors.credit),
                const SizedBox(width: 8),
                Text(
                  '100% Local & Offline',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
