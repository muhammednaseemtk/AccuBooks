import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/database_helper.dart';

class SequenceUtils {
  static final Map<String, Set<String>> _inMemoryReserved = {};

  static void clearReservedForTesting([String? key]) {
    if (key != null) {
      _inMemoryReserved[key]?.clear();
    } else {
      _inMemoryReserved.clear();
    }
  }

  static int? extractNumber(String code, [String? prefix]) {
    final clean = code.trim().toUpperCase();
    if (prefix != null && prefix.isNotEmpty) {
      final upperPrefix = prefix.trim().toUpperCase();
      if (clean.startsWith(upperPrefix)) {
        final rest = clean.substring(upperPrefix.length).trim();
        if (RegExp(r'^\d+$').hasMatch(rest)) {
          return int.tryParse(rest);
        }
        return null;
      }
    }
    final matches = RegExp(r'\d+').allMatches(clean);
    if (matches.isNotEmpty) {
      return int.tryParse(matches.last.group(0)!);
    }
    return null;
  }

  static Future<Set<String>> getReserved(String prefKey) async {
    final set = Set<String>.from(_inMemoryReserved[prefKey] ?? {});
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(prefKey) ?? [];
      set.addAll(list.map((c) => c.trim().toUpperCase()));
    } catch (_) {}
    return set;
  }

  static Future<void> reserve(String prefKey, String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return;
    _inMemoryReserved.putIfAbsent(prefKey, () => {}).add(clean);
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList(prefKey) ?? []).toList();
      if (!list.contains(clean)) {
        list.add(clean);
        await prefs.setStringList(prefKey, list);
      }
    } catch (_) {}
  }

  static Future<bool> isNumberExists({
    required DatabaseHelper dbHelper,
    required String tableName,
    required String columnName,
    required String prefKey,
    required String codeOrNumber,
    int? excludeId,
    Transaction? txn,
    Future<List<String>> Function()? fallbackExistingList,
  }) async {
    final clean = codeOrNumber.trim();
    if (clean.isEmpty) return false;

    try {
      final executor = txn ?? await dbHelper.database;
      final where = excludeId != null
          ? 'LOWER($columnName) = LOWER(?) AND id != ?'
          : 'LOWER($columnName) = LOWER(?)';
      final whereArgs = excludeId != null ? [clean, excludeId] : [clean];

      final res = await executor.query(
        tableName,
        columns: ['id'],
        where: where,
        whereArgs: whereArgs,
        limit: 1,
      );

      if (res.isNotEmpty) return true;
    } catch (_) {
      if (fallbackExistingList != null) {
        final list = await fallbackExistingList();
        final exists = list.any((c) =>
            c.trim().toLowerCase() == clean.toLowerCase());
        if (exists) return true;
      }
    }

    final reserved = await getReserved(prefKey);
    if (reserved.contains(clean.toUpperCase())) {
      return true;
    }

    return false;
  }

  static Future<String> getNextNumber({
    required DatabaseHelper dbHelper,
    required String tableName,
    required String columnName,
    required String prefix,
    required int padDigits,
    required String prefKey,
    bool useSqliteSequence = true,
    Transaction? txn,
    Future<List<String>> Function()? fallbackExistingList,
  }) async {
    List<String> existing = [];
    int seqFromDb = 0;

    try {
      final executor = txn ?? await dbHelper.database;
      final rows = await executor.query(
        tableName,
        columns: [columnName],
      );
      existing = rows.map((r) => (r[columnName] as String).trim()).toList();

      if (useSqliteSequence) {
        final seqRows = await executor.rawQuery(
          "SELECT seq FROM sqlite_sequence WHERE name = ?",
          [tableName],
        );
        if (seqRows.isNotEmpty) {
          seqFromDb = (seqRows.first['seq'] as int?) ?? 0;
        }
      }
    } catch (_) {
      if (fallbackExistingList != null) {
        existing = await fallbackExistingList();
      }
    }

    final reserved = await getReserved(prefKey);

    int maxNumber = seqFromDb;
    for (final code in existing) {
      final num = extractNumber(code, prefix);
      if (num != null && num > maxNumber) {
        maxNumber = num;
      }
    }
    for (final code in reserved) {
      final num = extractNumber(code, prefix);
      if (num != null && num > maxNumber) {
        maxNumber = num;
      }
    }

    int nextNumber = maxNumber + 1;
    String candidate = '$prefix${nextNumber.toString().padLeft(padDigits, '0')}';

    while (existing.any((c) => c.toUpperCase() == candidate.toUpperCase()) ||
        reserved.contains(candidate.toUpperCase())) {
      nextNumber++;
      candidate = '$prefix${nextNumber.toString().padLeft(padDigits, '0')}';
    }

    return candidate;
  }

  /// Reconcile document number reservations after a database restore
  /// Clears in-memory caches and purges any reserved codes that exist as active records in the restored database
  static Future<void> reconcileAfterRestore(DatabaseHelper dbHelper) async {
    _inMemoryReserved.clear();

    final modules = [
      {'pref': 'reserved_customer_codes', 'table': 'customers', 'col': 'customer_code'},
      {'pref': 'reserved_supplier_codes', 'table': 'suppliers', 'col': 'supplier_code'},
      {'pref': 'reserved_product_codes', 'table': 'products', 'col': 'product_code'},
      {'pref': 'reserved_sales_order_numbers', 'table': 'sales_orders', 'col': 'order_number'},
      {'pref': 'reserved_sales_invoice_numbers', 'table': 'sales_invoices', 'col': 'invoice_number'},
      {'pref': 'reserved_sales_return_numbers', 'table': 'sales_returns', 'col': 'return_number'},
      {'pref': 'reserved_purchase_order_numbers', 'table': 'purchase_orders', 'col': 'order_number'},
      {'pref': 'reserved_purchase_numbers', 'table': 'purchase_invoices', 'col': 'invoice_number'},
      {'pref': 'reserved_purchase_return_numbers', 'table': 'purchase_returns', 'col': 'return_number'},
      {'pref': 'reserved_receipt_numbers', 'table': 'receipts', 'col': 'receipt_number'},
      {'pref': 'reserved_payment_numbers', 'table': 'payments', 'col': 'payment_number'},
      {'pref': 'reserved_expense_numbers', 'table': 'expenses', 'col': 'expense_number'},
      {'pref': 'reserved_journal_numbers', 'table': 'journal_entries', 'col': 'transaction_number'},
    ];

    try {
      final prefs = await SharedPreferences.getInstance();
      final db = await dbHelper.database;

      for (final m in modules) {
        final prefKey = m['pref']!;
        final tableName = m['table']!;
        final colName = m['col']!;

        final reservedList = prefs.getStringList(prefKey) ?? [];
        if (reservedList.isEmpty) continue;

        try {
          final rows = await db.query(tableName, columns: [colName]);
          final existing = rows
              .map((r) => (r[colName] as String?)?.trim().toUpperCase() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet();

          // Remove any codes that actually exist in the restored database
          final cleaned = reservedList
              .map((s) => s.trim().toUpperCase())
              .where((s) => !existing.contains(s))
              .toList();

          await prefs.setStringList(prefKey, cleaned);
        } catch (_) {}
      }
    } catch (_) {}
  }
}
