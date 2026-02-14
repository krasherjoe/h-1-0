import 'package:sqflite/sqflite.dart';
import '../models/company_model.dart';
import 'database_helper.dart';

class CompanyRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<CompanyInfo> getCompanyInfo() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('company_info', where: 'id = 1');
    if (maps.isEmpty) {
      // 初期値
      return CompanyInfo(name: "販売アシスト1号 登録企業");
    }
    return CompanyInfo.fromMap(maps.first);
  }

  Future<void> saveCompanyInfo(CompanyInfo info) async {
    final db = await _dbHelper.database;
    await db.insert(
      'company_info',
      info.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
