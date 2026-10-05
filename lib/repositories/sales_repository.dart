import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../models/sales_invoice_item_model.dart';
import '../models/sales_invoice_model.dart';

class SalesRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<String> getNextInvoiceNumber() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT MAX(id) as max_id FROM ${DatabaseTables.tableSalesInvoices}
    ''');
    final nextId = ((res.first['max_id'] as int?) ?? 0) + 1;
    return '${AccountingConstants.prefixSales}${nextId.toString().padLeft(6, '0')}';
  }

  Future<List<SalesInvoiceModel>> getAllSalesInvoices({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
    String? paymentStatus,
    String? search,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (fromDate != null) {
      whereClauses.add('si.invoice_date >= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.startOfDay(fromDate)));
    }

    if (toDate != null) {
      whereClauses.add('si.invoice_date <= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.endOfDay(toDate)));
    }

    if (customerId != null && customerId > 0) {
      whereClauses.add('si.customer_id = ?');
      whereArgs.add(customerId);
    }

    if (paymentStatus != null && paymentStatus.isNotEmpty && paymentStatus != 'All') {
      whereClauses.add('si.payment_status = ?');
      whereArgs.add(paymentStatus);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(si.invoice_number LIKE ? OR c.name LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        si.*, 
        c.name as customer_name,
        c.phone as customer_phone,
        c.address as customer_address
      FROM ${DatabaseTables.tableSalesInvoices} si
      JOIN ${DatabaseTables.tableCustomers} c ON si.customer_id = c.id
      $whereString
      ORDER BY si.invoice_date DESC, si.id DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    if (maps.isEmpty) return [];

    final invoiceIds = maps.map((m) => m['id'] as int).toList();
    final placeholders = List.filled(invoiceIds.length, '?').join(',');
    final itemsMaps = await db.rawQuery('''
      SELECT sii.*, p.name as product_name, p.product_code, p.unit
      FROM ${DatabaseTables.tableSalesInvoiceItems} sii
      LEFT JOIN ${DatabaseTables.tableProducts} p ON sii.product_id = p.id
      WHERE sii.sales_invoice_id IN ($placeholders)
      ORDER BY sii.id ASC
    ''', invoiceIds);

    final itemsByInvoiceId = <int, List<SalesInvoiceItemModel>>{};
    for (final itemMap in itemsMaps) {
      final invId = itemMap['sales_invoice_id'] as int;
      itemsByInvoiceId.putIfAbsent(invId, () => []).add(SalesInvoiceItemModel.fromMap(itemMap));
    }

    return maps.map((map) {
      final id = map['id'] as int;
      return SalesInvoiceModel.fromMap(map, items: itemsByInvoiceId[id] ?? []);
    }).toList();
  }

  Future<SalesInvoiceModel?> getSalesInvoiceById(int id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        si.*, 
        c.name as customer_name,
        c.phone as customer_phone,
        c.address as customer_address
      FROM ${DatabaseTables.tableSalesInvoices} si
      JOIN ${DatabaseTables.tableCustomers} c ON si.customer_id = c.id
      WHERE si.id = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [id]);
    if (maps.isNotEmpty) {
      final items = await getItemsByInvoiceId(id);
      return SalesInvoiceModel.fromMap(maps.first, items: items);
    }
    return null;
  }

  Future<List<SalesInvoiceItemModel>> getItemsByInvoiceId(int invoiceId) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT sii.*, p.name as product_name, p.product_code, p.unit
      FROM ${DatabaseTables.tableSalesInvoiceItems} sii
      JOIN ${DatabaseTables.tableProducts} p ON sii.product_id = p.id
      WHERE sii.invoice_id = ?
      ORDER BY sii.id ASC
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [invoiceId]);
    return maps.map((m) => SalesInvoiceItemModel.fromMap(m)).toList();
  }

  Future<int> insertSalesInvoice(SalesInvoiceModel invoice, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    return await executor.insert(
      DatabaseTables.tableSalesInvoices,
      invoice.toMap(),
    );
  }

  Future<void> insertSalesInvoiceItems(int invoiceId, List<SalesInvoiceItemModel> items, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    for (final item in items) {
      await executor.insert(
        DatabaseTables.tableSalesInvoiceItems,
        item.copyWith(invoiceId: invoiceId).toMap(),
      );
    }
  }

  Future<int> updateSalesInvoice(SalesInvoiceModel invoice, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    return await executor.update(
      DatabaseTables.tableSalesInvoices,
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  Future<void> cancelSalesInvoice(int invoiceId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    await executor.update(
      DatabaseTables.tableSalesInvoices,
      {
        'payment_status': AccountingConstants.paymentCancelled,
        'updated_at': AppDateUtils.formatDb(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }
}
