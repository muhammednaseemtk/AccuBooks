import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:accubooks/app/app.dart';
import 'package:accubooks/app/routes/app_routes.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/models/user_model.dart';
import 'package:accubooks/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    DatabaseHelper.initializeFfi();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpFrames(WidgetTester tester, [int count = 5]) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void setupAuth() {
    final authService = Get.put<AuthService>(AuthService(), permanent: true);
    authService.isAuthenticated.value = true;
    authService.currentUser.value = UserModel(
      id: 1,
      organizationId: 1,
      fullName: 'Admin User',
      email: 'admin@accubooks.local',
      role: 'OWNER',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  group('3-Option Layout Tests for Sales & Purchases', () {
    testWidgets('Sales screen has exactly 3 tabs in order: Sales Orders, Sales Invoices, Sales Returns', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      setupAuth();

      await tester.pumpWidget(const AccuBooksApp(initialRoute: AppRoutes.sales));
      await pumpFrames(tester);

      // Find all ChoiceChips on the screen
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips.length, 3);

      expect((chips[0].label as Text).data, 'Sales Orders');
      expect((chips[1].label as Text).data, 'Sales Invoices');
      expect((chips[2].label as Text).data, 'Sales Returns');

      // Sales Invoices is active on SalesScreen
      expect(chips[0].selected, isFalse);
      expect(chips[1].selected, isTrue);
      expect(chips[2].selected, isFalse);

      // Tap Sales Orders tab -> switches to Sales Orders screen
      await tester.tap(find.widgetWithText(ChoiceChip, 'Sales Orders'));
      await pumpFrames(tester);

      expect(Get.currentRoute, AppRoutes.salesOrders);

      // On SalesOrdersScreen, verify the 3 tabs again
      final orderChips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(orderChips.length, 3);
      expect((orderChips[0].label as Text).data, 'Sales Orders');
      expect((orderChips[1].label as Text).data, 'Sales Invoices');
      expect((orderChips[2].label as Text).data, 'Sales Returns');

      expect(orderChips[0].selected, isTrue);
      expect(orderChips[1].selected, isFalse);
      expect(orderChips[2].selected, isFalse);

      // Tap Sales Returns tab -> switches active tab to Sales Returns
      await tester.tap(find.widgetWithText(ChoiceChip, 'Sales Returns'));
      await pumpFrames(tester);

      final returnChips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(returnChips[0].selected, isFalse);
      expect(returnChips[1].selected, isFalse);
      expect(returnChips[2].selected, isTrue);
    });

    testWidgets('Purchase screen has exactly 3 tabs in order: Purchase Orders, Purchase Invoices, Purchase Returns', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      setupAuth();

      await tester.pumpWidget(const AccuBooksApp(initialRoute: AppRoutes.purchases));
      await pumpFrames(tester);

      // Find all ChoiceChips on the screen
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips.length, 3);

      expect((chips[0].label as Text).data, 'Purchase Orders');
      expect((chips[1].label as Text).data, 'Purchase Invoices');
      expect((chips[2].label as Text).data, 'Purchase Returns');

      // Purchase Invoices is active on PurchasesScreen
      expect(chips[0].selected, isFalse);
      expect(chips[1].selected, isTrue);
      expect(chips[2].selected, isFalse);

      // Tap Purchase Orders tab -> switches to Purchase Orders screen
      await tester.tap(find.widgetWithText(ChoiceChip, 'Purchase Orders'));
      await pumpFrames(tester);

      expect(Get.currentRoute, AppRoutes.purchaseOrders);

      // On PurchaseOrdersScreen, verify the 3 tabs again
      final orderChips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(orderChips.length, 3);
      expect((orderChips[0].label as Text).data, 'Purchase Orders');
      expect((orderChips[1].label as Text).data, 'Purchase Invoices');
      expect((orderChips[2].label as Text).data, 'Purchase Returns');

      expect(orderChips[0].selected, isTrue);
      expect(orderChips[1].selected, isFalse);
      expect(orderChips[2].selected, isFalse);

      // Tap Purchase Returns tab -> switches active tab to Purchase Returns
      await tester.tap(find.widgetWithText(ChoiceChip, 'Purchase Returns'));
      await pumpFrames(tester);

      final returnChips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(returnChips[0].selected, isFalse);
      expect(returnChips[1].selected, isFalse);
      expect(returnChips[2].selected, isTrue);
    });
  });
}
