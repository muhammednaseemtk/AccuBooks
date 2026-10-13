import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/sequence_utils.dart';
import '../models/sales_invoice_item_model.dart';
import '../models/sales_invoice_model.dart';

class SalesRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String prefReservedInvoiceNumbers = 'reserved_sales_invoice_numbers';

  static void clearReservedNumbersForTesting() {
    SequenceUtils.clearReservedForTesting(prefReservedInvoiceNumbers);
  }

  Future<Set<String>> getReservedInvoiceNumbers() async {
    return SequenceUtils.getReserved(prefReservedInvoiceNumbers);
  }

  Future<void> reserveInvoiceNumber(String invoiceNumber) async {
    return SequenceUtils.reserve(prefReservedInvoiceNumbers, invoiceNumber);
  }

  Future<bool> isInvoiceNumberExists(
    String invoiceNumber, {
    int? excludeId,
    Transaction? txn,
  }) async {
    return SequenceUtils.isNumberExists(
      dbHelper: _dbHelper,
      tableName: DatabaseTables.tableSalesInvoices,
      columnName: 'invoice_number',
      prefKey: prefReservedInvoiceNumbers,
      codeOrNumber: invoiceNumber,
      excludeId: excludeId,
      txn: txn,
    );
  }

  Future<String> getNextInvoiceNumber({Transaction? txn}) async {
    return SequenceUtils.getNextNumber(
      dbHelper: _dbHelper,
      tableName: DatabaseTables.tableSalesInvoices,
      columnName: 'invoice_number',
      prefix: AccountingConstants.prefixSales,
      padDigits: 6,
      prefKey: prefReservedInvoiceNumbers,
      txn: txn,
    );
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
      WHERE sii.invoice_id IN ($placeholders)
      ORDER BY sii.id ASC
    ''', invoiceIds);

    final itemsByInvoiceId = <int, List<SalesInvoiceItemModel>>{};
    for (final itemMap in itemsMaps) {
      final invId = itemMap['invoice_id'] as int;
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
      LEFT JOIN ${DatabaseTables.tableProducts} p ON sii.product_id = p.id
      WHERE sii.invoice_id = ?
      ORDER BY sii.id ASC
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [invoiceId]);
    return maps.map((m) => SalesInvoiceItemModel.fromMap(m)).toList();
  }

  Future<int> insertSalesInvoice(SalesInvoiceModel invoice, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    if (await isInvoiceNumberExists(invoice.invoiceNumber, txn: txn)) {
      throw Exception('Sales invoice number already exists. Please use a unique number.');
    }
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
    if (await isInvoiceNumberExists(invoice.invoiceNumber, excludeId: invoice.id, txn: txn)) {
      throw Exception('Sales invoice number already exists. Please use a unique number.');
    }
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

  Future<int> deleteSalesInvoiceItems(int invoiceId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    return await executor.delete(
      DatabaseTables.tableSalesInvoiceItems,
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<int> deleteSalesInvoice(int invoiceId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    final maps = await executor.query(
      DatabaseTables.tableSalesInvoices,
      columns: ['invoice_number'],
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    if (maps.isNotEmpty) {
      final num = maps.first['invoice_number'] as String?;
      if (num != null) {
        await reserveInvoiceNumber(num);
      }
    }
    await deleteSalesInvoiceItems(invoiceId, txn: txn);
    return await executor.delete(
      DatabaseTables.tableSalesInvoices,
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }
}
