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
    try {
      await db.execute('ALTER TABLE company_info ADD COLUMN seal_offset_x REAL DEFAULT 10.0');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE company_info ADD COLUMN seal_offset_y REAL DEFAULT 50.0');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE company_info ADD COLUMN seal_rotation REAL DEFAULT 0.0');
    } catch (_) {}
  }

  Future<CompanyInfo> getCompanyInfo() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('company_info', where: 'id = 1');
      print('DEBUG: company_info query returned ${maps.length} rows');
      if (maps.isEmpty) {
        print('DEBUG: No company_info found, returning sample data');
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
      print('DEBUG: company_info raw map: $map');
      final company = CompanyInfo(
        name: map['name'] ?? '',
        zipCode: map['zip_code'],
        address: map['address'],
        address2: map['address2'],
        tel: map['tel'],
        fax: map['fax'],
        email: map['email'],
        url: map['url'],
        defaultTaxRate: (map['default_tax_rate'] ?? 0.10).toDouble(),
        sealPath: map['seal_path'],
        sealOffsetX: (map['seal_offset_x'] as num?)?.toDouble() ?? 10.0,
        sealOffsetY: (map['seal_offset_y'] as num?)?.toDouble() ?? 50.0,
        sealRotation: (map['seal_rotation'] as num?)?.toDouble() ?? 0.0,
        taxDisplayMode: map['tax_display_mode'] ?? 'normal',
        registrationNumber: map['registration_number'],
        bankAccounts: map['bank_accounts'],
        defaultBankAccountIndex: (map['default_bank_account_index'] as num?)?.toInt() ?? 0,
      );
      print('DEBUG: Loaded company registrationNumber: ${company.registrationNumber}');
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
    
    // 明示的に全カラムを設定したマップ
    final map = {
      'id': 1,
      'name': info.name,
      'zip_code': info.zipCode,
      'address': info.address,
      'address2': info.address2,
      'tel': info.tel,
      'fax': info.fax,
      'email': info.email,
      'url': info.url,
      'default_tax_rate': info.defaultTaxRate,
      'seal_path': info.sealPath,
      'seal_offset_x': info.sealOffsetX,
      'seal_offset_y': info.sealOffsetY,
      'seal_rotation': info.sealRotation,
      'tax_display_mode': info.taxDisplayMode,
      'registration_number': info.registrationNumber,
      'bank_accounts': info.bankAccounts,
      'default_bank_account_index': info.defaultBankAccountIndex,
    };
    
    // INSERT OR REPLACEを使用
    await db.insert(
      'company_info',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // registrationNumberがnullの場合、明示的にNULLを設定（SQLiteのINSERT OR REPLACEの挙動対策）
    if (info.registrationNumber == null) {
      print('DEBUG: Setting registration_number to NULL');
      final result = await db.rawUpdate(
        'UPDATE company_info SET registration_number = NULL WHERE id = 1',
      );
      print('DEBUG: rawUpdate result (rows affected): $result');
      // 確認のために再度クエリ
      final check = await db.query('company_info', where: 'id = 1');
      if (check.isNotEmpty) {
        print('DEBUG: After NULL update, registration_number: ${check.first['registration_number']}');
      }
    } else {
      print('DEBUG: Saving registrationNumber: ${info.registrationNumber}');
    }
  }
}
