import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'product_master_screen.dart';
import 'customer_master_screen.dart';
import 'activity_log_screen.dart';
import 'sales_report_screen.dart';
import 'gps_history_screen.dart';

class ManagementScreen extends StatelessWidget {
  const ManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductMasterScreen())),
          ),
          _buildMenuTile(
            context,
            Icons.people,
            "顧客マスター管理",
            "取引先（請求先）の名称や敬称を管理します",
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerMasterScreen())),
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
            () => _showComingSoon(context),
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
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ActivityLogScreen())),
          ),
          _buildMenuTile(
            context,
            Icons.analytics_outlined,
            "売上・資金管理レポート",
            "売上や資金の流れを分析します", // Added subtitle
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesReportScreen())),
          ),
          _buildMenuTile(
            context,
            Icons.settings_backup_restore,
            "データベース・リストア",
            "バックアップから全てのデータを復元します",
            () => _showComingSoon(context),
          ),
          _buildMenuTile(
            context,
            Icons.location_history,
            "GPS座標履歴の管理",
            "過去に取得した位置情報の履歴を確認します",
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GpsHistoryScreen())),
          ),
          const Divider(),
          _buildSectionHeader("外部同期 (将来のOdoo連携)"),
          _buildMenuTile(
            context,
            Icons.sync,
            "クラウド同期を実行",
            "未同期の伝票をクラウドマスターへ送信します",
            () => _showComingSoon(context),
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
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("この機能は次期バージョンで実装予定です。同期フラグ等の基盤は準備済みです。")),
    );
  }

  Future<void> _exportAllInvoicesCsv(BuildContext context) async {
    final invoiceRepo = InvoiceRepository();
    final customerRepo = CustomerRepository();
    
    final customers = await customerRepo.getAllCustomers();
    final invoices = await invoiceRepo.getAllInvoices(customers);
    
    if (invoices.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("エクスポートするデータがありません")));
      return;
    }

    StringBuffer buffer = StringBuffer();
    buffer.writeln("日付,請求番号,取引先,合計金額,備考");
    for (var inv in invoices) {
      buffer.writeln("${inv.date},$inv.invoiceNumber,${inv.customer.formalName},${inv.totalAmount},${inv.notes ?? ""}");
    }

    await Share.share(buffer.toString(), subject: '販売アシスト1号_全伝票マスター');
  }

  Future<void> _backupDatabase(BuildContext context) async {
    final dbPath = p.join(await getDatabasesPath(), 'gemi_invoice.db');
    final file = File(dbPath);
    if (await file.exists()) {
      await Share.shareXFiles([XFile(dbPath)], text: '販売アシスト1号_DBバックアップ');
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("データベースファイルが見つかりません")));
    }
  }
}
