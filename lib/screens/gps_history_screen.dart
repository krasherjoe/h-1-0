import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/gps_service.dart';

class GpsHistoryScreen extends StatefulWidget {
  const GpsHistoryScreen({super.key});

  @override
  State<GpsHistoryScreen> createState() => _GpsHistoryScreenState();
}

class _GpsHistoryScreenState extends State<GpsHistoryScreen> {
  final _gpsService = GpsService();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await _gpsService.getHistory(limit: 50);
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GPS位置情報履歴"),
        actions: [
          IconButton(onPressed: _loadHistory, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text("位置情報の履歴がありません。"))
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final date = DateTime.parse(item['timestamp']);
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.location_on)),
                      title: Text("${item['latitude'].toStringAsFixed(6)}, ${item['longitude'].toStringAsFixed(6)}"),
                      subtitle: Text(DateFormat('yyyy/MM/dd HH:mm:ss').format(date)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    );
                  },
                ),
    );
  }
}
