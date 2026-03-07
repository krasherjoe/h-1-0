import 'dart:io';
import 'package:flutter/material.dart';
import '../services/app_settings_repository.dart';
import '../config/app_config.dart';
import '../constants/dashboard_icons.dart';
import '../models/dashboard_menu_item.dart';
import '../widgets/menu_category_header.dart';
import 'invoice_history_screen.dart';
import 'invoice_input_screen.dart';
import 'invoice_detail_page.dart';
import 'customer_master_screen.dart';
import 'product_master_screen.dart';
import 'supplier_master_screen.dart';
import 'order_input_screen.dart';
import 'quotation_input_screen.dart';
import 'sales_entry_screen.dart';
import 'sales_return_input_screen.dart';
import 'warehouse_master_screen.dart';
import 'staff_master_screen.dart';
import 'settings_screen.dart';
import 'master_hub_page.dart';
import 'menu_placeholder_screen.dart';
import 'stocktake_input_screen.dart';
import 'stock_transfer_screen.dart';
import 'invoice_issue_screen.dart';
import 'support_desk_screen.dart';
import 'warehouse_dashboard_screen.dart';
import 'staff_management_screen.dart';
import '../models/invoice_models.dart';
import '../services/location_service.dart';
import '../services/customer_repository.dart';
import '../widgets/slide_to_unlock.dart';
import '../constants/menu_catalog.dart';

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
  bool _showCategoryDescriptions = true;
  final Set<String> _collapsedCategories = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_collapsedCategories.contains(category)) {
        _collapsedCategories.remove(category);
      } else {
        _collapsedCategories.add(category);
      }
    });
  }

  bool _isCategoryCollapsed(String category) => _collapsedCategories.contains(category);

  Future<void> _load() async {
    final statusEnabled = await _repo.getDashboardStatusEnabled();
    final statusText = await _repo.getDashboardStatusText();
    final rawMenu = await _repo.getDashboardMenu();
    final isDebug = AppConfig.enableDebugFeatures;
    final normalizedMenu = isDebug ? rawMenu.map((e) => e.copyWith(enabled: true)).toList() : rawMenu;
    final visibleMenu = isDebug ? normalizedMenu : normalizedMenu.where((item) => item.enabled).toList();
    final unlocked = await _repo.getDashboardHistoryUnlocked();
    final showCategoryDesc = await _repo.getDashboardShowCategoryDescriptions();
    setState(() {
      _statusEnabled = statusEnabled;
      _statusText = statusText;
      _menu = visibleMenu;
      _loading = false;
      _historyUnlocked = unlocked;
      _showCategoryDescriptions = showCategoryDesc;
    });
  }

  void _navigate(DashboardMenuItem item) async {
    final target = _buildTargetScreen(item);
    if (target == null) {
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => target));
    if (item.route == 'settings') {
      await _load();
    }
  }

  Widget? _buildTargetScreen(DashboardMenuItem item) {
    switch (item.route) {
      case 'invoice_history':
        if (!_historyUnlocked) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ロックを解除してください')));
          return null;
        }
        return const InvoiceHistoryScreen(initialUnlocked: true);
      case 'invoice_input':
        return InvoiceInputForm(
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
      case 'invoice_issue':
        return const InvoiceIssueScreen();
      case 'customer_master':
        return const CustomerMasterScreen();
      case 'product_master':
        return const ProductMasterScreen();
      case 'supplier_master':
        return const SupplierMasterScreen();
      case 'order_input':
        return const OrderInputScreen();
      case 'quotation_input':
        return const QuotationInputScreen();
      case 'sales_entry':
        return const SalesEntryScreen();
      case 'sales_return_input':
        return const SalesReturnInputScreen();
      case 'warehouse_master':
        return const WarehouseMasterScreen();
      case 'staff_master':
        return const StaffMasterScreen();
      case 'master_hub':
        return const MasterHubPage();
      case 'settings':
        return const SettingsScreen();
      case 'stocktake_input':
        return const StocktakeInputScreen();
      case 'stock_transfer':
        return const StockTransferScreen();
      case 'support_desk':
        return const SupportDeskScreen();
      case 'warehouse_dashboard':
        return const WarehouseDashboardScreen();
      case 'staff_management':
        return const StaffManagementScreen();
      default:
        return MenuPlaceholderScreen(item: item);
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
                  Text(_subtitle(item), style: const TextStyle(color: Colors.grey)),
                  if (_showCategoryDescriptions && item.description != null) ...[
                    const SizedBox(height: 4),
                    Text(item.description!, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ]
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
    return kDashboardIcons[name] ?? Icons.apps;
  }

  String _subtitle(DashboardMenuItem item) {
    final screenId = item.id.toUpperCase();
    return '$screenId • ${item.route}';
  }

  List<Widget> _buildMenuSections() {
    if (_menu.isEmpty) return const [];
    final grouped = <String, List<DashboardMenuItem>>{};
    for (final item in _menu) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    final widgets = <Widget>[];
    final processed = <String>{};

    Widget buildSection(String category, List<DashboardMenuItem> items) {
      final description = kMenuCategoryDescriptions[category];
      final collapsed = _isCategoryCollapsed(category);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MenuCategoryHeader(
              title: category,
              description: description,
              showDescription: _showCategoryDescriptions,
              collapsible: true,
              collapsed: collapsed,
              onToggle: () => _toggleCategory(category),
            ),
            AnimatedCrossFade(
              firstChild: Column(
                children: items
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _tile(e),
                        ))
                    .toList(),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: collapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      );
    }

    for (final category in kMenuCategoryOrder) {
      final items = grouped[category];
      if (items == null || items.isEmpty) continue;
      widgets.add(buildSection(category, items));
      processed.add(category);
    }

    // add any categories not listed in kMenuCategoryOrder
    grouped.forEach((category, items) {
      if (processed.contains(category)) return;
      widgets.add(buildSection(category, items));
    });

    return widgets;
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
                              const Expanded(child: Text('A2 ロック解除済')),
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
                            lockedText: 'スライドでロック解除 (A2)',
                            unlockedText: 'A2 解除済',
                            onUnlocked: () async {
                              setState(() => _historyUnlocked = true);
                              await _repo.setDashboardHistoryUnlocked(true);
                            },
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
                  ..._buildMenuSections(),
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