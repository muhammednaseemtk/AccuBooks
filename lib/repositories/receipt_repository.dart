import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../models/receipt_model.dart';

class ReceiptRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<String> getNextReceiptNumber() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT MAX(id) as max_id FROM ${DatabaseTables.tableReceipts}
    ''');
    final nextId = ((res.first['max_id'] as int?) ?? 0) + 1;
    return '${AccountingConstants.prefixReceipt}${nextId.toString().padLeft(6, '0')}';
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
    final executor = txn ?? await _dbHelper.database;
    return await executor.insert(
      DatabaseTables.tableReceipts,
      receipt.toMap(),
    );
  }
}
