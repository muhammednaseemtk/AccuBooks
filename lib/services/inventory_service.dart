import '../core/constants/accounting_constants.dart';
import '../models/product_model.dart';
import '../models/stock_transaction_model.dart';
import '../repositories/product_repository.dart';

class InventoryService {
  final ProductRepository _productRepo;

  InventoryService({ProductRepository? productRepo})
      : _productRepo = productRepo ?? ProductRepository();

  Future<void> adjustStock({
    required int productId,
    required double newQuantity,
    required String reason,
  }) async {
    final product = await _productRepo.getProductById(productId);
    if (product == null) {
      throw Exception('Product not found: $productId');
    }

    final diff = newQuantity - product.stockQuantity;
    if (diff == 0) return;

    await _productRepo.updateStock(
      productId,
      diff,
      transactionType: AccountingConstants.stockAdjustment,
      rate: product.purchasePrice,
    );
  }

  Future<List<ProductModel>> getLowStockProducts() async {
    return await _productRepo.getAllProducts(lowStockOnly: true, activeOnly: true);
  }

  Future<List<StockTransactionModel>> getProductAuditHistory(int productId) async {
    return await _productRepo.getStockTransactions(productId);
  }
}
