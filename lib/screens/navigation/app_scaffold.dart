import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../controllers/auth_controller.dart';
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
          // Desktop and Tablet permanent sidebar (collapsible)
          if (isDesktop || isTablet)
            Obx(() {
              final isCollapsed = settingsCtrl.isSidebarCollapsed.value;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                width: isCollapsed ? 76 : 240,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  border: Border(
                    right: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                ),
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: isCollapsed ? 76 : 240,
                    maxWidth: isCollapsed ? 76 : 240,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: isCollapsed ? 76 : 240,
                      child: _buildNavContent(context, settingsCtrl, isCollapsed: isCollapsed),
                    ),
                  ),
                ),
              );
            }),

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
                                if (Get.isRegistered<AuthController>()) ...[
                                  const SizedBox(width: 8),
                                  Obx(() {
                                    final user = Get.find<AuthController>().currentUser;
                                    return InkWell(
                                      onTap: () => Get.toNamed(AppRoutes.profile),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Chip(
                                        avatar: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: AppColors.primary,
                                          child: Text(
                                            (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0].toUpperCase() : 'U',
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        label: Text(
                                          user?.roleDisplayName ?? 'Owner',
                                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                                        side: BorderSide.none,
                                      ),
                                    );
                                  }),
                                ],
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
        // App Logo & Brand Header (Clickable Sidebar Toggle)
        Container(
          height: 64,
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
          ),
          child: isCollapsed
              ? Center(
                  child: Tooltip(
                    message: 'Expand Sidebar',
                    waitDuration: const Duration(milliseconds: 150),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (!ResponsiveUtils.isDesktop(context) && !ResponsiveUtils.isTablet(context)) {
                            Navigator.of(context).maybePop();
                          } else {
                            settingsCtrl.toggleSidebar();
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            width: 34,
                            height: 34,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (!ResponsiveUtils.isDesktop(context) && !ResponsiveUtils.isTablet(context)) {
                        Navigator.of(context).maybePop();
                      } else {
                        settingsCtrl.toggleSidebar();
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Tooltip(
                      message: 'Collapse Sidebar',
                      waitDuration: const Duration(milliseconds: 150),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/app_logo.png',
                              width: 34,
                              height: 34,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AccuBooks',
                                    style: AppTextStyles.subtitle1.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Local Accounting',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 10,
                                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),

        // Navigation Items List
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              vertical: 10,
              horizontal: isCollapsed ? 12 : 10,
            ),
            itemCount: navItems.length,
            separatorBuilder: (context, index) => SizedBox(height: isCollapsed ? 6 : 4),
            itemBuilder: (context, index) {
              final item = navItems[index];
              final isSelected = currentRoute == item.route;

              final itemWidget = Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    if (currentRoute == item.route) {
                      if (!ResponsiveUtils.isDesktop(context) && !ResponsiveUtils.isTablet(context)) {
                        Navigator.of(context).pop();
                      }
                      return;
                    }
                    if (!ResponsiveUtils.isDesktop(context) && !ResponsiveUtils.isTablet(context)) {
                      Navigator.of(context).pop();
                    }
                    Get.offNamed(item.route);
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? AppColors.primaryLight.withValues(alpha: 0.18)
                              : AppColors.primary.withValues(alpha: 0.12))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(
                              color: (isDark ? AppColors.primaryLight : AppColors.primary).withValues(alpha: 0.35),
                              width: 1,
                            )
                          : null,
                    ),
                    child: isCollapsed
                        ? Center(
                            child: Icon(
                              item.icon,
                              size: 22,
                              color: isSelected
                                  ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 20,
                                  color: isSelected
                                      ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                ),
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              );

              if (isCollapsed) {
                return Tooltip(
                  message: item.title,
                  preferBelow: false,
                  verticalOffset: 0,
                  margin: const EdgeInsets.only(left: 14),
                  waitDuration: const Duration(milliseconds: 150),
                  child: itemWidget,
                );
              }

              return itemWidget;
            },
          ),
        ),



        // Bottom status / User profile & Logout
        if (Get.isRegistered<AuthController>())
          Obx(() {
            final authCtrl = Get.find<AuthController>();
            final user = authCtrl.currentUser;

            if (isCollapsed) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Tooltip(
                  message: 'Logout (${user?.fullName ?? 'User'})',
                  waitDuration: const Duration(milliseconds: 150),
                  child: IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.grey),
                    onPressed: () => authCtrl.confirmLogout(),
                    splashRadius: 18,
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => Get.toNamed(AppRoutes.profile),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user?.fullName ?? 'AccuBooks User',
                            style: AppTextStyles.button.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user?.roleDisplayName ?? 'Owner',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.grey),
                    tooltip: 'Logout',
                    onPressed: () => authCtrl.confirmLogout(),
                  ),
                ],
              ),
            );
          })
        else if (!isCollapsed)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.credit),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AccuBooks SaaS',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
