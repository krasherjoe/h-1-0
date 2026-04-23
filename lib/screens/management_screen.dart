import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'product_master_screen.dart';
import 'screen_pc_product_category_master.dart';
import 'customer_master_screen.dart';
import 'activity_log_screen.dart';
import 'sales_report_screen.dart';
import 'gps_history_screen.dart';
import 'camera_delivery_photo_screen.dart';
import 'fast_search_screen.dart';
import 'restore_screen.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text("マスター管理・同期"),
        backgroundColor: Colors.blueGrey,
      ),
      body: ListView(
        children: [
          _buildSectionHeader("データ入出力"),
          _buildMenuTile(
            context,
            Icons.inventory_2,
            "商品マスター管理",
            "販売商品の名称や単価を管理します",
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProductMasterScreen(),
              ),
            ),
          ),
          _buildMenuTile(
            context,
            Icons.category,
            "PC:商品カテゴリーマスター",
            "商品カテゴリーの追加・編集・非表示を管理します",
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProductCategoryMasterScreen(),
              ),
            ),
          ),
          _buildMenuTile(
            context,
            Icons.people,
            "顧客マスター管理",
            "取引先（請求先）の名称や敬称を管理します",
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomerMasterScreen(),
              ),
            ),
          ),
          _buildMenuTile(
            context,
            Icons.upload_file,
            "伝票マスター・エクスポート",
            "全データをCSV形式で出力します",
            () => _exportAllInvoicesCsv(context),
          ),
          _buildMenuTile(
            context,
            Icons.download,
            "伝票マスター・インポート",
            "外部ファイルからデータを取り込みます",
            () => _importCsv(context),
          ),
          const Divider(),
          _buildSectionHeader("バックアップ & セキュリティ"),
          _buildMenuTile(
            context,
            Icons.backup,
            "データベース・バックアップ",
            "SQLiteファイルを外部へ保存・シェアします",
            () => _backupDatabase(context),
          ),
          _buildMenuTile(
            context,
            Icons.list_alt,
            "アクティビティ履歴 (Git風)",
            "データの作成・変更・削除の履歴を確認します",
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ActivityLogScreen(),
              ),
            ),
          ),
          _buildMenuTile(
            context,
            Icons.analytics_outlined,
            "売上・資金管理レポート",
            "売上や資金の流れを分析します", // Added subtitle
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SalesReportScreen(),
              ),
            ),
          ),
          _buildMenuTile(
            context,
            Icons.settings_backup_restore,
            "データベース・リストア",
            "バックアップから全てのデータを復元します",
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RestoreScreen()),
            ),
          ),
          _buildMenuTile(
            context,
            Icons.location_history,
            "GPS座標履歴の管理",
            "過去に取得した位置情報の履歴を確認します",
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GpsHistoryScreen()),
            ),
          ),
          _buildMenuTile(
            context,
            Icons.camera_alt,
            "納品写真管理",
            "カメラで撮影した納品写真を管理します",
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CameraDeliveryPhotoScreen(),
              ),
            ),
          ),
          _buildMenuTile(
            context,
            Icons.search,
            "高速全文検索",
            "FTSで商品・顧客データを高速検索します",
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FastSearchScreen()),
            ),
          ),
          const Divider(),
          _buildSectionHeader("外部同期 (将来のOdoo連携)"),
          _buildMenuTile(
            context,
            Icons.sync,
            "クラウド同期を実行",
            "未同期の伝票をクラウドマスターへ送信します",
            () => _syncWithCloud(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _exportAllInvoicesCsv(BuildContext context) async {
    final invoiceRepo = InvoiceRepository();
    final customerRepo = CustomerRepository();

    final customers = await customerRepo.getAllCustomers();
    final invoices = await invoiceRepo.getAllInvoices(customers);

    if (invoices.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("エクスポートするデータがありません")));
      return;
    }

    StringBuffer buffer = StringBuffer();
    buffer.writeln("日付,請求番号,取引先,合計金額,備考");
    for (var inv in invoices) {
      buffer.writeln(
        "${inv.date},$inv.invoiceNumber,${inv.customer.formalName},${inv.totalAmount},${inv.notes ?? ""}",
      );
    }

    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: '販売アシスト1号_全伝票マスター'),
    );
  }

  Future<void> _backupDatabase(BuildContext context) async {
    // 新しい DB フォルダからファイルを参照
    String dbPath;
    if (Platform.isAndroid) {
      dbPath = '/storage/emulated/0/販売アシスト 1 号/販売アシスト 1 号.db';
    } else if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      dbPath = p.join(dir.path, '販売アシスト 1 号.db');
    } else {
      dbPath = p.join(await getDatabasesPath(), '販売アシスト 1 号.db');
    }

    final file = File(dbPath);
    if (await file.exists()) {
      await SharePlus.instance.share(
        ShareParams(text: '販売アシスト 1 号_DB バックアップ', files: [XFile(dbPath)]),
      );
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("データベースファイルが見つかりません")));
    }
  }

  Future<void> _importCsv(BuildContext context) async {
    // 将来的に file_picker 等を使用してファイルを選択する
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("インポート"),
        content: const Text("インポート用CSVファイルを選択してください。\n(現在この機能はファイル選択の基盤待ちです)"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("閉じる"),
          ),
        ],
      ),
    );
  }

  Future<void> _syncWithCloud(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("クラウド同期 (Odoo)"),
        content: const Text("クラウドサーバーとデータを同期します。\n未同期項目: 5件"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("閉じる"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("実行"),
          ),
        ],
      ),
    );
  }
}
