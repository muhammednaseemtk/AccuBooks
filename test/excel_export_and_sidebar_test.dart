import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accubooks/controllers/report_controller.dart';
import 'package:accubooks/controllers/settings_controller.dart';
import 'package:accubooks/services/report_service.dart';
import 'package:accubooks/screens/navigation/app_scaffold.dart';

class MockReportServiceForTest extends ReportService {
  String? returnPath;
  bool shouldThrow = false;

  MockReportServiceForTest({this.returnPath, this.shouldThrow = false});

  @override
  Future<String?> exportToExcel({
    required String sheetName,
    required String fileName,
    required List<String> headers,
    required List<List<dynamic>> dataRows,
    Future<Uri?> Function({
      required String fileName,
      required Uint8List bytes,
      FileType type,
      List<String>? allowedExtensions,
      String? dialogTitle,
    })? fileSaver,
  }) async {
    if (shouldThrow) {
      throw Exception('Disk write failed: permission denied');
    }
    return returnPath;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.closeAllSnackbars();
    Get.reset();
  });

  group('Requirement 1: Reports - Excel Export Save & Success Handling', () {
    test('1. ReportService.exportToExcel genuinely writes file to selected path and verifies existence', () async {
      final tempDir = await Directory.systemTemp.createTemp('accubooks_excel_test');
      final targetFile = File('${tempDir.path}/test_report.xlsx');

      final service = ReportService();
      final savedPath = await service.exportToExcel(
        sheetName: 'Test Report',
        fileName: 'test_report',
        headers: ['Col A', 'Col B'],
        dataRows: [
          ['Value 1', 123.45],
          ['Value 2', 678.90],
        ],
        fileSaver: ({
          required String fileName,
          required Uint8List bytes,
          dynamic type,
          List<String>? allowedExtensions,
          String? dialogTitle,
        }) async {
          // User chose targetFile.path in the save dialog
          return Uri.file(targetFile.path);
        },
      );

      expect(savedPath, isNotNull);
      expect(File(savedPath!).existsSync(), isTrue);
      expect(await targetFile.exists(), isTrue);
      expect(await targetFile.length(), greaterThan(0));

      // Cleanup
      await tempDir.delete(recursive: true);
    });

    test('2. When user cancels save dialog, exportToExcel returns null and does NOT write fallback', () async {
      final service = ReportService();
      final result = await service.exportToExcel(
        sheetName: 'Test Report',
        fileName: 'test_report_cancel',
        headers: ['Col A'],
        dataRows: [['Row 1']],
        fileSaver: ({
          required String fileName,
          required Uint8List bytes,
          FileType type = FileType.any,
          List<String>? allowedExtensions,
          String? dialogTitle,
        }) async {
          // User cancels or closes the dialog
          return null;
        },
      );

      expect(result, isNull);
    });

    testWidgets('3. When exportToExcel succeeds, ReportController displays success message', (tester) async {
      final mockService = MockReportServiceForTest(returnPath: 'C:\\Users\\Desktop\\test.xlsx');
      final controller = ReportController(reportService: mockService);
      Get.put(controller);

      await tester.pumpWidget(GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => controller.exportCurrentReportToExcel(),
              child: const Text('Export'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Export'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Excel exported successfully'), findsOneWidget);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('4. When user cancels save dialog, NO success message is shown', (tester) async {
      // returnPath is null (user cancelled save dialog)
      final mockService = MockReportServiceForTest(returnPath: null);
      final controller = ReportController(reportService: mockService);
      Get.put(controller);

      await tester.pumpWidget(GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => controller.exportCurrentReportToExcel(),
              child: const Text('Export'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Export'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Crucial: Must NOT show success message
      expect(find.text('Excel exported successfully'), findsNothing);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('5. When file write fails, NO success message is shown', (tester) async {
      final mockService = MockReportServiceForTest(shouldThrow: true);
      final controller = ReportController(reportService: mockService);
      Get.put(controller);

      await tester.pumpWidget(GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => controller.exportCurrentReportToExcel(),
              child: const Text('Export'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Export'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Excel exported successfully'), findsNothing);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });
  });

  group('Requirement 2: Sidebar User-Friendliness & Interaction', () {
    testWidgets('Expanded sidebar shows icons + menu names and can collapse', (tester) async {
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
          body: Center(child: Text('Main Content Area')),
        ),
      ));
      await tester.pumpAndSettle();

      // Expanded state: menu names are visible
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Accounts'), findsOneWidget);

      // Toggle button with tooltip 'Collapse Sidebar'
      final collapseBtn = find.byTooltip('Collapse Sidebar');
      expect(collapseBtn, findsWidgets);

      // Tap collapse
      await tester.tap(collapseBtn.first);
      await tester.pumpAndSettle();

      expect(settings.isSidebarCollapsed.value, isTrue);
    });

    testWidgets('Collapsed sidebar shows icons only with tooltips and easy expand button', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final settings = Get.put(SettingsController());
      settings.isSidebarCollapsed.value = true;

      await tester.pumpWidget(GetMaterialApp(
        home: const AppScaffold(
          title: 'Test Dashboard',
          currentRoute: '/dashboard',
          body: Center(child: Text('Main Content Area')),
        ),
      ));
      await tester.pumpAndSettle();

      // Collapsed state: menu texts in sidebar are hidden
      // The only 'Dashboard' text might be in the app bar title if title is 'Dashboard'
      // But 'Reports' and 'Accounts' menu texts should NOT be visible
      expect(find.text('Reports'), findsNothing);
      expect(find.text('Accounts'), findsNothing);

      // Tooltips exist for menu items
      expect(find.byTooltip('Reports'), findsOneWidget);
      expect(find.byTooltip('Accounts'), findsOneWidget);

      // Expand button is clearly present with tooltip 'Expand Sidebar'
      final expandBtn = find.byTooltip('Expand Sidebar');
      expect(expandBtn, findsWidgets);

      // Tap expand
      await tester.tap(expandBtn.first);
      await tester.pumpAndSettle();

      expect(settings.isSidebarCollapsed.value, isFalse);
      expect(find.text('Reports'), findsOneWidget);
    });
  });
}
