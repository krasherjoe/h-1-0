import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../models/customer_model.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import '../services/pdf_generator.dart';
import 'invoice_detail_page.dart';
import 'management_screen.dart';
import 'product_master_screen.dart';
import 'customer_master_screen.dart';
import 'invoice_input_screen.dart';
import 'settings_screen.dart';
import 'company_info_screen.dart';
import '../widgets/slide_to_unlock.dart';
import '../main.dart'; // InvoiceFlowScreen 用
import 'package:package_info_plus/package_info_plus.dart';
import 'package:printing/printing.dart';
import '../widgets/invoice_pdf_preview_page.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({Key? key}) : super(key: key);

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  bool _isLoading = true;
  bool _isUnlocked = false; // 保護解除フラグ
  String _searchQuery = "";
  String _sortBy = "date"; // "date", "amount", "customer"
  DateTime? _startDate;
  DateTime? _endDate;
  String _appVersion = "1.0.0";

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadVersion();
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
                            isUnlocked: _isUnlocked, // 状態を渡す
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
      drawer: _isUnlocked
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(color: Colors.indigo.shade700),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text("メニュー", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text("v$_appVersion", style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: const Text("伝票マスター"),
                    onTap: () {
                      Navigator.pop(context);
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
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text("設定"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),
                  const Divider(),
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
            )
          : null,
      appBar: AppBar(
        // leading removed
        title: GestureDetector(
          onLongPress: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CompanyInfoScreen()),
            ).then((_) => _loadData());
          },
          child: Text("伝票マスター v$_appVersion"),
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
            icon: const Icon(Icons.sort),
            onPressed: () {
              showMenu<String>(
                context: context,
                position: const RelativeRect.fromLTRB(100, 80, 0, 0),
                items: [
                  const PopupMenuItem(value: "date", child: Text("日付順")),
                  const PopupMenuItem(value: "amount", child: Text("金額順")),
                  const PopupMenuItem(value: "customer", child: Text("顧客名順")),
                ],
              ).then((val) {
                if (val != null) {
                  setState(() => _sortBy = val);
                  _applyFilterAndSort();
                }
              });
            },
            tooltip: "ソート切り替え",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "検索 (顧客名、伝票番号...)",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                isDense: true,
              ),
              onChanged: (val) {
                _searchQuery = val;
                _applyFilterAndSort();
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SlideToUnlock(
                isLocked: !_isUnlocked,
                onUnlocked: _toggleUnlock,
                text: "スライドでロック解除",
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredInvoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(_searchQuery.isEmpty ? "保存された伝票がありません" : "該当する伝票が見つかりません"),
                          ],
                        ),
                      )
                    : ListView.builder(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: 120), // 固定: FAB+安全余白
                        itemCount: _filteredInvoices.length,
                        itemBuilder: (context, index) {
                          final invoice = _filteredInvoices[index];
                          return ListTile(
                            tileColor: invoice.isDraft ? Colors.orange.shade50 : null, // 下書きは背景色を変更
                            leading: CircleAvatar(
                              backgroundColor: invoice.isDraft 
                                  ? Colors.orange.shade100 
                                  : (_isUnlocked ? Colors.indigo.shade100 : Colors.grey.shade200),
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.center,
                                    child: Icon(
                                      invoice.isDraft ? Icons.edit_note : Icons.description_outlined,
                                      color: invoice.isDraft 
                                          ? Colors.orange 
                                          : (_isUnlocked ? Colors.indigo : Colors.grey),
                                    ),
                                  ),
                                  if (invoice.isLocked)
                                    const Align(alignment: Alignment.bottomRight, child: Icon(Icons.lock, size: 14, color: Colors.redAccent)),
                                ],
                              ),
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(invoice.customerNameForDisplay, style: TextStyle(fontWeight: FontWeight.bold, color: invoice.isLocked ? Colors.grey : Colors.black87)),
                                if (invoice.subject?.isNotEmpty ?? false)
                                  Text(
                                    invoice.subject!,
                                    style: TextStyle(fontSize: 13, color: Colors.indigo.shade700, fontWeight: FontWeight.normal),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                            subtitle: Text("${dateFormatter.format(invoice.date)} - ${invoice.invoiceNumber}"),
                            trailing: SizedBox(
                              height: 60,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("￥${amountFormatter.format(invoice.totalAmount)}", 
                                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  if (invoice.isSynced)
                                    const Icon(Icons.sync, size: 14, color: Colors.green)
                                  else
                                    const Icon(Icons.sync_disabled, size: 14, color: Colors.orange),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(width: 32, height: 26),
                                    icon: const Icon(Icons.edit, size: 18),
                                    tooltip: invoice.isLocked ? "ロック中" : (_isUnlocked ? "編集" : "アンロックして編集"),
                                    onPressed: (invoice.isLocked || !_isUnlocked)
                                        ? null
                                        : () async {
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
                                ],
                              ),
                            ),
                            onTap: _isUnlocked
                                ? () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => InvoiceDetailPage(
                                          invoice: invoice,
                                          isUnlocked: _isUnlocked, // 状態を渡す
                                        ),
                                      ),
                                    );
                                    _loadData();
                                  }
                                : () => _requireUnlock(),
                            onLongPress: _isUnlocked ? () => _showInvoiceActions(invoice) : () => _requireUnlock(),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUnlocked
            ? () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InvoiceFlowScreen(onComplete: _loadData),
                  ),
                );
                _loadData();
              }
            : _requireUnlock,
        label: const Text("新規伝票作成"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }
}
