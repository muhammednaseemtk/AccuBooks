import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/accounting_constants.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../core/utils/date_utils.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_line_model.dart';

class JournalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> insertJournalEntry(JournalEntryModel entry, {Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;

    final entryId = await executor.insert(
      DatabaseTables.tableJournalEntries,
      entry.toMap(),
    );

    for (final line in entry.lines) {
      await executor.insert(
        DatabaseTables.tableJournalLines,
        line.copyWith(journalEntryId: entryId).toMap(),
      );
    }

    return entryId;
  }

  Future<String> getNextJournalNumber({Transaction? txn}) async {
    final executor = txn ?? await _dbHelper.database;
    final res = await executor.rawQuery('''
      SELECT MAX(id) as max_id FROM ${DatabaseTables.tableJournalEntries}
    ''');
    final nextId = ((res.first['max_id'] as int?) ?? 0) + 1;
    return '${AccountingConstants.prefixJournal}${nextId.toString().padLeft(6, '0')}';
  }

  Future<List<JournalEntryModel>> getAllJournalEntries({
    DateTime? fromDate,
    DateTime? toDate,
    String? type,
    String? search,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (fromDate != null) {
      whereClauses.add('transaction_date >= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.startOfDay(fromDate)));
    }

    if (toDate != null) {
      whereClauses.add('transaction_date <= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.endOfDay(toDate)));
    }

    if (type != null && type.isNotEmpty && type != 'All') {
      whereClauses.add('transaction_type = ?');
      whereArgs.add(type);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(transaction_number LIKE ? OR description LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.add(term);
      whereArgs.add(term);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.tableJournalEntries,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'transaction_date DESC, id DESC',
    );
    if (maps.isEmpty) return [];

    final entryIds = maps.map((m) => m['id'] as int).toList();
    final placeholders = List.filled(entryIds.length, '?').join(',');
    final linesMaps = await db.rawQuery('''
      SELECT jl.*, a.account_code, a.account_name, a.account_type
      FROM ${DatabaseTables.tableJournalLines} jl
      LEFT JOIN ${DatabaseTables.tableAccounts} a ON jl.account_id = a.id
      WHERE jl.journal_entry_id IN ($placeholders)
      ORDER BY jl.id ASC
    ''', entryIds);

    final linesByEntryId = <int, List<JournalLineModel>>{};
    for (final lineMap in linesMaps) {
      final eId = lineMap['journal_entry_id'] as int;
      linesByEntryId.putIfAbsent(eId, () => []).add(JournalLineModel.fromMap(lineMap));
    }

    return maps.map((map) {
      final id = map['id'] as int;
      return JournalEntryModel.fromMap(map, lines: linesByEntryId[id] ?? []);
    }).toList();
  }

  Future<JournalEntryModel?> getJournalEntryById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.tableJournalEntries,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final lines = await getJournalLinesByEntryId(id);
      return JournalEntryModel.fromMap(maps.first, lines: lines);
    }
    return null;
  }

  Future<List<JournalLineModel>> getJournalLinesByEntryId(int entryId) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT jl.*, a.account_code, a.account_name, a.account_type
      FROM ${DatabaseTables.tableJournalLines} jl
      JOIN ${DatabaseTables.tableAccounts} a ON jl.account_id = a.id
      WHERE jl.journal_entry_id = ?
      ORDER BY jl.id ASC
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [entryId]);
    return maps.map((m) => JournalLineModel.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getGeneralLedgerLines({
    required int accountId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>['jl.account_id = ?'];
    final whereArgs = <dynamic>[accountId];

    if (fromDate != null) {
      whereClauses.add('je.transaction_date >= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.startOfDay(fromDate)));
    }

    if (toDate != null) {
      whereClauses.add('je.transaction_date <= ?');
      whereArgs.add(AppDateUtils.formatDb(AppDateUtils.endOfDay(toDate)));
    }

    final query = '''
      SELECT 
        je.transaction_date,
        je.transaction_number,
        je.transaction_type,
        je.description as entry_description,
        jl.description as line_description,
        jl.debit,
        jl.credit
      FROM ${DatabaseTables.tableJournalLines} jl
      JOIN ${DatabaseTables.tableJournalEntries} je ON jl.journal_entry_id = je.id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY je.transaction_date ASC, je.id ASC
    ''';

    return await db.rawQuery(query, whereArgs);
  }

  Future<void> deleteJournalEntry(int entryId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(DatabaseTables.tableJournalLines, where: 'journal_entry_id = ?', whereArgs: [entryId]);
      await txn.delete(DatabaseTables.tableJournalEntries, where: 'id = ?', whereArgs: [entryId]);
    });
  }
}
