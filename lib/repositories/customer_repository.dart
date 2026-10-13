import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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

  Future<CustomerModel?> getCustomerById(int id, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await executor.query(
      DatabaseTables.tableCustomers,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final summary = await getCustomerFinancialSummary(id, txn: txn);
      return CustomerModel.fromMap(
        maps.first,
        outstanding: summary.outstanding,
        sales: summary.totalSales,
        receipts: summary.totalReceipts,
      );
    }
    return null;
  }

  Future<({double totalSales, double totalReceipts, double outstanding})> getCustomerFinancialSummary(int customerId, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;

    // Customer opening balance
    final custMap = await executor.query(
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
    final salesRes = await executor.rawQuery('''
      SELECT COALESCE(SUM(grand_total), 0.0) as total_sales
      FROM ${DatabaseTables.tableSalesInvoices}
      WHERE customer_id = ? AND payment_status != ?
    ''', [customerId, AccountingConstants.paymentCancelled]);
    final totalSales = (salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;

    // Receipts sum
    final receiptRes = await executor.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total_receipts
      FROM ${DatabaseTables.tableReceipts}
      WHERE customer_id = ?
    ''', [customerId]);
    final totalReceipts = (receiptRes.first['total_receipts'] as num?)?.toDouble() ?? 0.0;

    // Sales returns sum (excluding cancelled)
    double totalReturns = 0.0;
    try {
      final returnRes = await executor.rawQuery('''
        SELECT COALESCE(SUM(grand_total), 0.0) as total_returns
        FROM ${DatabaseTables.tableSalesReturns}
        WHERE customer_id = ? AND status != ?
      ''', [customerId, AccountingConstants.statusCancelled]);
      totalReturns = (returnRes.first['total_returns'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}

    final outstanding = CurrencyUtils.round(opening + totalSales - totalReceipts - totalReturns);
    return (totalSales: totalSales, totalReceipts: totalReceipts, outstanding: outstanding);
  }

  static final Set<String> _inMemoryReservedCodes = {};

  static void clearReservedCodesForTesting() {
    _inMemoryReservedCodes.clear();
  }

  Future<Set<String>> getReservedCodes() async {
    final reserved = Set<String>.from(_inMemoryReservedCodes);
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('reserved_customer_codes') ?? [];
      reserved.addAll(list.map((c) => c.toUpperCase()));
    } catch (_) {}
    return reserved;
  }

  Future<void> reserveCustomerCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return;
    _inMemoryReservedCodes.add(clean);
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList('reserved_customer_codes') ?? []).toList();
      if (!list.contains(clean)) {
        list.add(clean);
        await prefs.setStringList('reserved_customer_codes', list);
      }
    } catch (_) {}
  }

  int? _extractCodeNumber(String code) {
    final matches = RegExp(r'\d+').allMatches(code);
    if (matches.isNotEmpty) {
      return int.tryParse(matches.last.group(0)!);
    }
    return null;
  }

  Future<bool> isCustomerCodeExists(
    String customerCode, {
    int? excludeId,
    Transaction? txn,
  }) async {
    final cleanCode = customerCode.trim();
    if (cleanCode.isEmpty) return false;

    try {
      final executor = txn ?? await _dbHelper.database;
      final where = excludeId != null
          ? 'LOWER(customer_code) = LOWER(?) AND id != ?'
          : 'LOWER(customer_code) = LOWER(?)';
      final whereArgs = excludeId != null ? [cleanCode, excludeId] : [cleanCode];

      final res = await executor.query(
        DatabaseTables.tableCustomers,
        columns: ['id'],
        where: where,
        whereArgs: whereArgs,
        limit: 1,
      );

      if (res.isNotEmpty) return true;
    } catch (_) {
      final list = await getAllCustomers();
      final exists = list.any((c) =>
          c.customerCode.trim().toLowerCase() == cleanCode.toLowerCase() &&
          (excludeId == null || c.id != excludeId));
      if (exists) return true;
    }

    final reserved = await getReservedCodes();
    if (reserved.contains(cleanCode.toUpperCase())) {
      return true;
    }

    return false;
  }

  Future<String> getNextCustomerCode({Transaction? txn}) async {
    List<String> existingCodes = [];
    int seqFromDb = 0;

    try {
      final executor = txn ?? await _dbHelper.database;
      final rows = await executor.query(
        DatabaseTables.tableCustomers,
        columns: ['customer_code'],
      );
      existingCodes = rows.map((r) => (r['customer_code'] as String).trim()).toList();

      final seqRows = await executor.rawQuery(
        "SELECT seq FROM sqlite_sequence WHERE name = ?",
        [DatabaseTables.tableCustomers],
      );
      if (seqRows.isNotEmpty) {
        seqFromDb = (seqRows.first['seq'] as int?) ?? 0;
      }
    } catch (_) {
      final list = await getAllCustomers();
      existingCodes = list.map((c) => c.customerCode.trim()).toList();
    }

    final reservedCodes = await getReservedCodes();

    int maxNumber = seqFromDb;
    for (final code in existingCodes) {
      final num = _extractCodeNumber(code);
      if (num != null && num > maxNumber) {
        maxNumber = num;
      }
    }
    for (final code in reservedCodes) {
      final num = _extractCodeNumber(code);
      if (num != null && num > maxNumber) {
        maxNumber = num;
      }
    }

    int nextNumber = maxNumber + 1;
    String candidate = '${AccountingConstants.prefixCustomer}${nextNumber.toString().padLeft(3, '0')}';

    while (existingCodes.any((c) => c.toUpperCase() == candidate.toUpperCase()) ||
        reservedCodes.contains(candidate.toUpperCase())) {
      nextNumber++;
      candidate = '${AccountingConstants.prefixCustomer}${nextNumber.toString().padLeft(3, '0')}';
    }

    return candidate;
  }

  Future<int> insertCustomer(CustomerModel customer) async {
    final db = await _dbHelper.database;
    return await db.transaction<int>((txn) async {
      final exists = await isCustomerCodeExists(customer.customerCode, txn: txn);
      if (exists) {
        throw Exception('Customer code already exists. Please use a unique code.');
      }
      return await txn.insert(
        DatabaseTables.tableCustomers,
        customer.toMap(),
      );
    });
  }

  Future<int> updateCustomer(CustomerModel customer) async {
    final db = await _dbHelper.database;
    return await db.transaction<int>((txn) async {
      final exists = await isCustomerCodeExists(customer.customerCode, excludeId: customer.id, txn: txn);
      if (exists) {
        throw Exception('Customer code already exists. Please use a unique code.');
      }
      return await txn.update(
        DatabaseTables.tableCustomers,
        customer.toMap(),
        where: 'id = ?',
        whereArgs: [customer.id],
      );
    });
  }

  Future<bool> canDeleteCustomer(int id) async {
    final db = await _dbHelper.database;
    final sales = await db.query(
      DatabaseTables.tableSalesInvoices,
      where: 'customer_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (sales.isNotEmpty) return false;

    final rec = await db.query(
      DatabaseTables.tableReceipts,
      where: 'customer_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rec.isNotEmpty) return false;

    final returns = await db.query(
      DatabaseTables.tableSalesReturns,
      where: 'customer_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (returns.isNotEmpty) return false;

    return true;
  }

  Future<int> deleteCustomer(int id) async {
    final db = await _dbHelper.database;
    return await db.transaction<int>((txn) async {
      final maps = await txn.query(
        DatabaseTables.tableCustomers,
        columns: ['customer_code'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        final code = maps.first['customer_code'] as String?;
        if (code != null) {
          await reserveCustomerCode(code);
        }
      }

      // Clean up any non-posting sales orders and items for this customer
      final orders = await txn.query(
        DatabaseTables.tableSalesOrders,
        columns: ['id'],
        where: 'customer_id = ?',
        whereArgs: [id],
      );
      for (final o in orders) {
        final orderId = o['id'] as int;
        await txn.delete(
          DatabaseTables.tableSalesOrderItems,
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
      }
      await txn.delete(
        DatabaseTables.tableSalesOrders,
        where: 'customer_id = ?',
        whereArgs: [id],
      );

      return await txn.delete(
        DatabaseTables.tableCustomers,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
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
