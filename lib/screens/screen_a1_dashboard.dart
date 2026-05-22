import 'dart:io';
import 'package:flutter/material.dart';
import '../services/app_settings_repository.dart';
import '../services/database_helper.dart';
import '../services/project_repository.dart';
import '../config/app_config.dart';
import '../constants/dashboard_icons.dart';
import '../models/dashboard_menu_item.dart';
import '../models/invoice_models.dart';
import '../models/project_model.dart';
import '../widgets/menu_category_header.dart';
import '../widgets/slide_to_unlock.dart';
import '../constants/menu_catalog.dart';
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
import 'purchase_input_screen.dart';
import 'purchase_return_input_screen.dart';
import 'inventory_management_screen.dart';
import 'payment_schedule_screen.dart';
import 'payment_register_screen.dart';
import 'cash_flow_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'business_profile_lite_screen.dart';
import 'inventory_location_screen.dart';
import 'inventory_movement_screen.dart';
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
import 'delivery_list_screen.dart';
import 'purchase_order_screen.dart';
import 'purchase_payment_screen.dart';
import 'screen_pj1_project_list.dart';
import 'screen_pj2_project_detail.dart';
import '../services/location_service.dart';
import '../services/customer_repository.dart';

class ScreenA1Dashboard extends StatefulWidget {
  const ScreenA1Dashboard({super.key});

  @override
  State<ScreenA1Dashboard> createState() => _ScreenA1DashboardState();
}

class _ScreenA1DashboardState extends State<ScreenA1Dashboard> {
  final _repo = AppSettingsRepository();
  final _dbHelper = DatabaseHelper();
  final _projectRepo = ProjectRepository();

  bool _loading = true;
  List<DashboardMenuItem> _menu = [];
  bool _historyUnlocked = false;
  bool _showCategoryDescriptions = true;
  final Set<String> _collapsedCategories = <String>{};

  // サマリー
  int _todayInvoiceCount = 0;
  int _todayInvoiceAmount = 0;
  int _unpaidTotal = 0;
  int _activeProjectCount = 0;

  // 最近の伝票・案件
  List<Map<String, dynamic>> _recentInvoices = [];
  List<Project> _activeProjects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rawMenu = await _repo.getDashboardMenu();
    final isDebug = AppConfig.enableDebugFeatures;
    final normalizedMenu = isDebug ? rawMenu.map((e) => e.copyWith(enabled: true)).toList() : rawMenu;
    final visibleMenu = isDebug ? normalizedMenu : normalizedMenu.where((item) => item.enabled).toList();
    final unlocked = await _repo.getDashboardHistoryUnlocked();
    final showCategoryDesc = await _repo.getDashboardShowCategoryDescriptions();

    // サマリー取得
    await _loadSummary();
    // 最近の伝票・案件
    await _loadRecent();

    if (!mounted) return;
    setState(() {
      _menu = visibleMenu;
      _loading = false;
      _historyUnlocked = unlocked;
      _showCategoryDescriptions = showCategoryDesc;
    });
  }

  Future<void> _loadSummary() async {
    try {
      final db = await _dbHelper.database;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // 本日の請求書件数・金額
      final todayRows = await db.rawQuery('''
        SELECT COUNT(*) as cnt, COALESCE(SUM(total_amount), 0) as amt
        FROM invoices
        WHERE date LIKE ? AND is_draft = 0
      ''', ['$todayStr%']);
      _todayInvoiceCount = (todayRows.first['cnt'] as num?)?.toInt() ?? 0;
      _todayInvoiceAmount = (todayRows.first['amt'] as num?)?.toInt() ?? 0;

      // 未回収金額（payment_status != 'paid'）
      final unpaidRows = await db.rawQuery('''
        SELECT COALESCE(SUM(total_amount - received_amount), 0) as amt
        FROM invoices
        WHERE payment_status != 'paid' AND is_draft = 0
      ''');
      _unpaidTotal = (unpaidRows.first['amt'] as num?)?.toInt() ?? 0;

      // 進行中案件数
      final projectRows = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM projects WHERE status = 'active'
      ''');
      _activeProjectCount = (projectRows.first['cnt'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[A1] サマリー取得エラー: $e');
    }
  }

  Future<void> _loadRecent() async {
    try {
      final db = await _dbHelper.database;

      // 最近の伝票5件
      final invRows = await db.rawQuery('''
        SELECT id, date, subject, total_amount, document_type, payment_status, customer_id
        FROM invoices
        WHERE is_draft = 0
        ORDER BY date DESC, updated_at DESC
        LIMIT 5
      ''');
      _recentInvoices = invRows;

      // 進行中案件5件（更新日時順）
      _activeProjects = await _projectRepo.getAllProjects();
      _activeProjects = _activeProjects
          .where((p) => p.status == ProjectStatus.active)
          .toList();
      _activeProjects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (_activeProjects.length > 5) {
        _activeProjects = _activeProjects.sublist(0, 5);
      }
    } catch (e) {
      debugPrint('[A1] 最近のデータ取得エラー: $e');
    }
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

  void _navigate(DashboardMenuItem item) async {
    final target = _buildTargetScreen(item);
    if (target == null) return;
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
            Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoice: invoice)));
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
      case 'purchase_order_input':
        return const PurchaseOrderListScreen();
      case 'purchase_return_input':
        return const PurchaseReturnInputScreen();
      case 'purchase_entries':
        return const PurchaseInputScreen();
      case 'purchase_receipts':
        return const PurchasePaymentListScreen();
      case 'warehouse_master':
        return const WarehouseMasterScreen();
      case 'staff_master':
        return const StaffMasterScreen();
      case 'master_hub':
        return const MasterHubPage();
      case 'project_list':
        return const ProjectListScreen();
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
      case 'delivery_list':
        return const DeliveryListScreen();
      case 'inventory_list':
      case 'inventory_lookup':
        return const InventoryManagementScreen();
      case 'payment_schedule':
        return const PaymentScheduleScreen();
      case 'payment_register':
        return const PaymentRegisterScreen();
      case 'cash_flow':
        return const CashFlowScreen();
      case 'analytics_dashboard':
      case 'analytics_report':
      case 'sales_analysis':
        return const AnalyticsDashboardScreen();
      case 'business_profile':
        return const BusinessProfileScreen();
      case 'inventory_location':
        return const InventoryLocationScreen();
      case 'inventory_movement':
        return const InventoryMovementScreen();
      default:
        return MenuPlaceholderScreen(item: item);
    }
  }

  Widget _tile(DashboardMenuItem item) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _navigate(item),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: theme.dividerColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
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
                  Text(_subtitle(item), style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                  if (_showCategoryDescriptions && item.description != null) ...[
                    const SizedBox(height: 4),
                    Text(item.description!, style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12)),
                  ]
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.iconTheme.color),
          ],
        ),
      ),
    );
  }

  Widget _leading(DashboardMenuItem item) {
    final theme = Theme.of(context);
    if (item.customIconPath != null && File(item.customIconPath!).existsSync()) {
      return CircleAvatar(backgroundImage: FileImage(File(item.customIconPath!)), radius: 22);
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.primary,
      child: Icon(_iconForName(item.iconName ?? 'list_alt')),
    );
  }

  IconData _iconForName(String name) => kDashboardIcons[name] ?? Icons.apps;

  String _subtitle(DashboardMenuItem item) {
    final screenId = item.id.toUpperCase();
    return '$screenId \u2022 ${item.route}';
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
                children: items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _tile(e))).toList(),
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

    grouped.forEach((category, items) {
      if (processed.contains(category)) return;
      widgets.add(buildSection(category, items));
    });

    return widgets;
  }

  // ===== A1 サマリー・クイックアクション =====

  Widget _buildSummaryCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _SummaryCard(
            icon: Icons.receipt,
            label: '本日請求',
            value: '${_todayInvoiceCount}件',
            sub: '\u00a5${_formatAmount(_todayInvoiceAmount)}',
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            icon: Icons.warning_amber,
            label: '未回収金額',
            value: '\u00a5${_formatAmount(_unpaidTotal)}',
            sub: '入金待ち',
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            icon: Icons.folder_open,
            label: '進行中案件',
            value: '${_activeProjectCount}件',
            sub: 'PJ1連携',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectListScreen())),
          ),
        ],
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 10000) {
      final man = amount / 10000;
      return '${man.toStringAsFixed(1)}万';
    }
    return amount.toString();
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('クイックアクション', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              _QuickActionButton(
                icon: Icons.add_circle,
                label: '新規請求',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceInputForm(
                      onInvoiceGenerated: (invoice, path) async {
                        final locationService = LocationService();
                        final pos = await locationService.getCurrentLocation();
                        if (pos != null) {
                          final customerRepo = CustomerRepository();
                          await customerRepo.addGpsHistory(invoice.customer.id, pos.latitude, pos.longitude);
                        }
                        if (!mounted) return;
                        Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoice: invoice)));
                      },
                      initialDocumentType: DocumentType.invoice,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _QuickActionButton(
                icon: Icons.description,
                label: '新規見積',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceInputForm(
                      onInvoiceGenerated: (invoice, path) {
                        if (!mounted) return;
                        Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoice: invoice)));
                      },
                      initialDocumentType: DocumentType.estimation,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _QuickActionButton(
                icon: Icons.assignment,
                label: '案件管理',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectListScreen())),
              ),
              const SizedBox(width: 8),
              _QuickActionButton(
                icon: Icons.history,
                label: '請求履歴',
                onTap: () {
                  if (!_historyUnlocked) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ロックを解除してください')));
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen(initialUnlocked: true)));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentInvoices() {
    if (_recentInvoices.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('最近の伝票', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              TextButton(
                onPressed: () {
                  if (!_historyUnlocked) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ロックを解除してください')));
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen(initialUnlocked: true)));
                },
                child: const Text('すべて'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ..._recentInvoices.map((row) {
            final docType = row['document_type'] as String? ?? 'invoice';
            final typeLabel = docType == 'estimation' ? '見積' : docType == 'sales' ? '売上' : '請求';
            final cs = Theme.of(context).colorScheme;
            final typeColor = docType == 'estimation' ? cs.secondary : docType == 'sales' ? cs.primary : cs.tertiary;
            final dateStr = (row['date'] as String? ?? '').substring(0, 10);
            final subject = row['subject'] as String? ?? '(件名なし)';
            final amount = row['total_amount'] as num? ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: typeColor.withValues(alpha: 0.1),
                  foregroundColor: typeColor,
                  child: Text(typeLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                title: Text(subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('$dateStr \u00a5${amount.toString()}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // 詳細表示は InvoiceDetailPage にInvoiceオブジェクトが必要なので、
                  // 簡易的に履歴画面へ遷移
                  if (!_historyUnlocked) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ロックを解除してください')));
                    return;
                  }
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen(initialUnlocked: true)));
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildActiveProjects() {
    if (_activeProjects.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('進行中の案件', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectListScreen())),
                child: const Text('PJ1で開く'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ..._activeProjects.map((project) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.assignment, size: 18),
                ),
                title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(project.customerName ?? '得意先未設定'),
                trailing: Text('\u00a5${project.totalAmount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: project)),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('A1:ダッシュボード'),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // ロック解除
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _historyUnlocked
                        ? Row(
                            children: [
                              Icon(Icons.lock_open, color: Theme.of(context).colorScheme.primary),
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
                  // サマリー
                  _buildSummaryCards(),
                  const Divider(),
                  // クイックアクション
                  _buildQuickActions(),
                  const Divider(),
                  // 最近の伝票
                  _buildRecentInvoices(),
                  // PJ1連携：進行中案件
                  _buildActiveProjects(),
                  const Divider(),
                  // メニュー
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

// ===== サマリーカード =====
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary, size: 28),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: cs.primary.withValues(alpha: 0.9), fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: cs.primary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(color: cs.primary.withValues(alpha: 0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ===== クイックアクションボタン =====
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: cs.primary, size: 28),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
