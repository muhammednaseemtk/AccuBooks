import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/sequence_utils.dart';
import '../models/purchase_order_item_model.dart';
import '../models/purchase_order_model.dart';
import '../models/purchase_return_item_model.dart';
import '../models/purchase_return_model.dart';

class PurchaseOrderRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String prefReservedOrderNumbers = 'reserved_purchase_order_numbers';
  static const String prefReservedReturnNumbers = 'reserved_purchase_return_numbers';

  static void clearReservedNumbersForTesting() {
    SequenceUtils.clearReservedForTesting(prefReservedOrderNumbers);
    SequenceUtils.clearReservedForTesting(prefReservedReturnNumbers);
  }

  // === PURCHASE ORDERS ===

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
      tableName: DatabaseTables.tablePurchaseOrders,
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
      tableName: DatabaseTables.tablePurchaseOrders,
      columnName: 'order_number',
      prefix: AccountingConstants.prefixPurchaseOrder,
      padDigits: 6,
      prefKey: prefReservedOrderNumbers,
      txn: txn,
    );
  }

  Future<List<PurchaseOrderModel>> getAllPurchaseOrders({
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
    String? status,
    String? search,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (fromDate != null) {
      whereClauses.add('po.order_date >= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.startOfDay(fromDate)));
    }

    if (toDate != null) {
      whereClauses.add('po.order_date <= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.endOfDay(toDate)));
    }

    if (supplierId != null && supplierId > 0) {
      whereClauses.add('po.supplier_id = ?');
      whereArgs.add(supplierId);
    }

    if (status != null && status.isNotEmpty && status != 'All') {
      whereClauses.add('po.status = ?');
      whereArgs.add(status);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(po.order_number LIKE ? OR s.name LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        po.*, 
        s.name as supplier_name,
        s.phone as supplier_phone,
        s.address as supplier_address
      FROM ${DatabaseTables.tablePurchaseOrders} po
      JOIN ${DatabaseTables.tableSuppliers} s ON po.supplier_id = s.id
      $whereString
      ORDER BY po.order_date DESC, po.id DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    if (maps.isEmpty) return [];

    final orderIds = maps.map((m) => m['id'] as int).toList();
    final placeholders = List.filled(orderIds.length, '?').join(',');
    final itemsMaps = await db.rawQuery('''
      SELECT poi.*, p.name as product_name, p.product_code, p.unit
      FROM ${DatabaseTables.tablePurchaseOrderItems} poi
      LEFT JOIN ${DatabaseTables.tableProducts} p ON poi.product_id = p.id
      WHERE poi.order_id IN ($placeholders)
      ORDER BY poi.id ASC
    ''', orderIds);

    final itemsByOrderId = <int, List<PurchaseOrderItemModel>>{};
    for (final itemMap in itemsMaps) {
      final ordId = itemMap['order_id'] as int;
      itemsByOrderId.putIfAbsent(ordId, () => []).add(PurchaseOrderItemModel.fromMap(itemMap));
    }

    return maps.map((map) {
      final id = map['id'] as int;
      return PurchaseOrderModel.fromMap(map, items: itemsByOrderId[id] ?? []);
    }).toList();
  }

  Future<PurchaseOrderModel?> getPurchaseOrderById(int id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        po.*, 
        s.name as supplier_name,
        s.phone as supplier_phone,
        s.address as supplier_address
      FROM ${DatabaseTables.tablePurchaseOrders} po
      JOIN ${DatabaseTables.tableSuppliers} s ON po.supplier_id = s.id
      WHERE po.id = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [id]);
    if (maps.isNotEmpty) {
      final items = await getItemsByOrderId(id);
      return PurchaseOrderModel.fromMap(maps.first, items: items);
    }
    return null;
  }

  Future<List<PurchaseOrderItemModel>> getItemsByOrderId(int orderId) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT poi.*, p.name as product_name, p.product_code, p.unit
      FROM ${DatabaseTables.tablePurchaseOrderItems} poi
      LEFT JOIN ${DatabaseTables.tableProducts} p ON poi.product_id = p.id
      WHERE poi.order_id = ?
      ORDER BY poi.id ASC
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [orderId]);
    return maps.map((m) => PurchaseOrderItemModel.fromMap(m)).toList();
  }

  Future<int> insertPurchaseOrder(PurchaseOrderModel order, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    if (await isOrderNumberExists(order.orderNumber, txn: txn)) {
      throw Exception('Purchase order number already exists. Please use a unique number.');
    }
    return await executor.insert(
      DatabaseTables.tablePurchaseOrders,
      order.toMap(),
    );
  }

  Future<void> insertPurchaseOrderItems(int orderId, List<PurchaseOrderItemModel> items, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    for (final item in items) {
      await executor.insert(
        DatabaseTables.tablePurchaseOrderItems,
        item.copyWith(orderId: orderId).toMap(),
      );
    }
  }

  Future<void> updatePurchaseOrderStatus(int orderId, String status, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    await executor.update(
      DatabaseTables.tablePurchaseOrders,
      {
        'status': status,
        'updated_at': AppDateUtils.formatDb(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  // === PURCHASE RETURNS ===

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
      tableName: DatabaseTables.tablePurchaseReturns,
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
      tableName: DatabaseTables.tablePurchaseReturns,
      columnName: 'return_number',
      prefix: AccountingConstants.prefixPurchaseReturn,
      padDigits: 6,
      prefKey: prefReservedReturnNumbers,
      txn: txn,
    );
  }

  Future<List<PurchaseReturnModel>> getAllPurchaseReturns({
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
    String? search,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (fromDate != null) {
      whereClauses.add('pr.return_date >= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.startOfDay(fromDate)));
    }

    if (toDate != null) {
      whereClauses.add('pr.return_date <= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.endOfDay(toDate)));
    }

    if (supplierId != null && supplierId > 0) {
      whereClauses.add('pr.supplier_id = ?');
      whereArgs.add(supplierId);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(pr.return_number LIKE ? OR s.name LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        pr.*, 
        s.name as supplier_name,
        s.phone as supplier_phone,
        s.address as supplier_address
      FROM ${DatabaseTables.tablePurchaseReturns} pr
      JOIN ${DatabaseTables.tableSuppliers} s ON pr.supplier_id = s.id
      $whereString
      ORDER BY pr.return_date DESC, pr.id DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    if (maps.isEmpty) return [];

    final returnIds = maps.map((m) => m['id'] as int).toList();
    final placeholders = List.filled(returnIds.length, '?').join(',');
    final itemsMaps = await db.rawQuery('''
      SELECT pri.*, p.name as product_name, p.product_code, p.unit
      FROM ${DatabaseTables.tablePurchaseReturnItems} pri
      LEFT JOIN ${DatabaseTables.tableProducts} p ON pri.product_id = p.id
      WHERE pri.return_id IN ($placeholders)
      ORDER BY pri.id ASC
    ''', returnIds);

    final itemsByReturnId = <int, List<PurchaseReturnItemModel>>{};
    for (final itemMap in itemsMaps) {
      final retId = itemMap['return_id'] as int;
      itemsByReturnId.putIfAbsent(retId, () => []).add(PurchaseReturnItemModel.fromMap(itemMap));
    }

    return maps.map((map) {
      final id = map['id'] as int;
      return PurchaseReturnModel.fromMap(map, items: itemsByReturnId[id] ?? []);
    }).toList();
  }

  Future<PurchaseReturnModel?> getPurchaseReturnById(int id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        pr.*, 
        s.name as supplier_name,
        s.phone as supplier_phone,
        s.address as supplier_address
      FROM ${DatabaseTables.tablePurchaseReturns} pr
      JOIN ${DatabaseTables.tableSuppliers} s ON pr.supplier_id = s.id
      WHERE pr.id = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [id]);
    if (maps.isNotEmpty) {
      final items = await getItemsByReturnId(id);
      return PurchaseReturnModel.fromMap(maps.first, items: items);
    }
    return null;
  }

  Future<List<PurchaseReturnItemModel>> getItemsByReturnId(int returnId) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT pri.*, p.name as product_name, p.product_code, p.unit
      FROM ${DatabaseTables.tablePurchaseReturnItems} pri
      LEFT JOIN ${DatabaseTables.tableProducts} p ON pri.product_id = p.id
      WHERE pri.return_id = ?
      ORDER BY pri.id ASC
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [returnId]);
    return maps.map((m) => PurchaseReturnItemModel.fromMap(m)).toList();
  }

  Future<int> insertPurchaseReturn(PurchaseReturnModel returnModel, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    if (await isReturnNumberExists(returnModel.returnNumber, txn: txn)) {
      throw Exception('Purchase return number already exists. Please use a unique number.');
    }
    return await executor.insert(
      DatabaseTables.tablePurchaseReturns,
      returnModel.toMap(),
    );
  }

  Future<void> insertPurchaseReturnItems(int returnId, List<PurchaseReturnItemModel> items, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    for (final item in items) {
      await executor.insert(
        DatabaseTables.tablePurchaseReturnItems,
        item.copyWith(returnId: returnId).toMap(),
      );
    }
  }

  Future<int> updatePurchaseOrder(PurchaseOrderModel order, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    if (await isOrderNumberExists(order.orderNumber, excludeId: order.id, txn: txn)) {
      throw Exception('Purchase order number already exists. Please use a unique number.');
    }
    return await executor.update(
      DatabaseTables.tablePurchaseOrders,
      order.toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );
  }

  Future<int> deletePurchaseOrderItems(int orderId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    return await executor.delete(
      DatabaseTables.tablePurchaseOrderItems,
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  Future<int> deletePurchaseOrder(int orderId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    final maps = await executor.query(
      DatabaseTables.tablePurchaseOrders,
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
    await deletePurchaseOrderItems(orderId, txn: txn);
    return await executor.delete(
      DatabaseTables.tablePurchaseOrders,
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<int> updatePurchaseReturn(PurchaseReturnModel returnModel, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    if (await isReturnNumberExists(returnModel.returnNumber, excludeId: returnModel.id, txn: txn)) {
      throw Exception('Purchase return number already exists. Please use a unique number.');
    }
    return await executor.update(
      DatabaseTables.tablePurchaseReturns,
      returnModel.toMap(),
      where: 'id = ?',
      whereArgs: [returnModel.id],
    );
  }

  Future<int> deletePurchaseReturnItems(int returnId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    return await executor.delete(
      DatabaseTables.tablePurchaseReturnItems,
      where: 'return_id = ?',
      whereArgs: [returnId],
    );
  }

  Future<int> deletePurchaseReturn(int returnId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    final maps = await executor.query(
      DatabaseTables.tablePurchaseReturns,
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
    await deletePurchaseReturnItems(returnId, txn: txn);
    return await executor.delete(
      DatabaseTables.tablePurchaseReturns,
      where: 'id = ?',
      whereArgs: [returnId],
    );
  }
}
