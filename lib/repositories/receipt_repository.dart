import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/sequence_utils.dart';
import '../models/receipt_model.dart';

class ReceiptRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  static const String prefReservedReceiptNumbers = 'reserved_receipt_numbers';

  static void clearReservedNumbersForTesting() {
    SequenceUtils.clearReservedForTesting(prefReservedReceiptNumbers);
  }

  Future<Set<String>> getReservedReceiptNumbers() async {
    return SequenceUtils.getReserved(prefReservedReceiptNumbers);
  }

  Future<void> reserveReceiptNumber(String number) async {
    return SequenceUtils.reserve(prefReservedReceiptNumbers, number);
  }

  Future<bool> isReceiptNumberExists(
    String receiptNumber, {
    int? excludeId,
    Transaction? txn,
  }) async {
    return SequenceUtils.isNumberExists(
      dbHelper: _dbHelper,
      tableName: DatabaseTables.tableReceipts,
      columnName: 'receipt_number',
      prefKey: prefReservedReceiptNumbers,
      codeOrNumber: receiptNumber,
      excludeId: excludeId,
      txn: txn,
    );
  }

  Future<String> getNextReceiptNumber({Transaction? txn}) async {
    return SequenceUtils.getNextNumber(
      dbHelper: _dbHelper,
      tableName: DatabaseTables.tableReceipts,
      columnName: 'receipt_number',
      prefix: AccountingConstants.prefixReceipt,
      padDigits: 6,
      prefKey: prefReservedReceiptNumbers,
      txn: txn,
    );
  }

  Future<List<ReceiptModel>> getAllReceipts({
    DateTime? fromDate,
    DateTime? toDate,
    int? customerId,
    String? search,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (fromDate != null) {
      whereClauses.add('r.receipt_date >= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.startOfDay(fromDate)));
    }

    if (toDate != null) {
      whereClauses.add('r.receipt_date <= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.endOfDay(toDate)));
    }

    if (customerId != null && customerId > 0) {
      whereClauses.add('r.customer_id = ?');
      whereArgs.add(customerId);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(r.receipt_number LIKE ? OR c.name LIKE ? OR r.reference LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        r.*, 
        c.name as customer_name,
        a.account_name
      FROM ${DatabaseTables.tableReceipts} r
      JOIN ${DatabaseTables.tableCustomers} c ON r.customer_id = c.id
      JOIN ${DatabaseTables.tableAccounts} a ON r.account_id = a.id
      $whereString
      ORDER BY r.receipt_date DESC, r.id DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    return maps.map((m) => ReceiptModel.fromMap(m)).toList();
  }

  Future<ReceiptModel?> getReceiptById(int id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        r.*, 
        c.name as customer_name,
        a.account_name
      FROM ${DatabaseTables.tableReceipts} r
      JOIN ${DatabaseTables.tableCustomers} c ON r.customer_id = c.id
      JOIN ${DatabaseTables.tableAccounts} a ON r.account_id = a.id
      WHERE r.id = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [id]);
    if (maps.isNotEmpty) {
      return ReceiptModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertReceipt(ReceiptModel receipt, {Transaction? txn}) async {
    if (await isReceiptNumberExists(receipt.receiptNumber, txn: txn)) {
      throw Exception('Receipt number "${receipt.receiptNumber}" already exists.');
    }
    final executor = txn ?? await _dbHelper.database;
    return await executor.insert(
      DatabaseTables.tableReceipts,
      receipt.toMap(),
    );
  }

  Future<int> updateReceipt(ReceiptModel receipt, {Transaction? txn}) async {
    if (receipt.id != null && await isReceiptNumberExists(receipt.receiptNumber, excludeId: receipt.id, txn: txn)) {
      throw Exception('Receipt number "${receipt.receiptNumber}" already exists.');
    }
    final executor = txn ?? await _dbHelper.database;
    return await executor.update(
      DatabaseTables.tableReceipts,
      receipt.toMap(),
      where: 'id = ?',
      whereArgs: [receipt.id],
    );
  }

  Future<int> deleteReceipt(int id, {Transaction? txn}) async {
    final receipt = await getReceiptById(id);
    if (receipt != null) {
      await reserveReceiptNumber(receipt.receiptNumber);
    }
    final executor = txn ?? await _dbHelper.database;
    return await executor.delete(
      DatabaseTables.tableReceipts,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

