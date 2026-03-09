import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sales_flow_models.dart';
import '../services/sales_flow_repository.dart';

/// 販売フロー管理画面
class SalesFlowManagementScreen extends StatefulWidget {
  const SalesFlowManagementScreen({super.key});

  @override
  State<SalesFlowManagementScreen> createState() => _SalesFlowManagementScreenState();
}

class _SalesFlowManagementScreenState extends State<SalesFlowManagementScreen> {
  final SalesFlowRepository _flowRepository = SalesFlowRepository();
  
  bool _isLoading = true;
  String _selectedTab = 'quotes';
  SalesFlowStatus? _selectedStatus;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // TODO: 実際のデータ読み込み処理を実装
      // 現時点ではダミーデータを生成
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データ読み込みに失敗しました: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('F1:販売フロー管理'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildTabBar(),
                _buildFilterSection(),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      color: Colors.indigo.shade50,
      child: Row(
        children: [
          _buildTabButton('quotes', '見積'),
          _buildTabButton('orders', '受注'),
          _buildTabButton('sales', '売上'),
          _buildTabButton('deliveries', '配送'),
          _buildTabButton('invoices', '請求'),
        ],
      ),
    );
  }
  
  Widget _buildTabButton(String tab, String title) {
    final isSelected = _selectedTab == tab;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = tab;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.indigo : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.indigo,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              decoration: const InputDecoration(
                labelText: '検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // TODO: 検索機能を実装
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<SalesFlowStatus>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'ステータス',
                border: OutlineInputBorder(),
              ),
              items: _getStatusOptions(_selectedTab).map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
  
  List<SalesFlowStatus> _getStatusOptions(String tab) {
    switch (tab) {
      case 'quotes':
        return [
          SalesFlowStatus.quoteDraft,
          SalesFlowStatus.quoteSubmitted,
          SalesFlowStatus.quoteApproved,
          SalesFlowStatus.quoteRejected,
          SalesFlowStatus.quoteExpired,
        ];
      case 'orders':
        return [
          SalesFlowStatus.orderDraft,
          SalesFlowStatus.orderSubmitted,
          SalesFlowStatus.orderConfirmed,
          SalesFlowStatus.orderCancelled,
        ];
      case 'sales':
        return [
          SalesFlowStatus.salesDraft,
          SalesFlowStatus.salesConfirmed,
          SalesFlowStatus.salesInvoiced,
          SalesFlowStatus.salesPaid,
          SalesFlowStatus.salesCancelled,
        ];
      case 'deliveries':
        return [
          DeliveryLinkStatus.notLinked,
          DeliveryLinkStatus.linked,
          DeliveryLinkStatus.inTransit,
          DeliveryLinkStatus.completed,
          DeliveryLinkStatus.failed,
          DeliveryLinkStatus.cancelled,
        ].map((status) => SalesFlowStatus.values.firstWhere(
          (s) => s.toString() == status.toString(),
          orElse: () => SalesFlowStatus.deliveryPending,
        )).toList();
      case 'invoices':
        return [
          InvoiceLinkStatus.notLinked,
          InvoiceLinkStatus.linked,
          InvoiceLinkStatus.issued,
          InvoiceLinkStatus.overdue,
          InvoiceLinkStatus.paid,
          InvoiceLinkStatus.cancelled,
        ].map((status) => SalesFlowStatus.values.firstWhere(
          (s) => s.toString() == status.toString(),
          orElse: () => SalesFlowStatus.invoiceDraft,
        )).toList();
      default:
        return [];
    }
  }
  
  Widget _buildContent() {
    switch (_selectedTab) {
      case 'quotes':
        return _buildQuotesList();
      case 'orders':
        return _buildOrdersList();
      case 'sales':
        return _buildSalesList();
      case 'deliveries':
        return _buildDeliveriesList();
      case 'invoices':
        return _buildInvoicesList();
      default:
        return const Center(child: Text('データがありません'));
    }
  }
  
  Widget _buildQuotesList() {
    // サンプルデータ
    final quotes = [
      {
        'id': '1',
        'quote_no': 'Q-2024-001',
        'client_name': '株式会社ABC',
        'title': 'ソフトウェア開発',
        'total': 1000000,
        'status': SalesFlowStatus.quoteSubmitted,
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        'valid_until': DateTime.now().add(const Duration(days: 25)).toIso8601String(),
      },
      {
        'id': '2',
        'quote_no': 'Q-2024-002',
        'client_name': '株式会社XYZ',
        'title': 'システム保守',
        'total': 500000,
        'status': SalesFlowStatus.quoteApproved,
        'created_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        'valid_until': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
      },
    ];
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: quotes.length,
      itemBuilder: (context, index) {
        final quote = quotes[index];
        return _buildQuoteCard(quote);
      },
    );
  }
  
  Widget _buildQuoteCard(Map<String, dynamic> quote) {
    final status = quote['status'] as SalesFlowStatus;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status.color,
          child: Icon(
            status.icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          quote['quote_no'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quote['client_name']),
            Text(quote['title']),
            Text(
              '有効期限: ${DateFormat('yyyy/MM/dd').format(DateTime.parse(quote['valid_until']))}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '¥${(quote['total'] as int).toString().replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (Match m) => '${m[1]},',
                  )}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: status.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showQuoteDetails(quote),
      ),
    );
  }
  
  Widget _buildOrdersList() {
    // サンプルデータ
    final orders = [
      {
        'id': '1',
        'order_no': 'ORD-2024-001',
        'client_name': '株式会社ABC',
        'title': 'ソフトウェア開発',
        'total': 1000000,
        'status': SalesFlowStatus.orderConfirmed,
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'delivery_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      },
    ];
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order);
      },
    );
  }
  
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as SalesFlowStatus;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status.color,
          child: Icon(
            status.icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          order['order_no'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order['client_name']),
            Text(order['title']),
            if (order['delivery_date'] != null)
              Text(
                '納品予定: ${DateFormat('yyyy/MM/dd').format(DateTime.parse(order['delivery_date']))}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '¥${(order['total'] as int).toString().replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (Match m) => '${m[1]},',
                  )}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: status.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showOrderDetails(order),
      ),
    );
  }
  
  Widget _buildSalesList() {
    return const Center(
      child: Text('売上データはありません'),
    );
  }
  
  Widget _buildDeliveriesList() {
    return const Center(
      child: Text('配送データはありません'),
    );
  }
  
  Widget _buildInvoicesList() {
    return const Center(
      child: Text('請求データはありません'),
    );
  }
  
  void _showQuoteDetails(Map<String, dynamic> quote) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('見積詳細: ${quote['quote_no']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('見積番号', quote['quote_no']),
              _buildDetailRow('お客様', quote['client_name']),
              _buildDetailRow('件名', quote['title']),
              _buildDetailRow('金額', '¥${(quote['total'] as int).toString().replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (Match m) => '${m[1]},',
                  )}'),
              _buildDetailRow('ステータス', (quote['status'] as SalesFlowStatus).displayName),
              _buildDetailRow('発行日', DateFormat('yyyy/MM/dd').format(DateTime.parse(quote['created_at']))),
              _buildDetailRow('有効期限', DateFormat('yyyy/MM/dd').format(DateTime.parse(quote['valid_until']))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          if ((quote['status'] as SalesFlowStatus) == SalesFlowStatus.quoteApproved)
            ElevatedButton(
              onPressed: () => _convertQuoteToOrder(quote),
              child: const Text('受注に変換'),
            ),
          ElevatedButton(
            onPressed: () => _exportQuotePdf(quote),
            child: const Text('PDF出力'),
          ),
        ],
      ),
    );
  }
  
  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('受注詳細: ${order['order_no']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('受注番号', order['order_no']),
              _buildDetailRow('お客様', order['client_name']),
              _buildDetailRow('件名', order['title']),
              _buildDetailRow('金額', '¥${(order['total'] as int).toString().replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (Match m) => '${m[1]},',
                  )}'),
              _buildDetailRow('ステータス', (order['status'] as SalesFlowStatus).displayName),
              _buildDetailRow('受注日', DateFormat('yyyy/MM/dd').format(DateTime.parse(order['created_at']))),
              if (order['delivery_date'] != null)
                _buildDetailRow('納品予定日', DateFormat('yyyy/MM/dd').format(DateTime.parse(order['delivery_date']))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          if ((order['status'] as SalesFlowStatus) == SalesFlowStatus.orderConfirmed)
            ElevatedButton(
              onPressed: () => _convertOrderToSales(order),
              child: const Text('売上に変換'),
            ),
          ElevatedButton(
            onPressed: () => _exportOrderPdf(order),
            child: const Text('PDF出力'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  Future<void> _convertQuoteToOrder(Map<String, dynamic> quote) async {
    try {
      final orderId = await _flowRepository.convertQuoteToOrder(
        quoteId: quote['id'],
        userId: 'current_user', // 実際にはログインユーザーID
      );
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('受注に変換しました: $orderId')),
        );
        _loadData();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('変換に失敗しました: $e')),
        );
      }
    }
  }
  
  Future<void> _convertOrderToSales(Map<String, dynamic> order) async {
    try {
      final salesId = await _flowRepository.convertOrderToSales(
        orderId: order['id'],
        userId: 'current_user', // 実際にはログインユーザーID
      );
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('売上に変換しました: $salesId')),
        );
        _loadData();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('変換に失敗しました: $e')),
        );
      }
    }
  }
  
  Future<void> _exportQuotePdf(Map<String, dynamic> quote) async {
    try {
      // PDF生成処理
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF出力機能は今後実装予定です')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF出力に失敗しました: $e')),
        );
      }
    }
  }
  
  Future<void> _exportOrderPdf(Map<String, dynamic> order) async {
    try {
      // PDF生成処理
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF出力機能は今後実装予定です')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF出力に失敗しました: $e')),
        );
      }
    }
  }
}
