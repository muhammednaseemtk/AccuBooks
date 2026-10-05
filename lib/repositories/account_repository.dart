import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/currency_utils.dart';
import '../core/utils/date_utils.dart';
import '../models/account_model.dart';

class AccountRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<AccountModel>> getAllAccounts({
    String? search,
    String? type,
    bool activeOnly = false,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (activeOnly) {
      whereClauses.add('a.is_active = 1');
    }

    if (type != null && type.isNotEmpty && type != 'All') {
      whereClauses.add('a.account_type = ?');
      whereArgs.add(type);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(a.account_code LIKE ? OR a.account_name LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        a.*,
        COALESCE(SUM(jl.debit), 0.0) as agg_debits,
        COALESCE(SUM(jl.credit), 0.0) as agg_credits
      FROM ${DatabaseTables.tableAccounts} a
      LEFT JOIN ${DatabaseTables.tableJournalLines} jl ON a.id = jl.account_id
      $whereString
      GROUP BY a.id
      ORDER BY a.account_code ASC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs.isNotEmpty ? whereArgs : null);

    final results = <AccountModel>[];
    for (final map in maps) {
      final acc = AccountModel.fromMap(map);
      final debits = (map['agg_debits'] as num?)?.toDouble() ?? 0.0;
      final credits = (map['agg_credits'] as num?)?.toDouble() ?? 0.0;

      double balance = 0.0;
      if (acc.accountType == AccountingConstants.typeAsset || acc.accountType == AccountingConstants.typeExpense) {
        balance = (acc.openingBalanceType == AccountingConstants.balanceDebit ? acc.openingBalance : -acc.openingBalance) +
            debits -
            credits;
      } else {
        balance = (acc.openingBalanceType == AccountingConstants.balanceCredit ? acc.openingBalance : -acc.openingBalance) +
            credits -
            debits;
      }
      results.add(acc.copyWith(currentBalance: CurrencyUtils.round(balance)));
    }
    return results;
  }

  Future<AccountModel?> getAccountById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.tableAccounts,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final acc = AccountModel.fromMap(maps.first);
      final balance = await getAccountBalance(acc.id!, acc.accountType, acc.openingBalance, acc.openingBalanceType);
      return acc.copyWith(currentBalance: balance);
    }
    return null;
  }

  Future<AccountModel?> getAccountByCode(String code) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.tableAccounts,
      where: 'account_code = ?',
      whereArgs: [code],
    );
    if (maps.isNotEmpty) {
      final acc = AccountModel.fromMap(maps.first);
      final balance = await getAccountBalance(acc.id!, acc.accountType, acc.openingBalance, acc.openingBalanceType);
      return acc.copyWith(currentBalance: balance);
    }
    return null;
  }

  Future<double> getAccountBalance(
    int accountId,
    String accountType,
    double openingBalance,
    String openingBalanceType,
  ) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(debit), 0.0) as total_debit,
        COALESCE(SUM(credit), 0.0) as total_credit
      FROM ${DatabaseTables.tableJournalLines}
      WHERE account_id = ?
    ''', [accountId]);

    final totalDebit = (result.first['total_debit'] as num?)?.toDouble() ?? 0.0;
    final totalCredit = (result.first['total_credit'] as num?)?.toDouble() ?? 0.0;

    double balance = 0.0;
    if (accountType == AccountingConstants.typeAsset || accountType == AccountingConstants.typeExpense) {
      final opening = (openingBalanceType == AccountingConstants.balanceDebit) ? openingBalance : -openingBalance;
      balance = opening + totalDebit - totalCredit;
    } else {
      final opening = (openingBalanceType == AccountingConstants.balanceCredit) ? openingBalance : -openingBalance;
      balance = opening + totalCredit - totalDebit;
    }

    return CurrencyUtils.round(balance);
  }

  Future<int> insertAccount(AccountModel account) async {
    final db = await _dbHelper.database;
    final id = await db.insert(
      DatabaseTables.tableAccounts,
      account.toMap(),
    );

    // If opening balance > 0, post opening journal entry
    if (account.openingBalance > 0) {
      final now = AppDateUtils.formatDb(DateTime.now());
      await _dbHelper.transaction((txn) async {
        final jId = await txn.insert(DatabaseTables.tableJournalEntries, {
          'transaction_number': 'OB-${account.accountCode}',
          'transaction_date': now,
          'transaction_type': AccountingConstants.transTypeOpeningBalance,
          'reference_id': id,
          'description': 'Opening balance for ${account.accountName}',
          'created_at': now,
        });

        final isDebit = account.openingBalanceType == AccountingConstants.balanceDebit;
        // Dual entry: account debit/credit against Retained Earnings (Capital/Equity)
        final equityAcc = await txn.query(
          DatabaseTables.tableAccounts,
          where: 'account_code = ?',
          whereArgs: [AccountingConstants.codeRetainedEarnings],
        );
        final equityId = equityAcc.isNotEmpty ? equityAcc.first['id'] as int : id;

        await txn.insert(DatabaseTables.tableJournalLines, {
          'journal_entry_id': jId,
          'account_id': id,
          'debit': isDebit ? account.openingBalance : 0.0,
          'credit': isDebit ? 0.0 : account.openingBalance,
          'description': 'Opening balance',
        });

        await txn.insert(DatabaseTables.tableJournalLines, {
          'journal_entry_id': jId,
          'account_id': equityId,
          'debit': isDebit ? 0.0 : account.openingBalance,
          'credit': isDebit ? account.openingBalance : 0.0,
          'description': 'Opening balance offset',
        });
      });
    }

    return id;
  }

  Future<int> updateAccount(AccountModel account) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseTables.tableAccounts,
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<bool> canDeleteAccount(int id) async {
    final db = await _dbHelper.database;
    final lines = await db.query(
      DatabaseTables.tableJournalLines,
      where: 'account_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (lines.isNotEmpty) return false;

    final rec = await db.query(
      DatabaseTables.tableReceipts,
      where: 'account_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rec.isNotEmpty) return false;

    final pay = await db.query(
      DatabaseTables.tablePayments,
      where: 'account_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (pay.isNotEmpty) return false;

    final exp = await db.query(
      DatabaseTables.tableExpenses,
      where: 'account_id = ? OR payment_account_id = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    if (exp.isNotEmpty) return false;

    final cust = await db.query(
      DatabaseTables.tableCustomers,
      where: 'account_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (cust.isNotEmpty) return false;

    final sup = await db.query(
      DatabaseTables.tableSuppliers,
      where: 'account_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (sup.isNotEmpty) return false;

    return true;
  }

  Future<int> deleteAccount(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      DatabaseTables.tableAccounts,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deactivateAccount(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseTables.tableAccounts,
      {'is_active': 0, 'updated_at': AppDateUtils.formatDb(DateTime.now())},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
