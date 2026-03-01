import 'dart:io';
import 'package:flutter/material.dart';
import '../services/app_settings_repository.dart';
import 'invoice_history_screen.dart';
import 'invoice_input_screen.dart';
import 'invoice_detail_page.dart';
import 'customer_master_screen.dart';
import 'product_master_screen.dart';
import 'settings_screen.dart';
import 'master_hub_page.dart';
import '../models/invoice_models.dart';
import '../services/location_service.dart';
import '../services/customer_repository.dart';
import '../widgets/slide_to_unlock.dart';
import '../config/app_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = AppSettingsRepository();
  bool _loading = true;
  bool _statusEnabled = true;
  String _statusText = '工事中';
  List<DashboardMenuItem> _menu = [];
  bool _historyUnlocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final statusEnabled = await _repo.getDashboardStatusEnabled();
    final statusText = await _repo.getDashboardStatusText();
    final rawMenu = await _repo.getDashboardMenu();
    final enabledRoutes = AppConfig.enabledRoutes;
    final menu = rawMenu.where((m) => enabledRoutes.contains(m.route)).toList();
    final unlocked = await _repo.getDashboardHistoryUnlocked();
    setState(() {
      _statusEnabled = statusEnabled;
      _statusText = statusText;
      _menu = menu;
      _loading = false;
      _historyUnlocked = unlocked;
    });
  }

  void _navigate(DashboardMenuItem item) async {
    Widget? target;
    final enabledRoutes = AppConfig.enabledRoutes;
    if (!enabledRoutes.contains(item.route)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('この機能は現在ご利用いただけません')));
      return;
    }
    switch (item.route) {
      case 'invoice_history':
        if (!_historyUnlocked) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ロックを解除してください')));
          return;
        }
        target = const InvoiceHistoryScreen(initialUnlocked: true);
        break;
      case 'invoice_input':
        target = InvoiceInputForm(
          onInvoiceGenerated: (invoice, path) async {
            final locationService = LocationService();
            final pos = await locationService.getCurrentLocation();
            if (pos != null) {
              final customerRepo = CustomerRepository();
              await customerRepo.addGpsHistory(invoice.customer.id, pos.latitude, pos.longitude);
            }
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoice: invoice)),
            );
          },
          initialDocumentType: DocumentType.invoice,
        );
        break;
      case 'customer_master':
        target = const CustomerMasterScreen();
        break;
      case 'product_master':
        target = const ProductMasterScreen();
        break;
      case 'master_hub':
        target = const MasterHubPage();
        break;
      case 'settings':
        target = const SettingsScreen();
        break;
      default:
        target = const InvoiceHistoryScreen();
        break;
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => target!));
    if (item.route == 'settings') {
      await _load();
    }
  }

  Widget _tile(DashboardMenuItem item) {
    return GestureDetector(
      onTap: () => _navigate(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _leading(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(_routeLabel(item.route), style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _leading(DashboardMenuItem item) {
    if (item.customIconPath != null && File(item.customIconPath!).existsSync()) {
      return CircleAvatar(backgroundImage: FileImage(File(item.customIconPath!)), radius: 22);
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.indigo.shade50,
      foregroundColor: Colors.indigo.shade700,
      child: Icon(_iconForName(item.iconName ?? 'list_alt')),
    );
  }

  IconData _iconForName(String name) {
    return kIconsMap[name] ?? Icons.apps;
  }

  String _routeLabel(String route) {
    switch (route) {
      case 'invoice_history':
        return 'A2:伝票一覧';
      case 'invoice_input':
        return 'A1:伝票入力';
      case 'customer_master':
        return 'C1:顧客マスター';
      case 'product_master':
        return 'P1:商品マスター';
      case 'master_hub':
        return 'M1:マスター管理';
      case 'settings':
        return 'S1:設定';
      default:
        return route;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('D1:ダッシュボード'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              await _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _historyUnlocked
                        ? Row(
                            children: [
                              const Icon(Icons.lock_open, color: Colors.green),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('A2ロック解除済')),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  setState(() => _historyUnlocked = false);
                                  await _repo.setDashboardHistoryUnlocked(false);
                                },
                                icon: const Icon(Icons.lock),
                                label: const Text('再ロック'),
                              ),
                            ],
                          )
                        : SlideToUnlock(
                            isLocked: !_historyUnlocked,
                            onUnlocked: () async {
                              setState(() => _historyUnlocked = true);
                              await _repo.setDashboardHistoryUnlocked(true);
                            },
                            text: 'スライドでロック解除 (A2)',
                          ),
                  ),
                  if (_statusEnabled)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_statusText, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ..._menu.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _tile(e),
                      )),
                  if (_menu.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('メニューが未設定です。設定画面から追加してください。'),
                      ),
                    )
                ],
              ),
            ),
    );
  }
}

// fallback icon map for dashboard
const Map<String, IconData> kIconsMap = {
  'list_alt': Icons.list_alt,
  'edit_note': Icons.edit_note,
  'history': Icons.history,
  'settings': Icons.settings,
  'invoice': Icons.receipt_long,
  'customer': Icons.people,
  'product': Icons.inventory_2,
  'menu': Icons.menu,
  'analytics': Icons.analytics,
  'map': Icons.map,
  'master': Icons.storage,
  'qr': Icons.qr_code,
  'camera': Icons.camera_alt,
  'contact': Icons.contact_mail,
};
