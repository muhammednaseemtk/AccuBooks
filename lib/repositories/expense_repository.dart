import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../core/utils/sequence_utils.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  static const String prefReservedExpenseNumbers = 'reserved_expense_numbers';

  static void clearReservedNumbersForTesting() {
    SequenceUtils.clearReservedForTesting(prefReservedExpenseNumbers);
  }

  Future<Set<String>> getReservedExpenseNumbers() async {
    return SequenceUtils.getReserved(prefReservedExpenseNumbers);
  }

  Future<void> reserveExpenseNumber(String number) async {
    return SequenceUtils.reserve(prefReservedExpenseNumbers, number);
  }

  Future<bool> isExpenseNumberExists(
    String expenseNumber, {
    int? excludeId,
    Transaction? txn,
  }) async {
    return SequenceUtils.isNumberExists(
      dbHelper: _dbHelper,
      tableName: DatabaseTables.tableExpenses,
      columnName: 'expense_number',
      prefKey: prefReservedExpenseNumbers,
      codeOrNumber: expenseNumber,
      excludeId: excludeId,
      txn: txn,
    );
  }

  Future<String> getNextExpenseNumber({Transaction? txn}) async {
    return SequenceUtils.getNextNumber(
      dbHelper: _dbHelper,
      tableName: DatabaseTables.tableExpenses,
      columnName: 'expense_number',
      prefix: AccountingConstants.prefixExpense,
      padDigits: 6,
      prefKey: prefReservedExpenseNumbers,
      txn: txn,
    );
  }

  Future<List<ExpenseModel>> getAllExpenses({
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
    String? search,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (fromDate != null) {
      whereClauses.add('e.expense_date >= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.startOfDay(fromDate)));
    }

    if (toDate != null) {
      whereClauses.add('e.expense_date <= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.endOfDay(toDate)));
    }

    if (accountId != null && accountId > 0) {
      whereClauses.add('e.account_id = ?');
      whereArgs.add(accountId);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(e.expense_number LIKE ? OR a.account_name LIKE ? OR e.description LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        e.*, 
        a.account_name as expense_account_name,
        pa.account_name as payment_account_name
      FROM ${DatabaseTables.tableExpenses} e
      JOIN ${DatabaseTables.tableAccounts} a ON e.account_id = a.id
      JOIN ${DatabaseTables.tableAccounts} pa ON e.payment_account_id = pa.id
      $whereString
      ORDER BY e.expense_date DESC, e.id DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);
    return maps.map((m) => ExpenseModel.fromMap(m)).toList();
  }

  Future<ExpenseModel?> getExpenseById(int id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        e.*, 
        a.account_name as expense_account_name,
        pa.account_name as payment_account_name
      FROM ${DatabaseTables.tableExpenses} e
      JOIN ${DatabaseTables.tableAccounts} a ON e.account_id = a.id
      JOIN ${DatabaseTables.tableAccounts} pa ON e.payment_account_id = pa.id
      WHERE e.id = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [id]);
    if (maps.isNotEmpty) {
      return ExpenseModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertExpense(ExpenseModel expense, {Transaction? txn}) async {
    if (await isExpenseNumberExists(expense.expenseNumber, txn: txn)) {
      throw Exception('Expense number "${expense.expenseNumber}" already exists.');
    }
    final executor = txn ?? await _dbHelper.database;
    return await executor.insert(
      DatabaseTables.tableExpenses,
      expense.toMap(),
    );
  }

  Future<int> updateExpense(ExpenseModel expense, {Transaction? txn}) async {
    if (expense.id != null && await isExpenseNumberExists(expense.expenseNumber, excludeId: expense.id, txn: txn)) {
      throw Exception('Expense number "${expense.expenseNumber}" already exists.');
    }
    final executor = txn ?? await _dbHelper.database;
    return await executor.update(
      DatabaseTables.tableExpenses,
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id, {Transaction? txn}) async {
    final expense = await getExpenseById(id);
    if (expense != null) {
      await reserveExpenseNumber(expense.expenseNumber);
    }
    final executor = txn ?? await _dbHelper.database;
    return await executor.delete(
      DatabaseTables.tableExpenses,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

