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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo.shade700).copyWith(
          primary: Colors.indigo.shade700,
          secondary: Colors.deepOrange.shade400,
          surface: Colors.grey.shade50,
          onSurface: Colors.blueGrey.shade900,
        ),
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: Colors.indigo.shade700),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.indigo.shade700, width: 1.4),
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        fontFamily: 'IPAexGothic',
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: InteractiveViewer(
              panEnabled: false,
              scaleEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
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
    // 入力フォーム自身が Scaffold を持つため、ここではそのまま返す
    return InvoiceInputForm(
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
    );
  }
}
