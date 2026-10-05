import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/currency_utils.dart';
import '../core/utils/date_utils.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<CustomerModel>> getAllCustomers({
    String? search,
    bool activeOnly = false,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (activeOnly) {
      whereClauses.add('c.is_active = 1');
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(c.customer_code LIKE ? OR c.name LIKE ? OR c.phone LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        c.*,
        COALESCE(s.total_sales, 0.0) as agg_sales,
        COALESCE(r.total_receipts, 0.0) as agg_receipts
      FROM ${DatabaseTables.tableCustomers} c
      LEFT JOIN (
        SELECT customer_id, SUM(grand_total) as total_sales
        FROM ${DatabaseTables.tableSalesInvoices}
        WHERE payment_status != ?
        GROUP BY customer_id
      ) s ON c.id = s.customer_id
      LEFT JOIN (
        SELECT customer_id, SUM(amount) as total_receipts
        FROM ${DatabaseTables.tableReceipts}
        GROUP BY customer_id
      ) r ON c.id = r.customer_id
      $whereString
      ORDER BY c.name ASC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      query,
      [AccountingConstants.paymentCancelled, ...whereArgs],
    );

    final results = <CustomerModel>[];
    for (final map in maps) {
      final ob = (map['opening_balance'] as num?)?.toDouble() ?? 0.0;
      final obType = (map['opening_balance_type'] as String?) ?? AccountingConstants.balanceDebit;
      final opening = (obType == AccountingConstants.balanceDebit) ? ob : -ob;
      final totalSales = (map['agg_sales'] as num?)?.toDouble() ?? 0.0;
      final totalReceipts = (map['agg_receipts'] as num?)?.toDouble() ?? 0.0;
      final outstanding = CurrencyUtils.round(opening + totalSales - totalReceipts);

      results.add(CustomerModel.fromMap(
        map,
        outstanding: outstanding,
        sales: CurrencyUtils.round(totalSales),
        receipts: CurrencyUtils.round(totalReceipts),
      ));
    }
    return results;
  }

  Future<CustomerModel?> getCustomerById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.tableCustomers,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final summary = await getCustomerFinancialSummary(id);
      return CustomerModel.fromMap(
        maps.first,
        outstanding: summary.outstanding,
        sales: summary.totalSales,
        receipts: summary.totalReceipts,
      );
    }
    return null;
  }

  Future<({double totalSales, double totalReceipts, double outstanding})> getCustomerFinancialSummary(int customerId) async {
    final db = await _dbHelper.database;

    // Customer opening balance
    final custMap = await db.query(
      DatabaseTables.tableCustomers,
      columns: ['opening_balance', 'opening_balance_type'],
      where: 'id = ?',
      whereArgs: [customerId],
    );

    double opening = 0.0;
    if (custMap.isNotEmpty) {
      final ob = (custMap.first['opening_balance'] as num?)?.toDouble() ?? 0.0;
      final obType = (custMap.first['opening_balance_type'] as String?) ?? AccountingConstants.balanceDebit;
      opening = (obType == AccountingConstants.balanceDebit) ? ob : -ob;
    }

    // Invoices sum (excluding cancelled)
    final salesRes = await db.rawQuery('''
      SELECT COALESCE(SUM(grand_total), 0.0) as total_sales
      FROM ${DatabaseTables.tableSalesInvoices}
      WHERE customer_id = ? AND payment_status != ?
    ''', [customerId, AccountingConstants.paymentCancelled]);
    final totalSales = (salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;

    // Receipts sum
    final receiptRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total_receipts
      FROM ${DatabaseTables.tableReceipts}
      WHERE customer_id = ?
    ''', [customerId]);
    final totalReceipts = (receiptRes.first['total_receipts'] as num?)?.toDouble() ?? 0.0;

    final outstanding = CurrencyUtils.round(opening + totalSales - totalReceipts);
    return (totalSales: totalSales, totalReceipts: totalReceipts, outstanding: outstanding);
  }

  Future<int> insertCustomer(CustomerModel customer) async {
    final db = await _dbHelper.database;
    return await db.insert(
      DatabaseTables.tableCustomers,
      customer.toMap(),
    );
  }

  Future<int> updateCustomer(CustomerModel customer) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseTables.tableCustomers,
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deactivateCustomer(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseTables.tableCustomers,
      {'is_active': 0, 'updated_at': AppDateUtils.formatDb(DateTime.now())},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getCustomerLedgerEntries(int customerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> ledger = [];

    // Customer info for opening
    final cust = await getCustomerById(customerId);
    if (cust != null && cust.openingBalance > 0) {
      final isDebit = cust.openingBalanceType == AccountingConstants.balanceDebit;
      ledger.add({
        'date': cust.createdAt,
        'reference': 'OB-${cust.customerCode}',
        'type': 'Opening Balance',
        'description': 'Customer Opening Balance',
        'debit': isDebit ? cust.openingBalance : 0.0,
        'credit': isDebit ? 0.0 : cust.openingBalance,
      });
    }

    // Invoices
    final invoices = await db.query(
      DatabaseTables.tableSalesInvoices,
      where: 'customer_id = ? AND payment_status != ?',
      whereArgs: [customerId, AccountingConstants.paymentCancelled],
      orderBy: 'invoice_date ASC',
    );
    for (final inv in invoices) {
      ledger.add({
        'date': AppDateUtils.parseDb(inv['invoice_date'] as String),
        'reference': inv['invoice_number'] as String,
        'type': 'Sales Invoice',
        'description': 'Invoice #${inv['invoice_number']}',
        'debit': (inv['grand_total'] as num).toDouble(),
        'credit': 0.0,
      });
    }

    // Receipts
    final receipts = await db.query(
      DatabaseTables.tableReceipts,
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'receipt_date ASC',
    );
    for (final rec in receipts) {
      ledger.add({
        'date': AppDateUtils.parseDb(rec['receipt_date'] as String),
        'reference': rec['receipt_number'] as String,
        'type': 'Receipt',
        'description': 'Payment via ${rec['payment_method']} (${rec['notes'] ?? ''})',
        'debit': 0.0,
        'credit': (rec['amount'] as num).toDouble(),
      });
    }

    // Sort by date ascending
    ledger.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Calculate running balance
    double running = 0.0;
    for (final entry in ledger) {
      final debit = entry['debit'] as double;
      final credit = entry['credit'] as double;
      running += (debit - credit);
      entry['balance'] = CurrencyUtils.round(running);
    }

    return ledger;
  }
}
