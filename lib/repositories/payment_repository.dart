import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/sequence_utils.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  static const String prefReservedPaymentNumbers = 'reserved_payment_numbers';

  static void clearReservedNumbersForTesting() {
    SequenceUtils.clearReservedForTesting(prefReservedPaymentNumbers);
  }

  Future<Set<String>> getReservedPaymentNumbers() async {
    return SequenceUtils.getReserved(prefReservedPaymentNumbers);
  }

  Future<void> reservePaymentNumber(String number) async {
    return SequenceUtils.reserve(prefReservedPaymentNumbers, number);
  }

  Future<bool> isPaymentNumberExists(
    String paymentNumber, {
    int? excludeId,
    Transaction? txn,
  }) async {
    return SequenceUtils.isNumberExists(
      dbHelper: _dbHelper,
      tableName: DatabaseTables.tablePayments,
      columnName: 'payment_number',
      prefKey: prefReservedPaymentNumbers,
      codeOrNumber: paymentNumber,
      excludeId: excludeId,
      txn: txn,
    );
  }

  Future<String> getNextPaymentNumber({Transaction? txn}) async {
    return SequenceUtils.getNextNumber(
      dbHelper: _dbHelper,
      tableName: DatabaseTables.tablePayments,
      columnName: 'payment_number',
      prefix: AccountingConstants.prefixPayment,
      padDigits: 6,
      prefKey: prefReservedPaymentNumbers,
      txn: txn,
    );
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
    if (await isPaymentNumberExists(payment.paymentNumber, txn: txn)) {
      throw Exception('Payment number "${payment.paymentNumber}" already exists.');
    }
    final executor = txn ?? await _dbHelper.database;
    return await executor.insert(
      DatabaseTables.tablePayments,
      payment.toMap(),
    );
  }

  Future<int> updatePayment(PaymentModel payment, {Transaction? txn}) async {
    if (payment.id != null && await isPaymentNumberExists(payment.paymentNumber, excludeId: payment.id, txn: txn)) {
      throw Exception('Payment number "${payment.paymentNumber}" already exists.');
    }
    final executor = txn ?? await _dbHelper.database;
    return await executor.update(
      DatabaseTables.tablePayments,
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<int> deletePayment(int id, {Transaction? txn}) async {
    final payment = await getPaymentById(id);
    if (payment != null) {
      await reservePaymentNumber(payment.paymentNumber);
    }
    final executor = txn ?? await _dbHelper.database;
    return await executor.delete(
      DatabaseTables.tablePayments,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

