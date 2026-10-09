import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../models/purchase_invoice_item_model.dart';
import '../models/purchase_invoice_model.dart';

class PurchaseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<String> getNextPurchaseNumber() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT MAX(id) as max_id FROM ${DatabaseTables.tablePurchaseInvoices}
    ''');
    final nextId = ((res.first['max_id'] as int?) ?? 0) + 1;
    return '${AccountingConstants.prefixPurchase}${nextId.toString().padLeft(6, '0')}';
  }

  Future<List<PurchaseInvoiceModel>> getAllPurchaseInvoices({
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
    String? paymentStatus,
    String? search,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (fromDate != null) {
      whereClauses.add('pi.invoice_date >= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.startOfDay(fromDate)));
    }

    if (toDate != null) {
      whereClauses.add('pi.invoice_date <= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.endOfDay(toDate)));
    }

    if (supplierId != null && supplierId > 0) {
      whereClauses.add('pi.supplier_id = ?');
      whereArgs.add(supplierId);
    }

    if (paymentStatus != null && paymentStatus.isNotEmpty && paymentStatus != 'All') {
      whereClauses.add('pi.payment_status = ?');
      whereArgs.add(paymentStatus);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(pi.invoice_number LIKE ? OR s.name LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        pi.*, 
        s.name as supplier_name,
        s.phone as supplier_phone,
        s.address as supplier_address
      FROM ${DatabaseTables.tablePurchaseInvoices} pi
      JOIN ${DatabaseTables.tableSuppliers} s ON pi.supplier_id = s.id
      $whereString
      ORDER BY pi.invoice_date DESC, pi.id DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    if (maps.isEmpty) return [];

    final purchaseIds = maps.map((m) => m['id'] as int).toList();
    final placeholders = List.filled(purchaseIds.length, '?').join(',');
    final itemsMaps = await db.rawQuery('''
      SELECT pii.*, p.name as product_name, p.product_code, p.unit
      FROM ${DatabaseTables.tablePurchaseInvoiceItems} pii
      LEFT JOIN ${DatabaseTables.tableProducts} p ON pii.product_id = p.id
      WHERE pii.invoice_id IN ($placeholders)
      ORDER BY pii.id ASC
    ''', purchaseIds);

    final itemsByPurchaseId = <int, List<PurchaseInvoiceItemModel>>{};
    for (final itemMap in itemsMaps) {
      final pId = itemMap['invoice_id'] as int;
      itemsByPurchaseId.putIfAbsent(pId, () => []).add(PurchaseInvoiceItemModel.fromMap(itemMap));
    }

    return maps.map((map) {
      final id = map['id'] as int;
      return PurchaseInvoiceModel.fromMap(map, items: itemsByPurchaseId[id] ?? []);
    }).toList();
  }

  Future<PurchaseInvoiceModel?> getPurchaseInvoiceById(int id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        pi.*, 
        s.name as supplier_name,
        s.phone as supplier_phone,
        s.address as supplier_address
      FROM ${DatabaseTables.tablePurchaseInvoices} pi
      JOIN ${DatabaseTables.tableSuppliers} s ON pi.supplier_id = s.id
      WHERE pi.id = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [id]);
    if (maps.isNotEmpty) {
      final items = await getItemsByInvoiceId(id);
      return PurchaseInvoiceModel.fromMap(maps.first, items: items);
    }
    return null;
  }

  Future<List<PurchaseInvoiceItemModel>> getItemsByInvoiceId(int invoiceId) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT pii.*, p.name as product_name, p.product_code, p.unit
      FROM ${DatabaseTables.tablePurchaseInvoiceItems} pii
      LEFT JOIN ${DatabaseTables.tableProducts} p ON pii.product_id = p.id
      WHERE pii.invoice_id = ?
      ORDER BY pii.id ASC
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [invoiceId]);
    return maps.map((m) => PurchaseInvoiceItemModel.fromMap(m)).toList();
  }

  Future<int> insertPurchaseInvoice(PurchaseInvoiceModel invoice, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    return await executor.insert(
      DatabaseTables.tablePurchaseInvoices,
      invoice.toMap(),
    );
  }

  Future<void> insertPurchaseInvoiceItems(int invoiceId, List<PurchaseInvoiceItemModel> items, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    for (final item in items) {
      await executor.insert(
        DatabaseTables.tablePurchaseInvoiceItems,
        item.copyWith(invoiceId: invoiceId).toMap(),
      );
    }
  }

  Future<void> cancelPurchaseInvoice(int invoiceId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    await executor.update(
      DatabaseTables.tablePurchaseInvoices,
      {
        'payment_status': AccountingConstants.paymentCancelled,
        'updated_at': AppDateUtils.formatDb(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<int> updatePurchaseInvoice(PurchaseInvoiceModel invoice, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    return await executor.update(
      DatabaseTables.tablePurchaseInvoices,
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  Future<int> deletePurchaseInvoiceItems(int invoiceId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    return await executor.delete(
      DatabaseTables.tablePurchaseInvoiceItems,
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<int> deletePurchaseInvoice(int invoiceId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    await deletePurchaseInvoiceItems(invoiceId, txn: txn);
    return await executor.delete(
      DatabaseTables.tablePurchaseInvoices,
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }
}
