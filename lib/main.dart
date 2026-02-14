// lib/main.dart
// version: 1.5.02 (Update: Date selection & Tax fix)
import 'package:flutter/material.dart';

// --- 独自モジュールのインポート ---
import 'models/invoice_models.dart'; // Invoice, InvoiceItem モデル
import 'screens/invoice_input_screen.dart'; // 入力フォーム画面
import 'screens/invoice_detail_page.dart'; // 詳細表示・編集画面
import 'screens/invoice_history_screen.dart'; // 履歴画面
import 'services/location_service.dart'; // 位置情報サービス
import 'services/customer_repository.dart'; // 顧客リポジトリ

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '販売アシスト1号',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const InvoiceHistoryScreen(),
    );
  }
}

// 従来の InvoiceFlowScreen は新規作成用ウィジェットとして維持
class InvoiceFlowScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const InvoiceFlowScreen({super.key, this.onComplete});

  @override
  State<InvoiceFlowScreen> createState() => _InvoiceFlowScreenState();
}

class _InvoiceFlowScreenState extends State<InvoiceFlowScreen> {
  // PDF 生成後に呼び出され、詳細ページへ遷移するコールバック
  void _handleInvoiceGenerated(Invoice generatedInvoice, String filePath) {
    // 詳細ページへ遷移
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceDetailPage(invoice: generatedInvoice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text("販売アシスト1号 V1.5.02"),
        backgroundColor: Colors.blueGrey,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueGrey),
              child: Text("メニュー", style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.add_task),
              title: const Text("新規伝票作成"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("伝票履歴"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InvoiceHistoryScreen()),
                );
              },
            ),
          ],
        ),
      ),
      // 入力フォームを表示
      body: InvoiceInputForm(
        onInvoiceGenerated: (invoice, path) async {
          // GPSの記録を試みる
          final locationService = LocationService();
          final position = await locationService.getCurrentLocation();
          if (position != null) {
            final customerRepo = CustomerRepository();
            await customerRepo.addGpsHistory(invoice.customer.id, position.latitude, position.longitude);
            debugPrint("GPS recorded for customer ${invoice.customer.id}");
          }
          _handleInvoiceGenerated(invoice, path);
          if (widget.onComplete != null) widget.onComplete!();
        },
      ),
    );
  }
}
