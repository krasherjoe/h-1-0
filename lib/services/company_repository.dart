import 'package:sqflite/sqflite.dart';
import '../models/company_model.dart';
import 'database_helper.dart';

class CompanyRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> ensureCompanyColumns() async {
    final db = await _dbHelper.database;
    try {
      await db.execute('ALTER TABLE company_info ADD COLUMN fax TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE company_info ADD COLUMN email TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE company_info ADD COLUMN url TEXT');
    } catch (_) {}
  }

  Future<CompanyInfo> getCompanyInfo() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('company_info', where: 'id = 1');
      if (maps.isEmpty) {
        final sample = CompanyInfo(
          name: "販売アシスト1号 サンプル会社",
          zipCode: "100-0001",
          address: "東京都千代田区サンプル1-1-1",
          tel: "03-1234-5678",
          fax: "03-1234-5679",
          email: "info@example.com",
          url: "https://example.com",
          registrationNumber: "T1234567890123",
        );
        await saveCompanyInfo(sample.copyWith(defaultTaxRate: 0.10));
        return sample;
      }
      final map = maps.first;
      final company = CompanyInfo(
        name: map['name'] ?? '',
        zipCode: map['zip_code'],
        address: map['address'],
        tel: map['tel'],
        fax: map['fax'],
        email: map['email'],
        url: map['url'],
        defaultTaxRate: (map['default_tax_rate'] ?? 0.10).toDouble(),
        sealPath: map['seal_path'],
        taxDisplayMode: map['tax_display_mode'] ?? 'normal',
        registrationNumber: map['registration_number'],
      );
      return company;
    } catch (e) {
      print('CompanyRepository.getCompanyInfo エラー: $e');
      // デフォルト値を返す
      return CompanyInfo(
        name: "販売アシスト1号 サンプル会社",
        zipCode: "100-0001",
        address: "東京都千代田区サンプル1-1-1",
        tel: "03-1234-5678",
        fax: "03-1234-5679",
        email: "info@example.com",
        url: "https://example.com",
        registrationNumber: "T1234567890123",
      );
    }
  }

  Future<void> saveCompanyInfo(CompanyInfo info) async {
    final db = await _dbHelper.database;
    await ensureCompanyColumns();
    
    final map = info.toMap();
    
    // registrationNumberがnullの場合、明示的にNULLを設定するためにUPDATEを使用
    if (info.registrationNumber == null) {
      await db.update(
        'company_info',
        map,
        where: 'id = ?',
        whereArgs: [1],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // registration_numberカラムをNULLに設定
      await db.update(
        'company_info',
        {'registration_number': null},
        where: 'id = ?',
        whereArgs: [1],
      );
    } else {
      await db.insert(
        'company_info',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
