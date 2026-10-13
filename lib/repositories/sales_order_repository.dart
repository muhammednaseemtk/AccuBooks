import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/sequence_utils.dart';
import '../models/sales_order_item_model.dart';
import '../models/sales_order_model.dart';
import '../models/sales_return_item_model.dart';
import '../models/sales_return_model.dart';

class SalesOrderRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String prefReservedOrderNumbers = 'reserved_sales_order_numbers';
  static const String prefReservedReturnNumbers = 'reserved_sales_return_numbers';

  static void clearReservedNumbersForTesting() {
    SequenceUtils.clearReservedForTesting(prefReservedOrderNumbers);
    SequenceUtils.clearReservedForTesting(prefReservedReturnNumbers);
  }

  // === SALES ORDERS RESERVATIONS & UNIQUENESS ===

  Future<Set<String>> getReservedOrderNumbers() async {
    return SequenceUtils.getReserved(prefReservedOrderNumbers);
  }

  Future<void> reserveOrderNumber(String orderNumber) async {
    return SequenceUtils.reserve(prefReservedOrderNumbers, orderNumber);
  }

  Future<bool> isOrderNumberExists(
    String orderNumber, {
    int? excludeId,
    Transaction? txn,
  }) async {
    return SequenceUtils.isNumberExists(
      dbHelper: _dbHelper,
      tableName: DatabaseTables.tableSalesOrders,
      columnName: 'order_number',
      prefKey: prefReservedOrderNumbers,
      codeOrNumber: orderNumber,
      excludeId: excludeId,
      txn: txn,
    );
  }

  Future<String> getNextOrderNumber({Transaction? txn}) async {
    return SequenceUtils.getNextNumber(
      dbHelper: _dbHelper,
      tableName: DatabaseTables.tableSalesOrders,
      columnName: 'order_number',
      prefix: AccountingConstants.prefixSalesOrder,
      padDigits: 6,
      prefKey: prefReservedOrderNumbers,
      txn: txn,
    );
  }

  Future<List<SalesOrderModel>> getAllSalesOrders({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
    String? status,
    String? search,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (fromDate != null) {
      whereClauses.add('so.order_date >= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.startOfDay(fromDate)));
    }

    if (toDate != null) {
      whereClauses.add('so.order_date <= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.endOfDay(toDate)));
    }

    if (customerId != null && customerId > 0) {
      whereClauses.add('so.customer_id = ?');
      whereArgs.add(customerId);
    }

    if (status != null && status.isNotEmpty && status != 'All') {
      whereClauses.add('so.status = ?');
      whereArgs.add(status);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(so.order_number LIKE ? OR c.name LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        so.*, 
        c.name as customer_name,
        c.phone as customer_phone,
        c.address as customer_address
      FROM ${DatabaseTables.tableSalesOrders} so
      JOIN ${DatabaseTables.tableCustomers} c ON so.customer_id = c.id
      $whereString
      ORDER BY so.order_date DESC, so.id DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    if (maps.isEmpty) return [];

    final orderIds = maps.map((m) => m['id'] as int).toList();
    final placeholders = List.filled(orderIds.length, '?').join(',');
    final itemsMaps = await db.rawQuery('''
      SELECT soi.*, p.name as product_name, p.product_code, p.unit
      FROM ${DatabaseTables.tableSalesOrderItems} soi
      LEFT JOIN ${DatabaseTables.tableProducts} p ON soi.product_id = p.id
      WHERE soi.order_id IN ($placeholders)
      ORDER BY soi.id ASC
    ''', orderIds);

    final itemsByOrderId = <int, List<SalesOrderItemModel>>{};
    for (final itemMap in itemsMaps) {
      final ordId = itemMap['order_id'] as int;
      itemsByOrderId.putIfAbsent(ordId, () => []).add(SalesOrderItemModel.fromMap(itemMap));
    }

    return maps.map((map) {
      final id = map['id'] as int;
      return SalesOrderModel.fromMap(map, items: itemsByOrderId[id] ?? []);
    }).toList();
  }

  Future<SalesOrderModel?> getSalesOrderById(int id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        so.*, 
        c.name as customer_name,
        c.phone as customer_phone,
        c.address as customer_address
      FROM ${DatabaseTables.tableSalesOrders} so
      JOIN ${DatabaseTables.tableCustomers} c ON so.customer_id = c.id
      WHERE so.id = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [id]);
    if (maps.isNotEmpty) {
      final items = await getItemsByOrderId(id);
      return SalesOrderModel.fromMap(maps.first, items: items);
    }
    return null;
  }

  Future<List<SalesOrderItemModel>> getItemsByOrderId(int orderId) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT soi.*, p.name as product_name, p.product_code, p.unit
      FROM ${DatabaseTables.tableSalesOrderItems} soi
      LEFT JOIN ${DatabaseTables.tableProducts} p ON soi.product_id = p.id
      WHERE soi.order_id = ?
      ORDER BY soi.id ASC
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [orderId]);
    return maps.map((m) => SalesOrderItemModel.fromMap(m)).toList();
  }

  Future<int> insertSalesOrder(SalesOrderModel order, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    if (await isOrderNumberExists(order.orderNumber, txn: txn)) {
      throw Exception('Sales order number already exists. Please use a unique number.');
    }
    return await executor.insert(
      DatabaseTables.tableSalesOrders,
      order.toMap(),
    );
  }

  Future<void> insertSalesOrderItems(int orderId, List<SalesOrderItemModel> items, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    for (final item in items) {
      await executor.insert(
        DatabaseTables.tableSalesOrderItems,
        item.copyWith(orderId: orderId).toMap(),
      );
    }
  }

  Future<void> updateSalesOrderStatus(int orderId, String status, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    await executor.update(
      DatabaseTables.tableSalesOrders,
      {
        'status': status,
        'updated_at': AppDateUtils.formatDb(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  // === SALES RETURNS ===

  Future<Set<String>> getReservedReturnNumbers() async {
    return SequenceUtils.getReserved(prefReservedReturnNumbers);
  }

  Future<void> reserveReturnNumber(String returnNumber) async {
    return SequenceUtils.reserve(prefReservedReturnNumbers, returnNumber);
  }

  Future<bool> isReturnNumberExists(
    String returnNumber, {
    int? excludeId,
    Transaction? txn,
  }) async {
    return SequenceUtils.isNumberExists(
      dbHelper: _dbHelper,
      tableName: DatabaseTables.tableSalesReturns,
      columnName: 'return_number',
      prefKey: prefReservedReturnNumbers,
      codeOrNumber: returnNumber,
      excludeId: excludeId,
      txn: txn,
    );
  }

  Future<String> getNextReturnNumber({Transaction? txn}) async {
    return SequenceUtils.getNextNumber(
      dbHelper: _dbHelper,
      tableName: DatabaseTables.tableSalesReturns,
      columnName: 'return_number',
      prefix: AccountingConstants.prefixSalesReturn,
      padDigits: 6,
      prefKey: prefReservedReturnNumbers,
      txn: txn,
    );
  }

  Future<List<SalesReturnModel>> getAllSalesReturns({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
    String? search,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (fromDate != null) {
      whereClauses.add('sr.return_date >= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.startOfDay(fromDate)));
    }

    if (toDate != null) {
      whereClauses.add('sr.return_date <= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.endOfDay(toDate)));
    }

    if (customerId != null && customerId > 0) {
      whereClauses.add('sr.customer_id = ?');
      whereArgs.add(customerId);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(sr.return_number LIKE ? OR c.name LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        sr.*, 
        c.name as customer_name,
        c.phone as customer_phone,
        c.address as customer_address
      FROM ${DatabaseTables.tableSalesReturns} sr
      JOIN ${DatabaseTables.tableCustomers} c ON sr.customer_id = c.id
      $whereString
      ORDER BY sr.return_date DESC, sr.id DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    if (maps.isEmpty) return [];

    final returnIds = maps.map((m) => m['id'] as int).toList();
    final placeholders = List.filled(returnIds.length, '?').join(',');
    final itemsMaps = await db.rawQuery('''
      SELECT sri.*, p.name as product_name, p.product_code, p.unit
      FROM ${DatabaseTables.tableSalesReturnItems} sri
      LEFT JOIN ${DatabaseTables.tableProducts} p ON sri.product_id = p.id
      WHERE sri.return_id IN ($placeholders)
      ORDER BY sri.id ASC
    ''', returnIds);

    final itemsByReturnId = <int, List<SalesReturnItemModel>>{};
    for (final itemMap in itemsMaps) {
      final retId = itemMap['return_id'] as int;
      itemsByReturnId.putIfAbsent(retId, () => []).add(SalesReturnItemModel.fromMap(itemMap));
    }

    return maps.map((map) {
      final id = map['id'] as int;
      return SalesReturnModel.fromMap(map, items: itemsByReturnId[id] ?? []);
    }).toList();
  }

  Future<SalesReturnModel?> getSalesReturnById(int id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        sr.*, 
        c.name as customer_name,
        c.phone as customer_phone,
        c.address as customer_address
      FROM ${DatabaseTables.tableSalesReturns} sr
      JOIN ${DatabaseTables.tableCustomers} c ON sr.customer_id = c.id
      WHERE sr.id = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [id]);
    if (maps.isNotEmpty) {
      final items = await getItemsByReturnId(id);
      return SalesReturnModel.fromMap(maps.first, items: items);
    }
    return null;
  }

  Future<List<SalesReturnItemModel>> getItemsByReturnId(int returnId) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT sri.*, p.name as product_name, p.product_code, p.unit
      FROM ${DatabaseTables.tableSalesReturnItems} sri
      LEFT JOIN ${DatabaseTables.tableProducts} p ON sri.product_id = p.id
      WHERE sri.return_id = ?
      ORDER BY sri.id ASC
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [returnId]);
    return maps.map((m) => SalesReturnItemModel.fromMap(m)).toList();
  }

  Future<int> insertSalesReturn(SalesReturnModel returnModel, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    if (await isReturnNumberExists(returnModel.returnNumber, txn: txn)) {
      throw Exception('Sales return number already exists. Please use a unique number.');
    }
    return await executor.insert(
      DatabaseTables.tableSalesReturns,
      returnModel.toMap(),
    );
  }

  Future<void> insertSalesReturnItems(int returnId, List<SalesReturnItemModel> items, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    for (final item in items) {
      await executor.insert(
        DatabaseTables.tableSalesReturnItems,
        item.copyWith(returnId: returnId).toMap(),
      );
    }
  }

  Future<int> updateSalesOrder(SalesOrderModel order, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    if (await isOrderNumberExists(order.orderNumber, excludeId: order.id, txn: txn)) {
      throw Exception('Sales order number already exists. Please use a unique number.');
    }
    return await executor.update(
      DatabaseTables.tableSalesOrders,
      order.toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<int> deleteSalesOrderItems(int orderId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    return await executor.delete(
      DatabaseTables.tableSalesOrderItems,
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  Future<int> deleteSalesOrder(int orderId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    final maps = await executor.query(
      DatabaseTables.tableSalesOrders,
      columns: ['order_number'],
      where: 'id = ?',
      whereArgs: [orderId],
    );
    if (maps.isNotEmpty) {
      final num = maps.first['order_number'] as String?;
      if (num != null) {
        await reserveOrderNumber(num);
      }
    }
    await deleteSalesOrderItems(orderId, txn: txn);
    return await executor.delete(
      DatabaseTables.tableSalesOrders,
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<int> updateSalesReturn(SalesReturnModel returnModel, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    if (await isReturnNumberExists(returnModel.returnNumber, excludeId: returnModel.id, txn: txn)) {
      throw Exception('Sales return number already exists. Please use a unique number.');
    }
    return await executor.update(
      DatabaseTables.tableSalesReturns,
      returnModel.toMap(),
      where: 'id = ?',
      whereArgs: [returnModel.id],
    );
  }

  Future<int> deleteSalesReturnItems(int returnId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    return await executor.delete(
      DatabaseTables.tableSalesReturnItems,
      where: 'return_id = ?',
      whereArgs: [returnId],
    );
  }

  Future<int> deleteSalesReturn(int returnId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    final maps = await executor.query(
      DatabaseTables.tableSalesReturns,
      columns: ['return_number'],
      where: 'id = ?',
      whereArgs: [returnId],
    );
    if (maps.isNotEmpty) {
      final num = maps.first['return_number'] as String?;
      if (num != null) {
        await reserveReturnNumber(num);
      }
    }
    await deleteSalesReturnItems(returnId, txn: txn);
    return await executor.delete(
      DatabaseTables.tableSalesReturns,
      where: 'id = ?',
      whereArgs: [returnId],
    );
  }
}
