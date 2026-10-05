import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/currency_utils.dart';
import '../core/utils/date_utils.dart';
import '../models/supplier_model.dart';

class SupplierRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<SupplierModel>> getAllSuppliers({
    String? search,
    bool activeOnly = false,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (activeOnly) {
      whereClauses.add('sup.is_active = 1');
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(sup.supplier_code LIKE ? OR sup.name LIKE ? OR sup.phone LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT 
        sup.*,
        COALESCE(p.total_purchases, 0.0) as agg_purchases,
        COALESCE(pay.total_payments, 0.0) as agg_payments
      FROM ${DatabaseTables.tableSuppliers} sup
      LEFT JOIN (
        SELECT supplier_id, SUM(grand_total) as total_purchases
        FROM ${DatabaseTables.tablePurchaseInvoices}
        WHERE payment_status != ?
        GROUP BY supplier_id
      ) p ON sup.id = p.supplier_id
      LEFT JOIN (
        SELECT supplier_id, SUM(amount) as total_payments
        FROM ${DatabaseTables.tablePayments}
        GROUP BY supplier_id
      ) pay ON sup.id = pay.supplier_id
      $whereString
      ORDER BY sup.name ASC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      query,
      [AccountingConstants.paymentCancelled, ...whereArgs],
    );

    final results = <SupplierModel>[];
    for (final map in maps) {
      final ob = (map['opening_balance'] as num?)?.toDouble() ?? 0.0;
      final obType = (map['opening_balance_type'] as String?) ?? AccountingConstants.balanceCredit;
      final opening = (obType == AccountingConstants.balanceCredit) ? ob : -ob;
      final totalPurchases = (map['agg_purchases'] as num?)?.toDouble() ?? 0.0;
      final totalPayments = (map['agg_payments'] as num?)?.toDouble() ?? 0.0;
      final outstanding = CurrencyUtils.round(opening + totalPurchases - totalPayments);

      results.add(SupplierModel.fromMap(
        map,
        outstanding: outstanding,
        purchases: CurrencyUtils.round(totalPurchases),
        payments: CurrencyUtils.round(totalPayments),
      ));
    }
    return results;
  }

  Future<SupplierModel?> getSupplierById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.tableSuppliers,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final summary = await getSupplierFinancialSummary(id);
      return SupplierModel.fromMap(
        maps.first,
        outstanding: summary.outstanding,
        purchases: summary.totalPurchases,
        payments: summary.totalPayments,
      );
    }
    return null;
  }

  Future<({double totalPurchases, double totalPayments, double outstanding})> getSupplierFinancialSummary(int supplierId) async {
    final db = await _dbHelper.database;

    // Supplier opening balance
    final supMap = await db.query(
      DatabaseTables.tableSuppliers,
      columns: ['opening_balance', 'opening_balance_type'],
      where: 'id = ?',
      whereArgs: [supplierId],
    );

    double opening = 0.0;
    if (supMap.isNotEmpty) {
      final ob = (supMap.first['opening_balance'] as num?)?.toDouble() ?? 0.0;
      final obType = (supMap.first['opening_balance_type'] as String?) ?? AccountingConstants.balanceCredit;
      opening = (obType == AccountingConstants.balanceCredit) ? ob : -ob;
    }

    // Purchases sum (excluding cancelled)
    final purRes = await db.rawQuery('''
      SELECT COALESCE(SUM(grand_total), 0.0) as total_purchases
      FROM ${DatabaseTables.tablePurchaseInvoices}
      WHERE supplier_id = ? AND payment_status != ?
    ''', [supplierId, AccountingConstants.paymentCancelled]);
    final totalPurchases = (purRes.first['total_purchases'] as num?)?.toDouble() ?? 0.0;

    // Payments sum
    final payRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total_payments
      FROM ${DatabaseTables.tablePayments}
      WHERE supplier_id = ?
    ''', [supplierId]);
    final totalPayments = (payRes.first['total_payments'] as num?)?.toDouble() ?? 0.0;

    final outstanding = CurrencyUtils.round(opening + totalPurchases - totalPayments);
    return (totalPurchases: totalPurchases, totalPayments: totalPayments, outstanding: outstanding);
  }

  Future<int> insertSupplier(SupplierModel supplier) async {
    final db = await _dbHelper.database;
    return await db.insert(
      DatabaseTables.tableSuppliers,
      supplier.toMap(),
    );
  }

  Future<int> updateSupplier(SupplierModel supplier) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseTables.tableSuppliers,
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<int> deactivateSupplier(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseTables.tableSuppliers,
      {'is_active': 0, 'updated_at': AppDateUtils.formatDb(DateTime.now())},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getSupplierLedgerEntries(int supplierId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> ledger = [];

    // Supplier info for opening
    final sup = await getSupplierById(supplierId);
    if (sup != null && sup.openingBalance > 0) {
      final isCredit = sup.openingBalanceType == AccountingConstants.balanceCredit;
      ledger.add({
        'date': sup.createdAt,
        'reference': 'OB-${sup.supplierCode}',
        'type': 'Opening Balance',
        'description': 'Supplier Opening Balance',
        'debit': isCredit ? 0.0 : sup.openingBalance,
        'credit': isCredit ? sup.openingBalance : 0.0,
      });
    }

    // Purchases (Credit)
    final purchases = await db.query(
      DatabaseTables.tablePurchaseInvoices,
      where: 'supplier_id = ? AND payment_status != ?',
      whereArgs: [supplierId, AccountingConstants.paymentCancelled],
      orderBy: 'invoice_date ASC',
    );
    for (final pur in purchases) {
      ledger.add({
        'date': AppDateUtils.parseDb(pur['invoice_date'] as String),
        'reference': pur['invoice_number'] as String,
        'type': 'Purchase Invoice',
        'description': 'Purchase #${pur['invoice_number']}',
        'debit': 0.0,
        'credit': (pur['grand_total'] as num).toDouble(),
      });
    }

    // Payments (Debit)
    final payments = await db.query(
      DatabaseTables.tablePayments,
      where: 'supplier_id = ?',
      whereArgs: [supplierId],
      orderBy: 'payment_date ASC',
    );
    for (final pay in payments) {
      ledger.add({
        'date': AppDateUtils.parseDb(pay['payment_date'] as String),
        'reference': pay['payment_number'] as String,
        'type': 'Payment',
        'description': 'Payment via ${pay['payment_method']} (${pay['notes'] ?? ''})',
        'debit': (pay['amount'] as num).toDouble(),
        'credit': 0.0,
      });
    }

    // Sort by date ascending
    ledger.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Calculate running balance (Credit balance increases liability)
    double running = 0.0;
    for (final entry in ledger) {
      final debit = entry['debit'] as double;
      final credit = entry['credit'] as double;
      running += (credit - debit);
      entry['balance'] = CurrencyUtils.round(running);
    }

    return ledger;
  }
}
