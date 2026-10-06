import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../models/stock_transaction_model.dart';
import '../models/tax_model.dart';

class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<ProductModel>> getAllProducts({
    String? search,
    int? categoryId,
    bool lowStockOnly = false,
    bool activeOnly = false,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (activeOnly) {
      whereClauses.add('p.is_active = 1');
    }

    if (categoryId != null && categoryId > 0) {
      whereClauses.add('p.category_id = ?');
      whereArgs.add(categoryId);
    }

    if (lowStockOnly) {
      whereClauses.add('p.stock_quantity <= p.minimum_stock');
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(p.product_code LIKE ? OR p.name LIKE ? OR p.barcode LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT p.*, c.name as category_name
      FROM ${DatabaseTables.tableProducts} p
      LEFT JOIN ${DatabaseTables.tableCategories} c ON p.category_id = c.id
      $whereString
      ORDER BY p.name ASC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    return maps.map((m) => ProductModel.fromMap(m)).toList();
  }

  Future<ProductModel?> getProductById(int id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT p.*, c.name as category_name
      FROM ${DatabaseTables.tableProducts} p
      LEFT JOIN ${DatabaseTables.tableCategories} c ON p.category_id = c.id
      WHERE p.id = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [id]);
    if (maps.isNotEmpty) {
      return ProductModel.fromMap(maps.first);
    }
    return null;
  }

  Future<ProductModel?> getProductByCode(String code) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT p.*, c.name as category_name
      FROM ${DatabaseTables.tableProducts} p
      LEFT JOIN ${DatabaseTables.tableCategories} c ON p.category_id = c.id
      WHERE p.product_code = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [code]);
    if (maps.isNotEmpty) {
      return ProductModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertProduct(ProductModel product) async {
    final db = await _dbHelper.database;
    final id = await db.insert(
      DatabaseTables.tableProducts,
      product.toMap(),
    );

    // If opening stock > 0, create stock transaction
    if (product.stockQuantity > 0) {
      await insertStockTransaction(StockTransactionModel(
        productId: id,
        transactionType: AccountingConstants.stockOpeningStock,
        quantityIn: product.stockQuantity,
        rate: product.purchasePrice,
        balanceQuantity: product.stockQuantity,
        transactionDate: DateTime.now(),
      ));
    }

    return id;
  }

  Future<int> updateProduct(ProductModel product) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseTables.tableProducts,
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<bool> canDeleteProduct(int id) async {
    final db = await _dbHelper.database;
    final sales = await db.query(
      DatabaseTables.tableSalesInvoiceItems,
      where: 'product_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (sales.isNotEmpty) return false;

    final pur = await db.query(
      DatabaseTables.tablePurchaseInvoiceItems,
      where: 'product_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (pur.isNotEmpty) return false;

    return true;
  }

  Future<int> deleteProduct(int id) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      await txn.delete(DatabaseTables.tableStockTransactions, where: 'product_id = ?', whereArgs: [id]);
      return await txn.delete(DatabaseTables.tableProducts, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> deactivateProduct(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseTables.tableProducts,
      {'is_active': 0, 'updated_at': AppDateUtils.formatDb(DateTime.now())},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update product stock atomically and log stock transaction
  Future<double> updateStock(
    int productId,
    double quantityDelta, {
    required String transactionType,
    int? referenceId,
    double rate = 0.0,
    Transaction? txn,
  }) async {
    final executor = txn ?? await _dbHelper.database;

    final pList = await executor.query(
      DatabaseTables.tableProducts,
      columns: ['stock_quantity'],
      where: 'id = ?',
      whereArgs: [productId],
    );

    if (pList.isEmpty) {
      throw Exception('Product not found: $productId');
    }

    final currentStock = (pList.first['stock_quantity'] as num).toDouble();
    final newStock = currentStock + quantityDelta;

    await executor.update(
      DatabaseTables.tableProducts,
      {
        'stock_quantity': newStock,
        'updated_at': AppDateUtils.formatDb(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );

    final now = DateTime.now();
    await executor.insert(DatabaseTables.tableStockTransactions, {
      'product_id': productId,
      'transaction_type': transactionType,
      'reference_id': referenceId,
      'quantity_in': quantityDelta > 0 ? quantityDelta : 0.0,
      'quantity_out': quantityDelta < 0 ? (-quantityDelta) : 0.0,
      'rate': rate,
      'balance_quantity': newStock,
      'transaction_date': AppDateUtils.formatDb(now),
      'created_at': AppDateUtils.formatDb(now),
    });

    return newStock;
  }

  Future<int> insertStockTransaction(StockTransactionModel trans, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    return await executor.insert(
      DatabaseTables.tableStockTransactions,
      trans.toMap(),
    );
  }

  Future<List<StockTransactionModel>> getStockTransactions(int productId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.tableStockTransactions,
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'transaction_date DESC',
    );
    return maps.map((m) => StockTransactionModel.fromMap(m)).toList();
  }

  // --- Categories ---
  Future<List<CategoryModel>> getAllCategories() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseTables.tableCategories,
      orderBy: 'name ASC',
    );
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<int> insertCategory(CategoryModel category) async {
    final db = await _dbHelper.database;
    return await db.insert(
      DatabaseTables.tableCategories,
      category.toMap(),
    );
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseTables.tableCategories,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      await txn.update(
        DatabaseTables.tableProducts,
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      return await txn.delete(DatabaseTables.tableCategories, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> deleteStockTransaction(int transactionId) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final tList = await txn.query(
        DatabaseTables.tableStockTransactions,
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      if (tList.isEmpty) return 0;
      final t = tList.first;
      final pId = t['product_id'] as int;
      final qIn = (t['quantity_in'] as num?)?.toDouble() ?? 0.0;
      final qOut = (t['quantity_out'] as num?)?.toDouble() ?? 0.0;
      final delta = qOut - qIn; // reverse the effect

      final pList = await txn.query(DatabaseTables.tableProducts, columns: ['stock_quantity'], where: 'id = ?', whereArgs: [pId]);
      if (pList.isNotEmpty) {
        final currentStock = (pList.first['stock_quantity'] as num).toDouble();
        await txn.update(DatabaseTables.tableProducts, {'stock_quantity': currentStock + delta}, where: 'id = ?', whereArgs: [pId]);
      }

      return await txn.delete(DatabaseTables.tableStockTransactions, where: 'id = ?', whereArgs: [transactionId]);
    });
  }

  // --- Taxes ---
  Future<List<TaxModel>> getAllTaxes() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseTables.tableTaxes,
      where: 'is_active = 1',
      orderBy: 'rate ASC',
    );
    return maps.map((m) => TaxModel.fromMap(m)).toList();
  }

  Future<int> insertTax(TaxModel tax) async {
    final db = await _dbHelper.database;
    return await db.insert(
      DatabaseTables.tableTaxes,
      tax.toMap(),
    );
  }
}
