import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import 'invoice_detail_page.dart';
import 'management_screen.dart';
import 'product_master_screen.dart';
import 'customer_master_screen.dart';
import 'invoice_input_screen.dart';
import 'settings_screen.dart';
import 'company_info_screen.dart';
import 'screen_a1_dashboard.dart';
import 'screen_pj1_project_list.dart';
import '../services/app_settings_repository.dart';
import '../widgets/swipe_to_unlock.dart';
// InvoiceFlowScreen import removed; using inline type picker
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/invoice_pdf_preview_page.dart';
import 'invoice_history/invoice_history_list.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  final bool initialUnlocked;
  const InvoiceHistoryScreen({super.key, this.initialUnlocked = false});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final AppSettingsRepository _settingsRepo = AppSettingsRepository();
  late final StreamSubscription<String> _homeModeSub;
  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  bool _isLoading = true;
  bool _isUnlocked = false; // 保護解除フラグ
  String _searchQuery = "";
  String _sortBy = "date"; // "date", "amount", "customer"
  DateTime? _startDate;
  DateTime? _endDate;
  String _appVersion = "1.0.0";
  bool _useDashboardHome = false;
  bool _showInvoiceNumber = true;

  @override
  void initState() {
    super.initState();
    _isUnlocked = widget.initialUnlocked;
    _loadData();
    _loadVersion();
    _loadHomeMode();
    _loadInvoiceNumberSetting();
    _homeModeSub = _settingsRepo.watchHomeMode().listen((mode) {
      if (!mounted) return;
      setState(() {
        _useDashboardHome = mode == 'dashboard';
        if (_useDashboardHome && widget.initialUnlocked) {
          _isUnlocked = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _homeModeSub.cancel();
    super.dispose();
  }

  Future<void> _loadInvoiceNumberSetting() async {
    final v = await _settingsRepo.getShowHistoryInvoiceNumber();
    if (!mounted) return;
    setState(() => _showInvoiceNumber = v);
  }

  Future<void> _loadHomeMode() async {
    final mode = await _settingsRepo.getHomeMode();
    if (!mounted) return;
    setState(() {
      _useDashboardHome = mode == 'dashboard';
      if (_useDashboardHome && widget.initialUnlocked) {
        _isUnlocked = true;
      }
    });
  }

  Future<void> _showInvoiceActions(Invoice invoice) async {
    if (!_requireUnlock()) return;
    if (invoice.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ロック中の伝票は操作できません")));
      return;
    }
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text("PDFプレビュー"),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InvoicePdfPreviewPage(
                      invoice: invoice,
                      isUnlocked: _isUnlocked,
                      isLocked: invoice.isLocked,
                      allowFormalIssue: !invoice.isLocked,
                      onFormalIssue: () async {
                        final repo = InvoiceRepository();
                        final promoted = invoice.copyWith(isDraft: false);
                        await repo.updateInvoice(promoted);
                        _loadData();
                        return true;
                      },
                      showShare: true,
                      showEmail: true,
                      showPrint: true,
                    ),
                  ),
                );
                _loadData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("編集"),
              onTap: _isUnlocked
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InvoiceDetailPage(
                            invoice: invoice,
                          ),
                        ),
                      );
                      _loadData();
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text("削除", style: TextStyle(color: Colors.redAccent)),
              onTap: _isUnlocked
                ? () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("伝票の削除"),
                        content: Text("「${invoice.customerNameForDisplay}」の伝票(${invoice.invoiceNumber})を削除しますか？\nこの操作は取り消せません。"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("削除", style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _invoiceRepo.deleteInvoice(invoice.id);
                      _loadData();
                    }
                  }
                : null,
            ),
          ],
        ),
      ),
    );
  }

  bool _requireUnlock() {
    if (_isUnlocked) return true;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("スライドでロック解除してください")));
    return false;
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final customers = await _customerRepo.getAllCustomers();
    final invoices = await _invoiceRepo.getAllInvoices(customers);
    setState(() {
      _invoices = invoices;
      _applyFilterAndSort();
      _isLoading = false;
    });
  }

  void _applyFilterAndSort() {
    setState(() {
      _filteredInvoices = _invoices.where((inv) {
        final query = _searchQuery.toLowerCase();
        final matchesQuery = inv.customerNameForDisplay.toLowerCase().contains(query) ||
               inv.invoiceNumber.toLowerCase().contains(query) ||
               (inv.notes?.toLowerCase().contains(query) ?? false);
        
        bool matchesDate = true;
        if (_startDate != null && inv.date.isBefore(_startDate!)) matchesDate = false;
        if (_endDate != null && inv.date.isAfter(_endDate!.add(const Duration(days: 1)))) matchesDate = false;
        
        return matchesQuery && matchesDate;
      }).toList();

      if (_sortBy == "date") {
        _filteredInvoices.sort((a, b) => b.date.compareTo(a.date));
      } else if (_sortBy == "amount") {
        _filteredInvoices.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
      } else if (_sortBy == "customer") {
        _filteredInvoices.sort((a, b) => a.customerNameForDisplay.compareTo(b.customerNameForDisplay));
      }
    });
  }

  void _toggleUnlock() {
    setState(() {
      _isUnlocked = !_isUnlocked;
    });
    if (!_isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("編集プロテクトを有効にしました")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountFormatter = NumberFormat("#,###");
    final dateFormatter = DateFormat('yyyy/MM/dd');
    return Scaffold(
      resizeToAvoidBottomInset: false,
      drawer: (_useDashboardHome || !_isUnlocked)
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: const BoxDecoration(color: Colors.indigo),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("販売アシスト1号", style: TextStyle(color: Colors.white, fontSize: 20)),
                          SizedBox(height: 8),
                          Text("クイックメニュー", style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    _drawerHeading("アクション"),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline, color: Colors.indigo),
                      title: const Text("新しい伝票を作成"),
                      subtitle: const Text("ドキュメント種別を選択"),
                      onTap: () {
                        Navigator.pop(context);
                        _showCreateTypeMenu();
                      },
                    ),
                    _drawerHeading("マスター"),
                    ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: const Text("伝票マスター"),
                      onTap: () => Navigator.pop(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.folder_special, color: Colors.teal),
                      title: const Text("PJ1:案件管理"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectListScreen()));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.people),
                      title: const Text("顧客マスター"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerMasterScreen()));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.inventory_2),
                      title: const Text("商品マスター"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductMasterScreen()));
                      },
                    ),
                    _drawerHeading("システム"),
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text("設定"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))
                            .then((_) { if (mounted) _loadInvoiceNumberSetting(); });
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings),
                      title: const Text("管理メニュー"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagementScreen()));
                      },
                    ),
                  ],
                ),
              ),
            ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _useDashboardHome
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const ScreenA1Dashboard()),
                  );
                },
              )
            : (_isUnlocked
                ? Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  )
                : null),
        title: GestureDetector(
          onLongPress: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CompanyInfoScreen()),
            ).then((_) => _loadData());
          },
          child: Text("A2:履歴リスト v$_appVersion"),
        ),
        backgroundColor: _isUnlocked ? Colors.blueGrey : Colors.blueGrey.shade800,
        actions: [
          if (_isUnlocked)
            IconButton(
              icon: const Icon(Icons.lock_open, color: Colors.orangeAccent),
              onPressed: _toggleUnlock,
              tooltip: "再度プロテクトする",
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showMenu<String>(
                context: context,
                position: const RelativeRect.fromLTRB(100, 80, 0, 0),
                items: [
                  const PopupMenuItem(value: "date", child: Text("日付順")),
                  const PopupMenuItem(value: "amount", child: Text("金額順")),
                  const PopupMenuItem(value: "customer", child: Text("顧客名順")),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: "project_list", child: Text("PJ1:案件管理")),
                ],
              ).then((val) {
                if (val == null) return;
                if (val == "project_list") {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectListScreen()));
                  return;
                }
                setState(() => _sortBy = val);
                _applyFilterAndSort();
              });
            },
            tooltip: "メニュー",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final bgColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50;
              final hintColor = isDark ? Colors.grey.shade400 : Colors.black54;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.9),
                        blurRadius: 4,
                        spreadRadius: -4,
                        offset: const Offset(-1, -1),
                      ),
                    ],
                  ),
                  child: TextField(
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: "検索 (顧客名、伝票番号...)",
                      hintStyle: TextStyle(color: hintColor),
                      prefixIcon: Icon(Icons.search, color: hintColor),
                      filled: true,
                      fillColor: bgColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _applyFilterAndSort();
                    },
                  ),
                ),
              );
            }
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : InvoiceHistoryList(
                      invoices: _filteredInvoices,
                      isUnlocked: _isUnlocked,
                      amountFormatter: amountFormatter,
                      dateFormatter: dateFormatter,
                      showInvoiceNumber: _showInvoiceNumber,
                      onTap: (invoice) async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InvoiceInputForm(
                              existingInvoice: invoice,
                              onInvoiceGenerated: (inv, path) {},
                            ),
                          ),
                        );
                        _loadData();
                      },
                      onLongPress: (invoice) => _isUnlocked ? _showInvoiceActions(invoice) : _requireUnlock(),
                      onEdit: (invoice) async {
                        if (invoice.isLocked || !_isUnlocked) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InvoiceInputForm(
                              existingInvoice: invoice,
                              onInvoiceGenerated: (inv, path) {},
                            ),
                          ),
                        );
                        _loadData();
                      },
                    ),
                ),
              ],
            ),
            if (!_useDashboardHome && !_isUnlocked)
              Positioned.fill(
                child: SwipeToUnlock(
                  onUnlocked: _toggleUnlock,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUnlocked
            ? () => _showCreateTypeMenu()
            : _requireUnlock,
        label: const Text("新しい伝票"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _drawerHeading(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 0.5)),
    );
  }

  void _showCreateTypeMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'A2:伝票選択',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.blue.withValues(alpha: 0.12), child: const Icon(Icons.request_quote, color: Colors.blue)),
              title: const Text('見積書', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              onTap: () => _startNew(DocumentType.estimation),
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.teal.withValues(alpha: 0.12), child: const Icon(Icons.local_shipping, color: Colors.teal)),
              title: const Text('納品書', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              onTap: () => _startNew(DocumentType.delivery),
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.indigo.withValues(alpha: 0.12), child: const Icon(Icons.receipt_long, color: Colors.indigo)),
              title: const Text('請求書', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              onTap: () => _startNew(DocumentType.invoice),
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.green.withValues(alpha: 0.12), child: const Icon(Icons.task_alt, color: Colors.green)),
              title: const Text('領収書', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              onTap: () => _startNew(DocumentType.receipt),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNew(DocumentType type) async {
    Navigator.pop(context);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceInputForm(
          onInvoiceGenerated: (inv, path) {},
          initialDocumentType: type,
          startViewMode: false,
          showNewBadge: true,
        ),
      ),
    );
    _loadData();
  }
}
