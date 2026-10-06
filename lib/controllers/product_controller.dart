import 'dart:async';
import 'package:get/get.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/stock_transaction_model.dart';
import '../models/tax_model.dart';
import '../repositories/product_repository.dart';
import '../services/inventory_service.dart';

class ProductController extends GetxController {
  final ProductRepository _productRepo;
  final InventoryService _inventoryService;

  ProductController({
    ProductRepository? productRepo,
    InventoryService? inventoryService,
  })  : _productRepo = productRepo ?? ProductRepository(),
        _inventoryService = inventoryService ?? InventoryService();

  final products = <ProductModel>[].obs;
  final categories = <CategoryModel>[].obs;
  final taxes = <TaxModel>[].obs;

  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  final searchQuery = ''.obs;
  final selectedCategoryId = 0.obs;
  final isLowStockOnly = false.obs;

  // Selected product audit
  final selectedProduct = Rxn<ProductModel>();
  final stockTransactions = <StockTransactionModel>[].obs;
  final isLoadingTransactions = false.obs;

  @override
  void onReady() {
    super.onReady();
    loadMetadata();
    loadProducts();
  }

  Future<void> loadMetadata() async {
    try {
      final cats = await _productRepo.getAllCategories();
      final txs = await _productRepo.getAllTaxes();
      categories.assignAll(cats);
      taxes.assignAll(txs);
    } catch (_) {}
  }

  Future<void> loadProducts() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final list = await _productRepo.getAllProducts(
        search: searchQuery.value,
        categoryId: selectedCategoryId.value > 0 ? selectedCategoryId.value : null,
        lowStockOnly: isLowStockOnly.value,
        activeOnly: false,
      );
      products.assignAll(list);
    } catch (e) {
      errorMessage.value = 'Failed to load products: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Timer? _searchDebounce;

  void setSearch(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      loadProducts();
    });
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  void setCategoryFilter(int categoryId) {
    selectedCategoryId.value = categoryId;
    loadProducts();
  }

  void toggleLowStockFilter() {
    isLowStockOnly.value = !isLowStockOnly.value;
    loadProducts();
  }

  Future<bool> saveProduct(ProductModel product) async {
    try {
      isSubmitting.value = true;
      if (product.id == null) {
        await _productRepo.insertProduct(product);
        await loadProducts();
        if (Get.context != null) {
          Get.snackbar('Success', 'Product created successfully', snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        await _productRepo.updateProduct(product);
        await loadProducts();
        if (Get.context != null) {
          Get.snackbar('Success', 'Product updated successfully', snackPosition: SnackPosition.BOTTOM);
        }
      }
      return true;
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar('Error', 'Failed to save product: $e', snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> deactivateProduct(int id) async {
    try {
      await _productRepo.deactivateProduct(id);
      await loadProducts();
      Get.snackbar('Success', 'Product deactivated', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to deactivate product: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> deleteProduct(ProductModel product) async {
    try {
      final canDelete = await _productRepo.canDeleteProduct(product.id!);
      if (!canDelete) {
        Get.snackbar(
          'Cannot Delete',
          'Product "${product.name}" is used in sales or purchase invoices. You can mark it inactive instead.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
      await _productRepo.deleteProduct(product.id!);
      await loadProducts();
      Get.snackbar('Success', 'Product "${product.name}" deleted successfully', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Unable to delete product: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      await _productRepo.deleteCategory(id);
      await loadMetadata();
      await loadProducts();
      Get.snackbar('Success', 'Category deleted successfully', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Unable to delete category: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> deleteStockTransaction(int transactionId, ProductModel product) async {
    try {
      await _productRepo.deleteStockTransaction(transactionId);
      await loadProductHistory(product);
      await loadProducts();
      Get.snackbar('Success', 'Stock movement record deleted and inventory restored', snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Unable to delete stock transaction: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> saveCategory(CategoryModel category) async {
    try {
      if (category.id == null) {
        await _productRepo.insertCategory(category);
      } else {
        await _productRepo.updateCategory(category);
      }
      await loadMetadata();
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to save category: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<bool> saveTax(TaxModel tax) async {
    try {
      await _productRepo.insertTax(tax);
      await loadMetadata();
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to save tax: $e', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<void> adjustStock(int productId, double newQuantity, String reason) async {
    try {
      await _inventoryService.adjustStock(
        productId: productId,
        newQuantity: newQuantity,
        reason: reason,
      );
      await loadProducts();
      Get.snackbar('Success', 'Stock adjusted successfully', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', 'Failed to adjust stock: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> loadProductHistory(ProductModel product) async {
    try {
      selectedProduct.value = product;
      isLoadingTransactions.value = true;
      final trans = await _productRepo.getStockTransactions(product.id!);
      stockTransactions.assignAll(trans);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load stock history: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoadingTransactions.value = false;
    }
  }
}
