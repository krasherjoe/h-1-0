import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sales_flow_models.dart';
import '../services/sales_flow_repository.dart';

/// 販売フロー管理画面
class SalesFlowManagementScreen extends StatefulWidget {
  const SalesFlowManagementScreen({super.key});

  @override
  State<SalesFlowManagementScreen> createState() =>
      _SalesFlowManagementScreenState();
}

class _SalesFlowManagementScreenState extends State<SalesFlowManagementScreen> {
  final SalesFlowRepository _flowRepository = SalesFlowRepository();

  bool _isLoading = true;
  String _selectedTab = 'quotes';
  SalesFlowStatus? _selectedStatus;
  String _searchQuery = '';
  List<Map<String, dynamic>> _quotes = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _deliveries = [];
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  List<Map<String, dynamic>> _filterBySearch(
    List<Map<String, dynamic>> source,
    List<String> fields,
  ) {
    if (_searchQuery.isEmpty) return source;
    final query = _searchQuery.toLowerCase();
    return source.where((item) {
      for (final field in fields) {
        final value = item[field];
        if (value != null && value.toString().toLowerCase().contains(query)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  SalesFlowStatus _parseSalesStatus(dynamic value) {
    if (value is SalesFlowStatus) return value;
    if (value is String) {
      return SalesFlowStatus.values.firstWhere(
        (status) => status.toString() == value,
        orElse: () => SalesFlowStatus.quoteDraft,
      );
    }
    return SalesFlowStatus.quoteDraft;
  }

  DeliveryLinkStatus _parseDeliveryStatus(dynamic value) {
    if (value is DeliveryLinkStatus) return value;
    if (value is String) {
      return DeliveryLinkStatus.values.firstWhere(
        (status) => status.toString() == value,
        orElse: () => DeliveryLinkStatus.notLinked,
      );
    }
    return DeliveryLinkStatus.notLinked;
  }

  InvoiceLinkStatus _parseInvoiceStatus(dynamic value) {
    if (value is InvoiceLinkStatus) return value;
    if (value is String) {
      return InvoiceLinkStatus.values.firstWhere(
        (status) => status.toString() == value,
        orElse: () => InvoiceLinkStatus.notLinked,
      );
    }
    return InvoiceLinkStatus.notLinked;
  }

  String _formatCurrency(int amount) {
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '¥$formatted';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    DateTime? date;
    if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }
    if (date == null) return '—';
    return DateFormat('yyyy/MM/dd').format(date);
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _flowRepository.getQuotes(),
        _flowRepository.getOrders(),
        _flowRepository.getSales(),
        _flowRepository.getDeliveries(),
        _flowRepository.getInvoices(),
      ]);

      setState(() {
        _quotes = results[0];
        _orders = results[1];
        _sales = results[2];
        _deliveries = results[3];
        _invoices = results[4];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('データ読み込みに失敗しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('F1:販売フロー管理'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                Expanded(child: _buildContent()),
              ],
            ),
    );
  }

  void _showSalesDetails(Map<String, dynamic> sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('売上詳細: ${sale['sales_no'] ?? ''}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('売上番号', sale['sales_no']),
              _buildDetailRow('お客様', sale['client_name']),
              _buildDetailRow('件名', sale['title']),
              _buildDetailRow('金額', _formatCurrency(_toInt(sale['total']))),
              _buildDetailRow(
                'ステータス',
                _parseSalesStatus(sale['status']).displayName,
              ),
              _buildDetailRow('更新日', _formatDate(sale['updated_at'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
return Container(
       color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
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
            _selectedStatus = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
  decoration: BoxDecoration(
             color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
             border: Border(
               bottom: BorderSide(
                 color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                 width: 2,
               ),
             ),
           ),
           child: Text(
             title,
             textAlign: TextAlign.center,
             style: TextStyle(
               color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary,
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
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                setState(() {
                  _searchQuery = value.trim();
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<SalesFlowStatus>(
              initialValue: _selectedStatus,
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
            ]
            .map(
              (status) => SalesFlowStatus.values.firstWhere(
                (s) => s.toString() == status.toString(),
                orElse: () => SalesFlowStatus.deliveryPending,
              ),
            )
            .toList();
      case 'invoices':
        return [
              InvoiceLinkStatus.notLinked,
              InvoiceLinkStatus.linked,
              InvoiceLinkStatus.issued,
              InvoiceLinkStatus.overdue,
              InvoiceLinkStatus.paid,
              InvoiceLinkStatus.cancelled,
            ]
            .map(
              (status) => SalesFlowStatus.values.firstWhere(
                (s) => s.toString() == status.toString(),
                orElse: () => SalesFlowStatus.invoiceDraft,
              ),
            )
            .toList();
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
    var filteredQuotes = _selectedStatus != null && _selectedTab == 'quotes'
        ? _quotes
              .where(
                (quote) =>
                    _parseSalesStatus(quote['status']) == _selectedStatus,
              )
              .toList()
        : List<Map<String, dynamic>>.from(_quotes);
    filteredQuotes = _filterBySearch(filteredQuotes, const [
      'quote_no',
      'client_name',
      'title',
    ]);

    if (filteredQuotes.isEmpty) {
      return const Center(child: Text('見積データがありません'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredQuotes.length,
      itemBuilder: (context, index) {
        final quote = filteredQuotes[index];
        return _buildQuoteCard(quote);
      },
    );
  }

  Widget _buildQuoteCard(Map<String, dynamic> quote) {
    final status = _parseSalesStatus(quote['status']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status.color,
          child: Icon(status.icon, color: Theme.of(context).colorScheme.onPrimary, size: 20),
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
              '有効期限: ${_formatDate(quote['valid_until'])}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatCurrency(_toInt(quote['total'])),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    var filteredOrders = _selectedStatus != null && _selectedTab == 'orders'
        ? _orders
              .where(
                (order) =>
                    _parseSalesStatus(order['status']) == _selectedStatus,
              )
              .toList()
        : List<Map<String, dynamic>>.from(_orders);
    filteredOrders = _filterBySearch(filteredOrders, const [
      'order_no',
      'client_name',
      'title',
    ]);

    if (filteredOrders.isEmpty) {
      return const Center(child: Text('受注データがありません'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = _parseSalesStatus(order['status']);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status.color,
          child: Icon(status.icon, color: Theme.of(context).colorScheme.onPrimary, size: 20),
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
                '納品予定: ${_formatDate(order['delivery_date'])}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatCurrency(_toInt(order['total'])),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    var filteredSales = _selectedStatus != null && _selectedTab == 'sales'
        ? _sales
              .where(
                (sale) => _parseSalesStatus(sale['status']) == _selectedStatus,
              )
              .toList()
        : List<Map<String, dynamic>>.from(_sales);
    filteredSales = _filterBySearch(filteredSales, const [
      'sales_no',
      'client_name',
      'title',
    ]);

    if (filteredSales.isEmpty) {
      return const Center(child: Text('売上データがありません'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredSales.length,
      itemBuilder: (context, index) {
        final sale = filteredSales[index];
        final status = _parseSalesStatus(sale['status']);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status.color,
              child: Icon(status.icon, color: Theme.of(context).colorScheme.onPrimary, size: 20),
            ),
            title: Text(sale['sales_no'] ?? '売上'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale['client_name'] ?? '不明'),
                Text(sale['title'] ?? ''),
                Text(
                  '更新日: ${_formatDate(sale['updated_at'])}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(_toInt(sale['total'])),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
            onTap: () => _showSalesDetails(sale),
          ),
        );
      },
    );
  }

  Widget _buildDeliveriesList() {
    var filteredDeliveries = List<Map<String, dynamic>>.from(_deliveries);
    filteredDeliveries = _filterBySearch(filteredDeliveries, const [
      'delivery_no',
      'client_name',
    ]);
    if (filteredDeliveries.isEmpty) {
      return const Center(child: Text('配送データがありません'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredDeliveries.length,
      itemBuilder: (context, index) {
        final delivery = filteredDeliveries[index];
        final status = _parseDeliveryStatus(delivery['status']);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status.color,
              child: Icon(Icons.local_shipping, color: Theme.of(context).colorScheme.onPrimary, size: 20),
            ),
            title: Text(delivery['delivery_no'] ?? '配送'),
            subtitle: Text('更新日: ${_formatDate(delivery['updated_at'])}'),
            trailing: Text(
              status.displayName,
              style: TextStyle(
                color: status.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoicesList() {
    var filteredInvoices = List<Map<String, dynamic>>.from(_invoices);
    filteredInvoices = _filterBySearch(filteredInvoices, const [
      'invoice_no',
      'client_name',
      'title',
    ]);
    if (filteredInvoices.isEmpty) {
      return const Center(child: Text('請求データがありません'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredInvoices.length,
      itemBuilder: (context, index) {
        final invoice = filteredInvoices[index];
        final status = _parseInvoiceStatus(invoice['status']);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status.color,
              child: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.onPrimary, size: 20),
            ),
            title: Text(invoice['invoice_no'] ?? '請求書'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice['client_name'] ?? '不明'),
                Text(
                  '期限: ${_formatDate(invoice['due_date'])}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(_toInt(invoice['total'])),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(status.displayName, style: TextStyle(color: status.color)),
              ],
            ),
          ),
        );
      },
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
              _buildDetailRow('金額', _formatCurrency(_toInt(quote['total']))),
              _buildDetailRow(
                'ステータス',
                _parseSalesStatus(quote['status']).displayName,
              ),
              _buildDetailRow('発行日', _formatDate(quote['created_at'])),
              _buildDetailRow('有効期限', _formatDate(quote['valid_until'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          if (_parseSalesStatus(quote['status']) ==
              SalesFlowStatus.quoteApproved)
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
              _buildDetailRow('金額', _formatCurrency(_toInt(order['total']))),
              _buildDetailRow(
                'ステータス',
                _parseSalesStatus(order['status']).displayName,
              ),
              _buildDetailRow('受注日', _formatDate(order['created_at'])),
              if (order['delivery_date'] != null)
                _buildDetailRow('納品予定日', _formatDate(order['delivery_date'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          if (_parseSalesStatus(order['status']) ==
              SalesFlowStatus.orderConfirmed)
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

  Widget _buildDetailRow(String label, dynamic value) {
    final displayValue = value?.toString() ?? '—';
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
          Expanded(child: Text(displayValue)),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('受注に変換しました: $orderId')));
        _loadData();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('変換に失敗しました: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('売上に変換しました: $salesId')));
        _loadData();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('変換に失敗しました: $e')));
      }
    }
  }

  Future<void> _exportQuotePdf(Map<String, dynamic> quote) async {
    try {
      // PDF生成処理
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF出力機能は今後実装予定です')));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF出力に失敗しました: $e')));
      }
    }
  }

  Future<void> _exportOrderPdf(Map<String, dynamic> order) async {
    try {
      // PDF生成処理
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF出力機能は今後実装予定です')));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF出力に失敗しました: $e')));
      }
    }
  }
}
