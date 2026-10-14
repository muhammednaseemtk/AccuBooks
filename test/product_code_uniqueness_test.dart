import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accubooks/core/constants/accounting_constants.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/core/widgets/app_dialog.dart';
import 'package:accubooks/controllers/product_controller.dart';
import 'package:accubooks/controllers/settings_controller.dart';
import 'package:accubooks/models/category_model.dart';
import 'package:accubooks/models/product_model.dart';
import 'package:accubooks/models/tax_model.dart';
import 'package:accubooks/models/stock_transaction_model.dart';
import 'package:accubooks/repositories/product_repository.dart';
import 'package:accubooks/screens/products/products_screen.dart';

class InMemoryProductRepository extends ProductRepository {
  final List<ProductModel> storage = [];
  final Set<String> reservedCodes = {};
  final List<CategoryModel> categories = [
    CategoryModel(id: 1, name: 'Electronics'),
  ];
  final List<TaxModel> taxes = [
    TaxModel(id: 1, name: 'GST 18%', rate: 18.0),
  ];

  @override
  Future<List<CategoryModel>> getAllCategories() async => List.from(categories);

  @override
  Future<List<TaxModel>> getAllTaxes() async => List.from(taxes);

  @override
  Future<List<ProductModel>> getAllProducts({
    String? search,
    int? categoryId,
    bool lowStockOnly = false,
    bool activeOnly = false,
  }) async {
    return List.from(storage);
  }

  @override
  Future<ProductModel?> getProductById(int id, {dynamic txn}) async {
    final idx = storage.indexWhere((p) => p.id == id);
    return idx >= 0 ? storage[idx] : null;
  }

  @override
  Future<ProductModel?> getProductByCode(String code, {dynamic txn}) async {
    final clean = code.trim().toUpperCase();
    final idx = storage.indexWhere((p) => p.productCode.trim().toUpperCase() == clean);
    return idx >= 0 ? storage[idx] : null;
  }

  @override
  Future<Set<String>> getReservedCodes() async {
    return Set.from(reservedCodes);
  }

  @override
  Future<void> reserveProductCode(String code) async {
    reservedCodes.add(code.trim().toUpperCase());
  }

  @override
  Future<bool> isProductCodeExists(String productCode, {int? excludeId, dynamic txn}) async {
    final clean = productCode.trim().toUpperCase();
    if (clean.isEmpty) return false;

    final existsInStorage = storage.any((p) =>
        p.productCode.trim().toUpperCase() == clean &&
        (excludeId == null || p.id != excludeId));
    if (existsInStorage) return true;

    if (reservedCodes.contains(clean)) return true;

    return false;
  }

  @override
  Future<String> getNextProductCode({dynamic txn}) async {
    int maxNumber = 0;
    for (final p in storage) {
      final matches = RegExp(r'\d+').allMatches(p.productCode);
      if (matches.isNotEmpty) {
        final num = int.tryParse(matches.last.group(0)!);
        if (num != null && num > maxNumber) maxNumber = num;
      }
    }
    for (final code in reservedCodes) {
      final matches = RegExp(r'\d+').allMatches(code);
      if (matches.isNotEmpty) {
        final num = int.tryParse(matches.last.group(0)!);
        if (num != null && num > maxNumber) maxNumber = num;
      }
    }

    int nextNumber = maxNumber + 1;
    String candidate = '${AccountingConstants.prefixProduct}${nextNumber.toString().padLeft(3, '0')}';
    while (storage.any((p) => p.productCode.trim().toUpperCase() == candidate.toUpperCase()) ||
        reservedCodes.contains(candidate.toUpperCase())) {
      nextNumber++;
      candidate = '${AccountingConstants.prefixProduct}${nextNumber.toString().padLeft(3, '0')}';
    }
    return candidate;
  }

  @override
  Future<int> insertProduct(ProductModel product, {dynamic txn}) async {
    if (await isProductCodeExists(product.productCode)) {
      throw Exception('Product code already exists. Please use a unique code.');
    }
    final newId = storage.length + 1;
    final saved = product.copyWith(id: newId);
    storage.add(saved);
    return newId;
  }

  @override
  Future<int> updateProduct(ProductModel product, {dynamic txn}) async {
    if (await isProductCodeExists(product.productCode, excludeId: product.id)) {
      throw Exception('Product code already exists. Please use a unique code.');
    }
    final idx = storage.indexWhere((p) => p.id == product.id);
    if (idx >= 0) {
      storage[idx] = product;
      return 1;
    }
    return 0;
  }

  @override
  Future<bool> canDeleteProduct(int id) async => true;

  @override
  Future<int> deleteProduct(int id) async {
    final idx = storage.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      await reserveProductCode(storage[idx].productCode);
      storage.removeAt(idx);
      return 1;
    }
    return 0;
  }

  @override
  Future<double> updateStock(
    int productId,
    double quantityDelta, {
    required String transactionType,
    int? referenceId,
    double rate = 0.0,
    dynamic txn,
  }) async {
    final p = await getProductById(productId);
    if (p != null) {
      final newQty = p.stockQuantity + quantityDelta;
      await updateProduct(p.copyWith(stockQuantity: newQty));
      return newQty;
    }
    return 0.0;
  }

  @override
  Future<List<StockTransactionModel>> getStockTransactions(int productId) async => [];
}

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

  setUp(() {
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    Get.put(SettingsController());
    ProductRepository.clearReservedCodesForTesting();
  });

  tearDown(() {
    Get.closeAllSnackbars();
    Get.reset();
  });

  Widget wrapWithApp(Widget child) {
    return GetMaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('Product Code Auto-Generation & Sequence Tests', () {
    test('Empty repository generates PRD-001', () async {
      final repo = InMemoryProductRepository();
      final controller = ProductController(productRepo: repo);
      Get.put(controller);

      final nextCode = await controller.getNextProductCode();
      expect(nextCode, equals('PRD-001'));
      expect(controller.nextProductCode.value, equals('PRD-001'));
    });

    test('Adding products sequentially advances code: PRD-001, PRD-002, PRD-003', () async {
      final repo = InMemoryProductRepository();
      final controller = ProductController(productRepo: repo);
      Get.put(controller);

      // Product 1
      final code1 = await controller.getNextProductCode();
      expect(code1, equals('PRD-001'));
      final ok1 = await controller.saveProduct(ProductModel(productCode: code1, name: 'Product One', salesPrice: 50));
      expect(ok1, isTrue);

      // Product 2
      final code2 = await controller.getNextProductCode();
      expect(code2, equals('PRD-002'));
      final ok2 = await controller.saveProduct(ProductModel(productCode: code2, name: 'Product Two', salesPrice: 100));
      expect(ok2, isTrue);

      // Product 3
      final code3 = await controller.getNextProductCode();
      expect(code3, equals('PRD-003'));
      final ok3 = await controller.saveProduct(ProductModel(productCode: code3, name: 'Product Three', salesPrice: 150));
      expect(ok3, isTrue);

      expect(controller.products.length, equals(3));
      expect(controller.products.map((p) => p.productCode).toList(),
          equals(['PRD-001', 'PRD-002', 'PRD-003']));
    });

    test('Deleted product codes remain reserved and are never reused', () async {
      final repo = InMemoryProductRepository();
      final controller = ProductController(productRepo: repo);
      Get.put(controller);

      await controller.saveProduct(ProductModel(productCode: 'PRD-001', name: 'Product One', salesPrice: 50));
      await controller.saveProduct(ProductModel(productCode: 'PRD-002', name: 'Product Two', salesPrice: 100));

      // Delete Product 2 (PRD-002)
      final prod2 = controller.products.firstWhere((p) => p.productCode == 'PRD-002');
      final delOk = await controller.deleteProduct(prod2);
      expect(delOk, isTrue);

      // Next code must advance to PRD-003, NOT reuse PRD-002
      final nextCode = await controller.getNextProductCode();
      expect(nextCode, equals('PRD-003'));

      // Trying to manually re-add PRD-002 must be rejected
      final reject = await controller.saveProduct(ProductModel(productCode: 'PRD-002', name: 'Imposter Prod', salesPrice: 100));
      expect(reject, isFalse);
    });

    test('Duplicate product code is rejected for new product', () async {
      final repo = InMemoryProductRepository();
      final controller = ProductController(productRepo: repo);
      Get.put(controller);

      await controller.saveProduct(ProductModel(productCode: 'PRD-001', name: 'Product One', salesPrice: 50));

      // Attempt duplicate code
      final dupOk = await controller.saveProduct(ProductModel(productCode: 'PRD-001', name: 'Duplicate Prod', salesPrice: 60));
      expect(dupOk, isFalse);
      expect(controller.products.length, equals(1));
    });

    test('Editing product without changing its code works correctly', () async {
      final repo = InMemoryProductRepository();
      final controller = ProductController(productRepo: repo);
      Get.put(controller);

      await controller.saveProduct(ProductModel(productCode: 'PRD-001', name: 'Product One', salesPrice: 50));
      final prod = controller.products.first;

      final updated = prod.copyWith(name: 'Product One Renamed');
      final updateOk = await controller.updateProduct(updated);
      expect(updateOk, isTrue);

      final reloaded = controller.products.firstWhere((p) => p.id == prod.id);
      expect(reloaded.name, equals('Product One Renamed'));
      expect(reloaded.productCode, equals('PRD-001'));
    });

    test('Editing product to use another product code is rejected', () async {
      final repo = InMemoryProductRepository();
      final controller = ProductController(productRepo: repo);
      Get.put(controller);

      await controller.saveProduct(ProductModel(productCode: 'PRD-001', name: 'Product One', salesPrice: 50));
      await controller.saveProduct(ProductModel(productCode: 'PRD-002', name: 'Product Two', salesPrice: 100));

      final prod2 = controller.products.firstWhere((p) => p.productCode == 'PRD-002');
      final stolenCode = prod2.copyWith(productCode: 'PRD-001');

      final updateOk = await controller.updateProduct(stolenCode);
      expect(updateOk, isFalse);

      final reloaded2 = controller.products.firstWhere((p) => p.id == prod2.id);
      expect(reloaded2.productCode, equals('PRD-002'));
    });
  });

  void ignoreLayoutOverflow() {
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
  }

  group('Product UI Dialog Code Auto-Generation & Uniqueness Tests', () {
    testWidgets('Add Product Dialog opens with auto-generated code and advances after saving multiple products consecutively', (tester) async {
      ignoreLayoutOverflow();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = InMemoryProductRepository();
      final controller = ProductController(productRepo: repo);
      Get.put(controller);
      await controller.loadProducts();

      await tester.pumpWidget(wrapWithApp(const ProductsScreen()));
      await tester.pump(const Duration(milliseconds: 200));

      // Click Add Product
      await tester.tap(find.byIcon(Icons.add_box_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Code field should be prepopulated with PRD-001
      expect(find.text('PRD-001'), findsOneWidget);

      final dialogFields = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextFormField),
      );

      // Enter Product 1 Name & Sales Price
      // Field indices: 0: Code, 1: Barcode, 2: Name, 3: Unit, 4: Tax Rate, 5: Purchase Price, 6: Sales Price, 7: Stock, 8: Min Stock
      await tester.enterText(dialogFields.at(2), 'First Product');
      await tester.enterText(dialogFields.at(6), '150');
      await tester.pump();

      // Tap Save Product
      await tester.tap(find.text('Save Product'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Code field in the open dialog should now advance immediately to PRD-002 (NOT wiped or empty!)
      expect(find.text('PRD-002'), findsOneWidget);

      // Add second product consecutively in the open dialog
      await tester.enterText(dialogFields.at(2), 'Second Product');
      await tester.enterText(dialogFields.at(6), '250');
      await tester.pump();

      await tester.tap(find.text('Save Product'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Code field in the open dialog should now advance immediately to PRD-003
      expect(find.text('PRD-003'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify both products were saved in the list with their exact codes
      expect(find.text('First Product'), findsOneWidget);
      expect(find.text('PRD-001'), findsOneWidget);
      expect(find.text('Second Product'), findsOneWidget);
      expect(find.text('PRD-002'), findsOneWidget);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('Closing and reopening Add Product dialog generates fresh unique code without stale values', (tester) async {
      ignoreLayoutOverflow();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = InMemoryProductRepository();
      final controller = ProductController(productRepo: repo);
      Get.put(controller);
      await controller.loadProducts();

      await tester.pumpWidget(wrapWithApp(const ProductsScreen()));
      await tester.pumpAndSettle();

      // Open Add Product Dialog (generates PRD-001)
      await tester.tap(find.byIcon(Icons.add_box_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('PRD-001'), findsOneWidget);

      final dialogFields = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(dialogFields.at(2), 'Product One');
      await tester.enterText(dialogFields.at(6), '100');
      await tester.pump();

      await tester.tap(find.text('Save Product'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Now close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      // Open dialog again for new product
      await tester.tap(find.byIcon(Icons.add_box_outlined), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The new dialog MUST display PRD-002, not stale PRD-001
      expect(find.text('PRD-002'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(AppDialog), matching: find.text('Cancel')), warnIfMissed: false);
      await tester.pumpAndSettle();

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('Manual editing of Product Code is preserved and saved exactly', (tester) async {
      ignoreLayoutOverflow();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = InMemoryProductRepository();
      final controller = ProductController(productRepo: repo);
      Get.put(controller);
      await controller.loadProducts();

      await tester.pumpWidget(wrapWithApp(const ProductsScreen()));
      await tester.pumpAndSettle();

      // Open Add Product Dialog
      await tester.tap(find.byIcon(Icons.add_box_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dialogFields = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextFormField),
      );

      // Manually change code from PRD-001 to CUSTOM-099
      await tester.enterText(dialogFields.at(0), 'CUSTOM-099');
      await tester.enterText(dialogFields.at(2), 'Custom Coded Product');
      await tester.enterText(dialogFields.at(6), '500');
      await tester.pump();

      // Check reactive state synchronization
      expect(controller.nextProductCode.value, equals('CUSTOM-099'));

      await tester.tap(find.text('Save Product'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Product in list must have exact custom code
      expect(find.text('CUSTOM-099'), findsOneWidget);
      expect(find.text('Custom Coded Product'), findsOneWidget);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('Duplicate Product Code shows error and preserves dialog inputs', (tester) async {
      ignoreLayoutOverflow();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = InMemoryProductRepository();
      await repo.insertProduct(ProductModel(productCode: 'PRD-001', name: 'Existing Product', salesPrice: 100));

      final controller = ProductController(productRepo: repo);
      Get.put(controller);
      await controller.loadProducts();

      await tester.pumpWidget(wrapWithApp(const ProductsScreen()));
      await tester.pumpAndSettle();

      // Open Add Product
      await tester.tap(find.byIcon(Icons.add_box_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final dialogFields = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextFormField),
      );

      // Overwrite auto code with duplicate PRD-001
      await tester.enterText(dialogFields.at(0), 'PRD-001');
      await tester.enterText(dialogFields.at(2), 'Duplicate Product Name');
      await tester.enterText(dialogFields.at(6), '200');
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save Product'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should remain open
      expect(find.text('Add New Product'), findsOneWidget);
      expect(Get.isDialogOpen, isTrue);

      // Input should be preserved
      expect(find.text('Duplicate Product Name'), findsOneWidget);

      // Duplicate message should be shown
      expect(find.text('Product code already exists. Please use a unique code.'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('Editing existing product preserves product code without regenerating it', (tester) async {
      ignoreLayoutOverflow();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = InMemoryProductRepository();
      await repo.insertProduct(ProductModel(productCode: 'PRD-SPECIFIC', name: 'Special Product', salesPrice: 300));

      final controller = ProductController(productRepo: repo);
      Get.put(controller);
      await controller.loadProducts();

      await tester.pumpWidget(wrapWithApp(const ProductsScreen()));
      await tester.pumpAndSettle();

      // Tap edit product button
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit Product'), findsOneWidget);
      // Code field inside dialog should preserve existing code PRD-SPECIFIC
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('PRD-SPECIFIC'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.descendant(of: find.byType(AppDialog), matching: find.text('Cancel')), warnIfMissed: false);
      await tester.pumpAndSettle();

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });
  });
}
