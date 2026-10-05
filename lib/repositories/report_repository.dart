import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/currency_utils.dart';
import '../core/utils/date_utils.dart';
import '../models/product_model.dart';

class ReportRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // --- Dashboard Metrics ---
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final db = await _dbHelper.database;
    final today = DateTime.now();
    final todayStart = AppDateUtils.formatDb(AppDateUtils.startOfDay(today));
    final todayEnd = AppDateUtils.formatDb(AppDateUtils.endOfDay(today));

    // 1. Today's Sales
    final salesRes = await db.rawQuery('''
      SELECT COALESCE(SUM(grand_total), 0.0) as today_sales
      FROM ${DatabaseTables.tableSalesInvoices}
      WHERE invoice_date >= ? AND invoice_date <= ? AND payment_status != ?
    ''', [todayStart, todayEnd, AccountingConstants.paymentCancelled]);
    final todaySales = (salesRes.first['today_sales'] as num?)?.toDouble() ?? 0.0;

    // 2. Today's Purchases
    final purRes = await db.rawQuery('''
      SELECT COALESCE(SUM(grand_total), 0.0) as today_purchases
      FROM ${DatabaseTables.tablePurchaseInvoices}
      WHERE invoice_date >= ? AND invoice_date <= ? AND payment_status != ?
    ''', [todayStart, todayEnd, AccountingConstants.paymentCancelled]);
    final todayPurchases = (purRes.first['today_purchases'] as num?)?.toDouble() ?? 0.0;

    // 3. Cash & Bank Balances
    final cashAcc = await db.query(DatabaseTables.tableAccounts, where: 'account_code = ?', whereArgs: [AccountingConstants.codeCash]);
    final bankAcc = await db.query(DatabaseTables.tableAccounts, where: 'account_code = ?', whereArgs: [AccountingConstants.codeBank]);

    double cashBalance = 0.0;
    if (cashAcc.isNotEmpty) {
      final id = cashAcc.first['id'] as int;
      final ob = (cashAcc.first['opening_balance'] as num?)?.toDouble() ?? 0.0;
      final lines = await db.rawQuery('''
        SELECT COALESCE(SUM(debit), 0.0) as debits, COALESCE(SUM(credit), 0.0) as credits
        FROM ${DatabaseTables.tableJournalLines} WHERE account_id = ?
      ''', [id]);
      final debits = (lines.first['debits'] as num?)?.toDouble() ?? 0.0;
      final credits = (lines.first['credits'] as num?)?.toDouble() ?? 0.0;
      cashBalance = ob + debits - credits;
    }

    double bankBalance = 0.0;
    if (bankAcc.isNotEmpty) {
      final id = bankAcc.first['id'] as int;
      final ob = (bankAcc.first['opening_balance'] as num?)?.toDouble() ?? 0.0;
      final lines = await db.rawQuery('''
        SELECT COALESCE(SUM(debit), 0.0) as debits, COALESCE(SUM(credit), 0.0) as credits
        FROM ${DatabaseTables.tableJournalLines} WHERE account_id = ?
      ''', [id]);
      final debits = (lines.first['debits'] as num?)?.toDouble() ?? 0.0;
      final credits = (lines.first['credits'] as num?)?.toDouble() ?? 0.0;
      bankBalance = ob + debits - credits;
    }

    // 4. Receivables & Payables
    final recvRes = await db.rawQuery('''
      SELECT COALESCE(SUM(balance_amount), 0.0) as total_recv
      FROM ${DatabaseTables.tableSalesInvoices}
      WHERE payment_status != ?
    ''', [AccountingConstants.paymentCancelled]);
    final totalReceivables = (recvRes.first['total_recv'] as num?)?.toDouble() ?? 0.0;

    final payRes = await db.rawQuery('''
      SELECT COALESCE(SUM(balance_amount), 0.0) as total_pay
      FROM ${DatabaseTables.tablePurchaseInvoices}
      WHERE payment_status != ?
    ''', [AccountingConstants.paymentCancelled]);
    final totalPayables = (payRes.first['total_pay'] as num?)?.toDouble() ?? 0.0;

    // 5. Total Expenses & Net Profit
    final pnl = await getProfitAndLoss();

    // 6. Recent Sales & Purchases
    final recentSales = await db.rawQuery('''
      SELECT si.*, c.name as customer_name
      FROM ${DatabaseTables.tableSalesInvoices} si
      JOIN ${DatabaseTables.tableCustomers} c ON si.customer_id = c.id
      ORDER BY si.invoice_date DESC, si.id DESC LIMIT 5
    ''');

    final recentPurchases = await db.rawQuery('''
      SELECT pi.*, s.name as supplier_name
      FROM ${DatabaseTables.tablePurchaseInvoices} pi
      JOIN ${DatabaseTables.tableSuppliers} s ON pi.supplier_id = s.id
      ORDER BY pi.invoice_date DESC, pi.id DESC LIMIT 5
    ''');

    // 7. Low stock products
    final lowStockMaps = await db.rawQuery('''
      SELECT p.*, c.name as category_name
      FROM ${DatabaseTables.tableProducts} p
      LEFT JOIN ${DatabaseTables.tableCategories} c ON p.category_id = c.id
      WHERE p.stock_quantity <= p.minimum_stock AND p.is_active = 1
      ORDER BY p.stock_quantity ASC LIMIT 10
    ''');
    final lowStock = lowStockMaps.map((m) => ProductModel.fromMap(m)).toList();

    return {
      'today_sales': CurrencyUtils.round(todaySales),
      'today_purchases': CurrencyUtils.round(todayPurchases),
      'cash_balance': CurrencyUtils.round(cashBalance),
      'bank_balance': CurrencyUtils.round(bankBalance),
      'total_receivables': CurrencyUtils.round(totalReceivables),
      'total_payables': CurrencyUtils.round(totalPayables),
      'total_expenses': CurrencyUtils.round(pnl['total_expenses'] as double),
      'total_income': CurrencyUtils.round(pnl['total_income'] as double),
      'net_profit': CurrencyUtils.round(pnl['net_profit'] as double),
      'recent_sales': recentSales,
      'recent_purchases': recentPurchases,
      'low_stock_products': lowStock,
    };
  }

  // --- Day Book ---
  Future<List<Map<String, dynamic>>> getDayBook(DateTime date) async {
    final db = await _dbHelper.database;
    final dayStart = AppDateUtils.formatDb(AppDateUtils.startOfDay(date));
    final dayEnd = AppDateUtils.formatDb(AppDateUtils.endOfDay(date));

    final query = '''
      SELECT 
        je.transaction_date,
        je.transaction_number,
        je.transaction_type,
        je.description as entry_description,
        jl.account_id,
        a.account_code,
        a.account_name,
        jl.description as line_description,
        jl.debit,
        jl.credit
      FROM ${DatabaseTables.tableJournalEntries} je
      JOIN ${DatabaseTables.tableJournalLines} jl ON je.id = jl.journal_entry_id
      JOIN ${DatabaseTables.tableAccounts} a ON jl.account_id = a.id
      WHERE je.transaction_date >= ? AND je.transaction_date <= ?
      ORDER BY je.transaction_date ASC, je.id ASC, jl.id ASC
    ''';

    return await db.rawQuery(query, [dayStart, dayEnd]);
  }

  // --- Trial Balance ---
  Future<Map<String, dynamic>> getTrialBalance({DateTime? asOfDate}) async {
    final db = await _dbHelper.database;
    final dateFilter = asOfDate != null ? AppDateUtils.formatDb(AppDateUtils.endOfDay(asOfDate)) : null;

    final query = '''
      SELECT 
        a.id,
        a.account_code,
        a.account_name,
        a.account_type,
        a.opening_balance,
        a.opening_balance_type,
        COALESCE(SUM(jl.debit), 0.0) as total_debit,
        COALESCE(SUM(jl.credit), 0.0) as total_credit
      FROM ${DatabaseTables.tableAccounts} a
      LEFT JOIN ${DatabaseTables.tableJournalLines} jl ON a.id = jl.account_id
      LEFT JOIN ${DatabaseTables.tableJournalEntries} je ON jl.journal_entry_id = je.id
      ${dateFilter != null ? 'AND je.transaction_date <= ?' : ''}
      WHERE a.is_active = 1
      GROUP BY a.id
      ORDER BY a.account_code ASC
    ''';

    final List<Map<String, dynamic>> rows = dateFilter != null
        ? await db.rawQuery(query, [dateFilter])
        : await db.rawQuery(query);

    final List<Map<String, dynamic>> reportLines = [];
    double grandTotalDebit = 0.0;
    double grandTotalCredit = 0.0;

    for (final row in rows) {
      final type = row['account_type'] as String;
      final ob = (row['opening_balance'] as num?)?.toDouble() ?? 0.0;
      final obType = (row['opening_balance_type'] as String?) ?? AccountingConstants.balanceDebit;
      final rawDebit = (row['total_debit'] as num?)?.toDouble() ?? 0.0;
      final rawCredit = (row['total_credit'] as num?)?.toDouble() ?? 0.0;

      // Net balance determination
      double netDebit = 0.0;
      double netCredit = 0.0;

      if (type == AccountingConstants.typeAsset || type == AccountingConstants.typeExpense) {
        final net = (obType == AccountingConstants.balanceDebit ? ob : -ob) + rawDebit - rawCredit;
        if (net >= 0) {
          netDebit = net;
        } else {
          netCredit = -net;
        }
      } else {
        final net = (obType == AccountingConstants.balanceCredit ? ob : -ob) + rawCredit - rawDebit;
        if (net >= 0) {
          netCredit = net;
        } else {
          netDebit = -net;
        }
      }

      if (netDebit > 0 || netCredit > 0 || ob > 0) {
        reportLines.add({
          'account_code': row['account_code'],
          'account_name': row['account_name'],
          'account_type': type,
          'debit': CurrencyUtils.round(netDebit),
          'credit': CurrencyUtils.round(netCredit),
        });
        grandTotalDebit += netDebit;
        grandTotalCredit += netCredit;
      }
    }

    return {
      'lines': reportLines,
      'total_debit': CurrencyUtils.round(grandTotalDebit),
      'total_credit': CurrencyUtils.round(grandTotalCredit),
      'is_balanced': (grandTotalDebit - grandTotalCredit).abs() <= 0.02,
    };
  }

  // --- Profit and Loss ---
  Future<Map<String, dynamic>> getProfitAndLoss({DateTime? fromDate, DateTime? toDate}) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (fromDate != null) {
      whereClauses.add('je.transaction_date >= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.startOfDay(fromDate)));
    }
    if (toDate != null) {
      whereClauses.add('je.transaction_date <= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.endOfDay(toDate)));
    }

    final dateCond = whereClauses.isNotEmpty ? 'AND ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        a.id,
        a.account_code,
        a.account_name,
        a.account_type,
        a.opening_balance,
        a.opening_balance_type,
        COALESCE(SUM(jl.debit), 0.0) as debits,
        COALESCE(SUM(jl.credit), 0.0) as credits
      FROM ${DatabaseTables.tableAccounts} a
      LEFT JOIN ${DatabaseTables.tableJournalLines} jl ON a.id = jl.account_id
      LEFT JOIN ${DatabaseTables.tableJournalEntries} je ON jl.journal_entry_id = je.id $dateCond
      WHERE a.account_type IN (?, ?) AND a.is_active = 1
      GROUP BY a.id
      ORDER BY a.account_code ASC
    ''';

    final List<Map<String, dynamic>> rows = await db.rawQuery(
      query,
      [AccountingConstants.typeIncome, AccountingConstants.typeExpense, ...whereArgs],
    );

    final incomeLines = <Map<String, dynamic>>[];
    final expenseLines = <Map<String, dynamic>>[];
    double totalIncome = 0.0;
    double totalExpenses = 0.0;

    for (final row in rows) {
      final type = row['account_type'] as String;
      final debits = (row['debits'] as num?)?.toDouble() ?? 0.0;
      final credits = (row['credits'] as num?)?.toDouble() ?? 0.0;

      if (type == AccountingConstants.typeIncome) {
        final amount = credits - debits;
        if (amount != 0) {
          incomeLines.add({
            'account_code': row['account_code'],
            'account_name': row['account_name'],
            'amount': CurrencyUtils.round(amount),
          });
          totalIncome += amount;
        }
      } else if (type == AccountingConstants.typeExpense) {
        final amount = debits - credits;
        if (amount != 0) {
          expenseLines.add({
            'account_code': row['account_code'],
            'account_name': row['account_name'],
            'amount': CurrencyUtils.round(amount),
          });
          totalExpenses += amount;
        }
      }
    }

    final netProfit = totalIncome - totalExpenses;

    return {
      'income_lines': incomeLines,
      'total_income': CurrencyUtils.round(totalIncome),
      'expense_lines': expenseLines,
      'total_expenses': CurrencyUtils.round(totalExpenses),
      'net_profit': CurrencyUtils.round(netProfit),
    };
  }

  // --- Balance Sheet ---
  Future<Map<String, dynamic>> getBalanceSheet({DateTime? asOfDate}) async {
    final db = await _dbHelper.database;
    final dateFilter = asOfDate != null ? AppDateUtils.formatDb(AppDateUtils.endOfDay(asOfDate)) : null;

    final query = '''
      SELECT 
        a.id,
        a.account_code,
        a.account_name,
        a.account_type,
        a.opening_balance,
        a.opening_balance_type,
        COALESCE(SUM(jl.debit), 0.0) as debits,
        COALESCE(SUM(jl.credit), 0.0) as credits
      FROM ${DatabaseTables.tableAccounts} a
      LEFT JOIN ${DatabaseTables.tableJournalLines} jl ON a.id = jl.account_id
      LEFT JOIN ${DatabaseTables.tableJournalEntries} je ON jl.journal_entry_id = je.id
      ${dateFilter != null ? 'AND je.transaction_date <= ?' : ''}
      WHERE a.account_type IN (?, ?, ?) AND a.is_active = 1
      GROUP BY a.id
      ORDER BY a.account_code ASC
    ''';

    final List<Map<String, dynamic>> rows = dateFilter != null
        ? await db.rawQuery(query, [dateFilter, AccountingConstants.typeAsset, AccountingConstants.typeLiability, AccountingConstants.typeEquity])
        : await db.rawQuery(query, [AccountingConstants.typeAsset, AccountingConstants.typeLiability, AccountingConstants.typeEquity]);

    final assetLines = <Map<String, dynamic>>[];
    final liabilityLines = <Map<String, dynamic>>[];
    final equityLines = <Map<String, dynamic>>[];

    double totalAssets = 0.0;
    double totalLiabilities = 0.0;
    double totalEquity = 0.0;

    for (final row in rows) {
      final type = row['account_type'] as String;
      final ob = (row['opening_balance'] as num?)?.toDouble() ?? 0.0;
      final obType = (row['opening_balance_type'] as String?) ?? AccountingConstants.balanceDebit;
      final debits = (row['debits'] as num?)?.toDouble() ?? 0.0;
      final credits = (row['credits'] as num?)?.toDouble() ?? 0.0;

      if (type == AccountingConstants.typeAsset) {
        final amount = (obType == AccountingConstants.balanceDebit ? ob : -ob) + debits - credits;
        if (amount != 0) {
          assetLines.add({
            'account_code': row['account_code'],
            'account_name': row['account_name'],
            'amount': CurrencyUtils.round(amount),
          });
          totalAssets += amount;
        }
      } else if (type == AccountingConstants.typeLiability) {
        final amount = (obType == AccountingConstants.balanceCredit ? ob : -ob) + credits - debits;
        if (amount != 0) {
          liabilityLines.add({
            'account_code': row['account_code'],
            'account_name': row['account_name'],
            'amount': CurrencyUtils.round(amount),
          });
          totalLiabilities += amount;
        }
      } else if (type == AccountingConstants.typeEquity) {
        final amount = (obType == AccountingConstants.balanceCredit ? ob : -ob) + credits - debits;
        if (amount != 0) {
          equityLines.add({
            'account_code': row['account_code'],
            'account_name': row['account_name'],
            'amount': CurrencyUtils.round(amount),
          });
          totalEquity += amount;
        }
      }
    }

    // Add Net Profit from P&L to Equity
    final pnl = await getProfitAndLoss(toDate: asOfDate);
    final netProfit = pnl['net_profit'] as double;
    if (netProfit != 0) {
      equityLines.add({
        'account_code': 'PNL-NET',
        'account_name': 'Current Period Profit / (Loss)',
        'amount': CurrencyUtils.round(netProfit),
      });
      totalEquity += netProfit;
    }

    return {
      'assets': assetLines,
      'total_assets': CurrencyUtils.round(totalAssets),
      'liabilities': liabilityLines,
      'total_liabilities': CurrencyUtils.round(totalLiabilities),
      'equity': equityLines,
      'total_equity': CurrencyUtils.round(totalEquity),
      'total_liabilities_and_equity': CurrencyUtils.round(totalLiabilities + totalEquity),
      'is_balanced': (totalAssets - (totalLiabilities + totalEquity)).abs() <= 0.05,
    };
  }

  // --- Receivables Report ---
  Future<List<Map<String, dynamic>>> getReceivablesReport() async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        c.id,
        c.customer_code,
        c.name,
        c.phone,
        c.credit_limit,
        COALESCE(SUM(si.balance_amount), 0.0) as total_due,
        COUNT(si.id) as open_invoices
      FROM ${DatabaseTables.tableCustomers} c
      LEFT JOIN ${DatabaseTables.tableSalesInvoices} si 
        ON c.id = si.customer_id AND si.payment_status != ? AND si.balance_amount > 0
      WHERE c.is_active = 1
      GROUP BY c.id
      HAVING total_due > 0
      ORDER BY total_due DESC
    ''';
    return await db.rawQuery(query, [AccountingConstants.paymentCancelled]);
  }

  // --- Payables Report ---
  Future<List<Map<String, dynamic>>> getPayablesReport() async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        s.id,
        s.supplier_code,
        s.name,
        s.phone,
        s.credit_limit,
        COALESCE(SUM(pi.balance_amount), 0.0) as total_due,
        COUNT(pi.id) as open_invoices
      FROM ${DatabaseTables.tableSuppliers} s
      LEFT JOIN ${DatabaseTables.tablePurchaseInvoices} pi 
        ON s.id = pi.supplier_id AND pi.payment_status != ? AND pi.balance_amount > 0
      WHERE s.is_active = 1
      GROUP BY s.id
      HAVING total_due > 0
      ORDER BY total_due DESC
    ''';
    return await db.rawQuery(query, [AccountingConstants.paymentCancelled]);
  }

  // --- Stock Report ---
  Future<List<Map<String, dynamic>>> getStockReport() async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        p.id,
        p.product_code,
        p.name,
        p.unit,
        p.purchase_price,
        p.sales_price,
        p.stock_quantity as closing_stock,
        p.minimum_stock,
        c.name as category_name,
        (p.stock_quantity * p.purchase_price) as stock_value
      FROM ${DatabaseTables.tableProducts} p
      LEFT JOIN ${DatabaseTables.tableCategories} c ON p.category_id = c.id
      WHERE p.is_active = 1
      ORDER BY p.name ASC
    ''';
    return await db.rawQuery(query);
  }
}
