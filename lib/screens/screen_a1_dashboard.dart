import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/app_settings_repository.dart';
import '../services/database_helper.dart';
import '../services/invoice_repository.dart';
import '../services/project_repository.dart';
import '../config/app_config.dart';
import '../constants/dashboard_icons.dart';
import '../models/dashboard_menu_item.dart';
import '../models/invoice_models.dart';
import '../models/payment_schedule_model.dart' show PaymentStatus;
import '../models/project_model.dart';
import '../widgets/menu_category_header.dart';
import '../widgets/slide_to_unlock.dart';
import '../constants/menu_catalog.dart';
import '../utils/theme_utils.dart';
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
  final _invoiceRepo = InvoiceRepository();
  final _customerRepo = CustomerRepository();

  bool _loading = true;
  List<DashboardMenuItem> _menu = [];
  bool _historyUnlocked = false;
  bool _showCategoryDescriptions = true;
  bool _recentCollapsed = false;
  bool _projectsCollapsed = false;
  final Set<String> _collapsedCategories = <String>{};

  // サマリー
  int _todayInvoiceCount = 0;
  int _todayInvoiceAmount = 0;
  int _unpaidTotal = 0;
  int _activeProjectCount = 0;

  // 最近の伝票・案件
  List<Invoice> _recentInvoices = [];
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
      final customers = await _customerRepo.getAllCustomers();
      final allInvoices = await _invoiceRepo.getAllInvoices(customers);
      allInvoices.sort((a, b) => b.date.compareTo(a.date));
      _recentInvoices = allInvoices.where((i) => !i.isDraft).take(5).toList();

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
          boxShadow: [BoxShadow(color: theme.dividerColor.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
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
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _SummaryCard(
            icon: Icons.receipt,
            label: '本日請求',
            value: '$_todayInvoiceCount件',
            sub: '\u00a5${_formatAmount(_todayInvoiceAmount)}',
            accentColor: cs.primary,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            icon: Icons.warning_amber,
            label: '未回収金額',
            value: '\u00a5${_formatAmount(_unpaidTotal)}',
            sub: '入金待ち',
            accentColor: cs.error,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            icon: Icons.folder_open,
            label: '進行中案件',
            value: '$_activeProjectCount件',
            sub: 'PJ1連携',
            accentColor: cs.tertiary,
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
                accentColor: documentTypeBadgeColor(DocumentType.invoice),
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
                accentColor: documentTypeBadgeColor(DocumentType.estimation),
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
                accentColor: documentTypeBadgeColor(DocumentType.order),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectListScreen())),
              ),
              const SizedBox(width: 8),
              _QuickActionButton(
                icon: Icons.history,
                label: '請求履歴',
                accentColor: documentTypeBadgeColor(DocumentType.receipt),
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MenuCategoryHeader(
            title: '最近の伝票',
            description: null,
            showDescription: false,
            collapsible: true,
            collapsed: _recentCollapsed,
            onToggle: () => setState(() => _recentCollapsed = !_recentCollapsed),
          ),
          AnimatedCrossFade(
            firstChild: Column(
              children: _recentInvoices.map((inv) {
                final typeLabel = inv.documentType == DocumentType.estimation
                    ? '見積'
                    : inv.documentType == DocumentType.order
                        ? '受注'
                        : inv.documentType == DocumentType.delivery
                            ? '納品'
                            : inv.documentType == DocumentType.receipt
                                ? '領収'
                                : '請求';
                final typeColor = documentTypeBadgeColor(inv.documentType);
                final subject = inv.subject ?? '(件名なし)';
                final customerName = inv.customer.displayName;
                final statusIcon = inv.paymentStatus == PaymentStatus.paid
                    ? Icons.check_circle
                    : inv.documentType == DocumentType.invoice &&
                            inv.paymentStatus == PaymentStatus.partial
                        ? Icons.money_off
                        : Icons.circle_outlined;
                final statusColor = inv.paymentStatus == PaymentStatus.paid
                    ? Colors.green
                    : inv.documentType == DocumentType.invoice
                        ? cs.error
                        : Colors.grey;
                return GestureDetector(
                  onTap: () {
                    if (!_historyUnlocked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ロックを解除してください')));
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => InvoiceDetailPage(invoice: inv)),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(typeLabel,
                                style: TextStyle(
                                    color: typeColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(customerName,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: cs.onSurfaceVariant)),
                                  const SizedBox(width: 8),
                                  Text(
                                      '${inv.date.year}/${inv.date.month.toString().padLeft(2, '0')}/${inv.date.day.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: cs.onSurfaceVariant
                                              .withValues(alpha: 0.6))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('\u00a5${_formatAmount(inv.totalAmount)}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface)),
                        const SizedBox(width: 4),
                        Icon(statusIcon,
                            size: 14, color: statusColor.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _recentCollapsed
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveProjects() {
    if (_activeProjects.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MenuCategoryHeader(
            title: '進行中の案件',
            description: null,
            showDescription: false,
            collapsible: true,
            collapsed: _projectsCollapsed,
            onToggle: () => setState(() => _projectsCollapsed = !_projectsCollapsed),
          ),
          AnimatedCrossFade(
            firstChild: Column(
              children: _activeProjects.map((project) {
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: project)),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.assignment, size: 18, color: cs.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(project.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text(project.customerName ?? '得意先未設定',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('\u00a5${project.totalAmount}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _projectsCollapsed
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
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

// ===== サマリーカード（ガラス調） =====
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color accentColor;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark
              ? accentColor.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.5),
          border: Border.all(
            color: isDark
                ? accentColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.08 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.04 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(height: 12),
                Text(label,
                    style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : accentColor.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: isDark ? Colors.white : accentColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 1),
                Text(sub,
                    style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : accentColor.withValues(alpha: 0.6),
                        fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== クイックアクション（ガラス調） =====
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark
                ? accentColor.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.5),
            border: Border.all(
              color: isDark
                  ? accentColor.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.06 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Column(
                children: [
                  Icon(icon, color: accentColor, size: 26),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
