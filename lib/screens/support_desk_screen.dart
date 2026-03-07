import 'package:flutter/material.dart';

class SupportDeskScreen extends StatefulWidget {
  const SupportDeskScreen({super.key});

  @override
  State<SupportDeskScreen> createState() => _SupportDeskScreenState();
}

class _SupportDeskScreenState extends State<SupportDeskScreen> {
  final List<Map<String, dynamic>> _tickets = [];
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadSampleData();
  }

  void _loadSampleData() {
    setState(() {
      _tickets.addAll([
        {
          'id': 'TK-001',
          'customer': 'サンプル顧客A',
          'subject': '商品の使い方について',
          'status': 'open',
          'priority': 'medium',
          'createdAt': DateTime.now().subtract(const Duration(hours: 2)),
        },
        {
          'id': 'TK-002',
          'customer': 'サンプル顧客B',
          'subject': '不具合報告',
          'status': 'in_progress',
          'priority': 'high',
          'createdAt': DateTime.now().subtract(const Duration(days: 1)),
        },
      ]);
    });
  }

  List<Map<String, dynamic>> get _filteredTickets {
    if (_filterStatus == 'all') return _tickets;
    return _tickets.where((t) => t['status'] == _filterStatus).toList();
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'open':
        return '未対応';
      case 'in_progress':
        return '対応中';
      case 'resolved':
        return '解決済み';
      case 'closed':
        return '完了';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return '高';
      case 'medium':
        return '中';
      case 'low':
        return '低';
      default:
        return priority;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('SUP:サポート窓口管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('新規チケット作成（未実装）')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('全て')),
                ButtonSegment(value: 'open', label: Text('未対応')),
                ButtonSegment(value: 'in_progress', label: Text('対応中')),
                ButtonSegment(value: 'resolved', label: Text('解決済み')),
              ],
              selected: {_filterStatus},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _filterStatus = newSelection.first;
                });
              },
            ),
          ),
          Expanded(
            child: _filteredTickets.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.support_agent, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'サポートチケットがありません',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredTickets.length,
                    itemBuilder: (context, index) {
                      final ticket = _filteredTickets[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(ticket['status']),
                            child: const Icon(Icons.support_agent, color: Colors.white),
                          ),
                          title: Text(
                            ticket['subject'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('顧客: ${ticket['customer']}'),
                              Text('ID: ${ticket['id']}'),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(_getStatusLabel(ticket['status'])),
                                    backgroundColor: _getStatusColor(ticket['status']).withOpacity(0.2),
                                    labelStyle: TextStyle(
                                      color: _getStatusColor(ticket['status']),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text('優先度: ${_getPriorityLabel(ticket['priority'])}'),
                                    backgroundColor: Colors.grey.shade200,
                                    labelStyle: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${ticket['id']} の詳細表示（未実装）')),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
