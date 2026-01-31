// lib/main.dart
// version: 1.4.3c (Bug Fix: PDF layout error) - Refactored for modularity
import 'package:flutter/material.dart';

// --- 独自モジュールのインポート ---
import 'models/invoice_models.dart'; // Invoice, InvoiceItem モデル
import 'screens/invoice_input_screen.dart'; // 入力フォーム画面
import 'screens/invoice_detail_page.dart'; // 詳細表示・編集画面

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
      home: const InvoiceFlowScreen(),
    );
  }
}

class InvoiceFlowScreen extends StatefulWidget {
  const InvoiceFlowScreen({super.key});

  @override
  State<InvoiceFlowScreen> createState() => _InvoiceFlowScreenState();
}

class _InvoiceFlowScreenState extends State<InvoiceFlowScreen> {
  // 最後に生成されたデータを保持（必要に応じて）
  Invoice? _lastGeneratedInvoice;

  // PDF 生成後に呼び出され、詳細ページへ遷移するコールバック
  void _handleInvoiceGenerated(Invoice generatedInvoice, String filePath) {
    setState(() {
      _lastGeneratedInvoice = generatedInvoice;
    });

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
        title: const Text("販売アシスト1号 V1.4.3c"),
        backgroundColor: Colors.blueGrey,
      ),
      // 入力フォームを表示
      body: InvoiceInputForm(
        onInvoiceGenerated: _handleInvoiceGenerated,
      ),
    );
  }
}
