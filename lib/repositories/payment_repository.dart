import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<String> getNextPaymentNumber() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT MAX(id) as max_id FROM ${DatabaseTables.tablePayments}
    ''');
    final nextId = ((res.first['max_id'] as int?) ?? 0) + 1;
    return '${AccountingConstants.prefixPayment}${nextId.toString().padLeft(6, '0')}';
  }

  Future<List<PaymentModel>> getAllPayments({
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
    String? search,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (fromDate != null) {
      whereClauses.add('p.payment_date >= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.startOfDay(fromDate)));
    }

    if (toDate != null) {
      whereClauses.add('p.payment_date <= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.endOfDay(toDate)));
    }

    if (supplierId != null && supplierId > 0) {
      whereClauses.add('p.supplier_id = ?');
      whereArgs.add(supplierId);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(p.payment_number LIKE ? OR s.name LIKE ? OR p.reference LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        p.*, 
        s.name as supplier_name,
        a.account_name
      FROM ${DatabaseTables.tablePayments} p
      JOIN ${DatabaseTables.tableSuppliers} s ON p.supplier_id = s.id
      JOIN ${DatabaseTables.tableAccounts} a ON p.account_id = a.id
      $whereString
      ORDER BY p.payment_date DESC, p.id DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    return maps.map((m) => PaymentModel.fromMap(m)).toList();
  }

  Future<PaymentModel?> getPaymentById(int id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        p.*, 
        s.name as supplier_name,
        a.account_name
      FROM ${DatabaseTables.tablePayments} p
      JOIN ${DatabaseTables.tableSuppliers} s ON p.supplier_id = s.id
      JOIN ${DatabaseTables.tableAccounts} a ON p.account_id = a.id
      WHERE p.id = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [id]);
    if (maps.isNotEmpty) {
      return PaymentModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertPayment(PaymentModel payment, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    return await executor.insert(
      DatabaseTables.tablePayments,
      payment.toMap(),
    );
  }
}
