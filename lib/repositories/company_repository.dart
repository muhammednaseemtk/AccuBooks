import '../core/database/database_helper.dart';
import '../core/database/database_tables.dart';
import '../models/company_model.dart';

class CompanyRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<CompanyModel?> getCompany() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseTables.tableCompanies,
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return CompanyModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertCompany(CompanyModel company) async {
    final db = await _dbHelper.database;
    return await db.insert(
      DatabaseTables.tableCompanies,
      company.toMap(),
    );
  }

  Future<int> updateCompany(CompanyModel company) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseTables.tableCompanies,
      company.toMap(),
      where: 'id = ?',
      whereArgs: [company.id],
    );
  }
}
