import 'package:flutter/material.dart';
import '../services/app_settings_repository.dart';
import 'email_settings_screen.dart';
import 'master_hub_page.dart';
import 'company_info_screen.dart';
import 'customer_master_screen.dart';
import 'product_master_screen.dart';
import 'dashboard_menu_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = AppSettingsRepository();
  String _theme = 'system';
  String _summaryTheme = 'white';
  final TextEditingController _statusTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final theme = await _repo.getTheme();
      setState(() => _theme = theme);
      final summaryTheme = await _repo.getSummaryTheme();
      setState(() => _summaryTheme = summaryTheme);
      final statusText = await _repo.getDashboardStatusText();
      setState(() => _statusTextController.text = statusText);
    });
  }

  @override
  void dispose() {
    _statusTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('S1:設定'),
      ),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(20)),
          ListTile(
            leading: const Icon(Icons.dashboard_customize),
            title: const Text('ダッシュボード設定'),
            subtitle: const Text('表示するメニューのON/OFFと順序を管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DashboardMenuSettingsScreen()),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.palette, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('テーマ設定', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(value: 'system', label: Text('システム'), icon: Icon(Icons.settings)),
                    ButtonSegment<String>(value: 'light', label: Text('ライト'), icon: Icon(Icons.light_mode)),
                    ButtonSegment<String>(value: 'dark', label: Text('ダーク'), icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {_theme},
                  onSelectionChanged: (s) async {
                    await _repo.setTheme(s.first);
                    setState(() => _theme = s.first);
                  },
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(value: 'white', label: Text('白'), icon: Icon(Icons.palette)),
                    ButtonSegment<String>(value: 'gray', label: Text('グレー'), icon: Icon(Icons.color_lens)),
                  ],
                  selected: {_summaryTheme},
                  onSelectionChanged: (s) async {
                    await _repo.setSummaryTheme(s.first);
                    setState(() => _summaryTheme = s.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('ステータス設定', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _statusTextController,
                  decoration: const InputDecoration(
                    labelText: 'ステータステキスト（例：営業中、休業中、工事中）',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) async {
                    await _repo.setDashboardStatusText(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mail, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('E-mail', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('設定'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmailSettingsScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storage, color: Colors.brown),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('マスター管理', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('会社情報'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompanyInfoScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('顧客マスター'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerMasterScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('商品マスター'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductMasterScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.category, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('マスター管理（統合）', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('M1:マスター管理'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MasterHubPage())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}