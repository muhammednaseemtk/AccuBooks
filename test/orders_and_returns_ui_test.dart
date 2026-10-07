import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:accubooks/app/app.dart';
import 'package:accubooks/app/routes/app_routes.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/core/widgets/app_button.dart';
import 'package:accubooks/models/user_model.dart';
import 'package:accubooks/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });

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

  testWidgets('Sales Orders & Returns Screen UI: Tabs, Actions, Dialogs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    await tester.pumpWidget(const AccuBooksApp(initialRoute: AppRoutes.salesOrders));
    await pumpFrames(tester);

    expect(find.text('Sales Orders & Returns'), findsWidgets);
    expect(find.text('Sales Orders'), findsWidgets);
    expect(find.text('Sales Returns'), findsWidgets);
    expect(find.text('New Sales Order'), findsWidgets);

    // Switch to Sales Returns tab
    final returnsTab = find.widgetWithText(ChoiceChip, 'Sales Returns');
    expect(returnsTab, findsOneWidget);
    await tester.tap(returnsTab);
    await pumpFrames(tester);

    expect(find.text('New Sales Return'), findsWidgets);

    // Tap New Sales Return button
    final newReturnBtn = find.widgetWithText(AppButton, 'New Sales Return');
    expect(newReturnBtn, findsOneWidget);
    await tester.tap(newReturnBtn);
    await pumpFrames(tester);

    // Dialog should be open with create button and returned items section
    expect(find.text('Create Sales Return'), findsOneWidget);
    expect(find.text('Returned Items'), findsOneWidget);

    // Close dialog
    final cancelBtn = find.text('Cancel / Clear');
    if (cancelBtn.evaluate().isNotEmpty) {
      await tester.tap(cancelBtn.first);
      await pumpFrames(tester);
    }
  });

  testWidgets('Purchase Orders & Returns Screen UI: Tabs, Actions, Dialogs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    await tester.pumpWidget(const AccuBooksApp(initialRoute: AppRoutes.purchaseOrders));
    await pumpFrames(tester);

    expect(find.text('Purchase Orders & Returns'), findsWidgets);
    expect(find.text('Purchase Orders'), findsWidgets);
    expect(find.text('Purchase Returns'), findsWidgets);
    expect(find.text('New Purchase Order'), findsWidgets);

    // Switch to Purchase Returns tab
    final returnsTab = find.widgetWithText(ChoiceChip, 'Purchase Returns');
    expect(returnsTab, findsOneWidget);
    await tester.tap(returnsTab);
    await pumpFrames(tester);

    expect(find.text('New Purchase Return'), findsWidgets);

    // Tap New Purchase Return button
    final newReturnBtn = find.widgetWithText(AppButton, 'New Purchase Return');
    expect(newReturnBtn, findsOneWidget);
    await tester.tap(newReturnBtn);
    await pumpFrames(tester);

    // Dialog should be open with create button and returned items section
    expect(find.text('Create Purchase Return'), findsOneWidget);
    expect(find.text('Returned Items'), findsOneWidget);

    // Close dialog
    final cancelBtn = find.text('Cancel / Clear');
    if (cancelBtn.evaluate().isNotEmpty) {
      await tester.tap(cancelBtn.first);
      await pumpFrames(tester);
    }
  });
}
