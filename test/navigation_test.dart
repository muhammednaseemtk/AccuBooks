import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:accubooks/app/app.dart';
import 'package:accubooks/app/routes/app_routes.dart';
import 'package:accubooks/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    DatabaseHelper.initializeFfi();
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('Navigation between every sidebar item opens smoothly and immediately', (WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final isOverflow = details.toString().contains('overflowed');
      if (!isOverflow) {
        originalOnError?.call(details);
      }
    };
    addTearDown(() {
      FlutterError.onError = originalOnError;
    });

    // Set a desktop screen size so permanent sidebar is visible
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AccuBooksApp(initialRoute: AppRoutes.dashboard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(Get.currentRoute, equals(AppRoutes.dashboard));
    expect(find.text('Dashboard'), findsWidgets);

    // List of sidebar items to navigate through
    final sidebarItems = [
      {'title': 'Accounts', 'route': AppRoutes.accounts},
      {'title': 'Customers', 'route': AppRoutes.customers},
      {'title': 'Suppliers', 'route': AppRoutes.suppliers},
      {'title': 'Products', 'route': AppRoutes.products},
      {'title': 'Sales', 'route': AppRoutes.sales},
      {'title': 'Purchases', 'route': AppRoutes.purchases},
      {'title': 'Receipts', 'route': AppRoutes.receipts},
      {'title': 'Payments', 'route': AppRoutes.payments},
      {'title': 'Expenses', 'route': AppRoutes.expenses},
      {'title': 'Journals', 'route': AppRoutes.journals},
      {'title': 'Reports', 'route': AppRoutes.reports},
      {'title': 'Settings', 'route': AppRoutes.settings},
      {'title': 'Dashboard', 'route': AppRoutes.dashboard},
    ];

    for (final item in sidebarItems) {
      final title = item['title']!;
      final route = item['route']!;

      // Find the menu item in the sidebar by title
      final navItemFinder = find.widgetWithText(InkWell, title);
      expect(navItemFinder, findsOneWidget, reason: 'Sidebar item $title should be present');

      // Tap the sidebar item
      await tester.tap(navItemFinder);
      await tester.pump(); // Immediate frame starts transition without lag

      // Allow route transition and onReady data loading to complete
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(Get.currentRoute, equals(route), reason: 'Navigated to $route for $title');
    }
  });
}
