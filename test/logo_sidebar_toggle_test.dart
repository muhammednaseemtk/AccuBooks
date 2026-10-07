import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accubooks/controllers/settings_controller.dart';
import 'package:accubooks/screens/navigation/app_scaffold.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.reset();
  });

  group('Logo Sidebar/Drawer Toggle Tests', () {
    testWidgets('1. AccuBooks logo works as the toggle: clicks collapse when open and expand when collapsed', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = Get.put(SettingsController());
      settings.isSidebarCollapsed.value = false;

      await tester.pumpWidget(GetMaterialApp(
        home: const AppScaffold(
          title: 'Test Dashboard',
          currentRoute: '/dashboard',
          body: Center(child: Text('Content')),
        ),
      ));
      await tester.pumpAndSettle();

      // Expanded state:
      // 1. Logo image is visible
      final logoFinder = find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/app_logo.png',
      );
      expect(logoFinder, findsOneWidget);

      // 2. Menu names are visible
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Purchases'), findsOneWidget);

      // 3. No separate toggle buttons in top app bar or sidebar header
      expect(find.byIcon(Icons.keyboard_double_arrow_left_rounded), findsNothing);
      expect(find.byIcon(Icons.keyboard_double_arrow_right_rounded), findsNothing);

      // Click the logo / brand header to collapse
      await tester.tap(logoFinder);
      await tester.pumpAndSettle();

      // State is now collapsed
      expect(settings.isSidebarCollapsed.value, isTrue);

      // Collapsed state:
      // 1. Logo image is STILL visible
      expect(logoFinder, findsOneWidget);

      // 2. Menu names are hidden
      expect(find.text('Sales'), findsNothing);
      expect(find.text('Purchases'), findsNothing);

      // 3. Menu icons are still present
      expect(find.byIcon(Icons.point_of_sale_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);

      // Click the logo again to expand
      await tester.tap(logoFinder);
      await tester.pumpAndSettle();

      // State is now expanded again
      expect(settings.isSidebarCollapsed.value, isFalse);
      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Purchases'), findsOneWidget);
    });

    testWidgets('2. Clicking logo does NOT navigate away or reload route', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = Get.put(SettingsController());
      settings.isSidebarCollapsed.value = false;

      var buildCount = 0;

      await tester.pumpWidget(GetMaterialApp(
        initialRoute: '/sales',
        getPages: [
          GetPage(
            name: '/sales',
            page: () {
              buildCount++;
              return const AppScaffold(
                title: 'Sales Screen',
                currentRoute: '/sales',
                body: Center(child: Text('Sales Screen Content')),
              );
            },
          ),
          GetPage(
            name: '/dashboard',
            page: () => const Scaffold(body: Text('Dashboard Screen Content')),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(buildCount, 1);
      expect(Get.currentRoute, '/sales');
      expect(find.text('Sales Screen Content'), findsOneWidget);

      final logoFinder = find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/app_logo.png',
      );

      // Tap logo
      await tester.tap(logoFinder);
      await tester.pumpAndSettle();

      // Route remains /sales (did not navigate to dashboard or anywhere else)
      expect(Get.currentRoute, '/sales');
      expect(find.text('Sales Screen Content'), findsOneWidget);
      expect(find.text('Dashboard Screen Content'), findsNothing);
      expect(settings.isSidebarCollapsed.value, isTrue);

      // Tap logo again
      await tester.tap(logoFinder);
      await tester.pumpAndSettle();

      expect(Get.currentRoute, '/sales');
      expect(settings.isSidebarCollapsed.value, isFalse);
    });
  });
}
