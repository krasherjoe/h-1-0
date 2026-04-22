import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/customer_model.dart' show HonorificCode;
import '../models/invoice_models.dart';
import '../services/pdf_generator.dart';
import '../services/invoice_repository.dart';
import '../services/customer_repository.dart';
import '../widgets/invoice_pdf_preview_page.dart';
import '../widgets/zoomable_app_bar.dart';
import '../services/gps_service.dart';
import 'customer_master_screen.dart';
import 'product_master_screen.dart';
import '../models/product_model.dart';
import '../services/app_settings_repository.dart';
import '../services/company_repository.dart';
import '../services/edit_log_repository.dart';

class InvoiceInputForm extends StatefulWidget {
  final Function(Invoice invoice, String filePath) onInvoiceGenerated;
  final Invoice? existingInvoice; // 追加: 編集時の既存伝票
  final DocumentType initialDocumentType;
  final bool startViewMode;
  final bool showNewBadge;
  final bool showCopyBadge;

  const InvoiceInputForm({
    super.key,
    required this.onInvoiceGenerated,
    this.existingInvoice, // 追加
    this.initialDocumentType = DocumentType.invoice,
    this.startViewMode = true,
    this.showNewBadge = false,
    this.showCopyBadge = false,
  });

  @override
  State<InvoiceInputForm> createState() => _InvoiceInputFormState();
}

List<InvoiceItem> _cloneItems(
  List<InvoiceItem> source, {
  bool resetIds = false,
}) {
  return source
      .map(
        (e) => InvoiceItem(
          id: resetIds ? null : e.id,
          productId: e.productId,
          description: e.description,
          quantity: e.quantity,
          unitPrice: e.unitPrice,
        ),
      )
      .toList(growable: true);
}

class _InvoiceInputFormState extends State<InvoiceInputForm> {
  final _repository = InvoiceRepository();
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  Customer? _selectedCustomer;
  final List<InvoiceItem> _items = [];
  double _taxRate = 0.10;
  bool _includeTax = false;
  DocumentType _documentType = DocumentType.invoice; // 追加
  DateTime _selectedDate = DateTime.now(); // 追加: 伝票日付
  bool _isDraft = true; // デフォルトは下書き
  final TextEditingController _subjectController =
      TextEditingController(); // 追加
  final _savingNotifier = ValueNotifier<bool>(
    false,
  ); // 保存中フラグ（ValueNotifier 使用）
  String? _currentId; // 保存対象のID（コピー時に新規になる）
  Invoice? _currentInvoice; // 現在編集中の伝票
  bool _isLocked = false;
  final List<_InvoiceSnapshot> _undoStack = [];
  final List<_InvoiceSnapshot> _redoStack = [];
  // タイトルバースワイプズーム用の状態
  final _transformationController = TransformationController();
  double _titleBarStartScale = 1.0;
  double _titleBarStartX = 0.0;
  bool _panEnabled = false;
  bool _isApplyingSnapshot = false;
  bool get _canUndo => _undoStack.length > 1;
  bool get _canRedo => _redoStack.isNotEmpty;
  bool _isViewMode = true; // デフォルトでビューワ
  bool _summaryIsBlue = false; // デフォルトは白
  final AppSettingsRepository _settingsRepo = AppSettingsRepository();
  final CompanyRepository _companyRepo = CompanyRepository();
  bool _showNewBadge = false;
  bool _showCopyBadge = false;
  bool _titleBarFlash = false; // タイトルバータップエフェクト用
  final EditLogRepository _editLogRepo = EditLogRepository();
  List<EditLogEntry> _editLogs = [];
  final FocusNode _subjectFocusNode = FocusNode();
  String _lastLoggedSubject = "";

  String _documentTypeLabel(DocumentType type) {
    switch (type) {
      case DocumentType.estimation:
        return "見積書";
      case DocumentType.order:
        return "受注伝票";
      case DocumentType.delivery:
        return "納品書";
      case DocumentType.invoice:
        return "請求書";
      case DocumentType.receipt:
        return "領収書";
    }
  }

  Color _documentTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.estimation:
        return Colors.blue;
      case DocumentType.order:
        return Colors.orange;
      case DocumentType.delivery:
        return Colors.teal;
      case DocumentType.invoice:
        return Colors.indigo;
      case DocumentType.receipt:
        return Colors.green;
    }
  }

  String _customerNameWithHonorific(Customer customer) {
    final base = customer.formalName;
    final hasHonorific = RegExp(r'(様|御中|殿)$').hasMatch(base);
    return hasHonorific
        ? base
        : "$base ${HonorificCode.toName(customer.title)}";
  }

  String _ensureCurrentId() {
    _currentId ??= DateTime.now().millisecondsSinceEpoch.toString();
    return _currentId!;
  }

  void _showDocumentTypeChangeDialog() async {
    if (_isLocked || !_isDraft) return;

    final currentType = _documentType;

    // 全種類（現在のタイプを除く）
    const allTypes = [
      DocumentType.estimation,
      DocumentType.order,
      DocumentType.delivery,
      DocumentType.invoice,
      DocumentType.receipt,
    ];
    final options = allTypes.where((t) => t != currentType).toList();

    String _typeLabel(DocumentType t) {
      switch (t) {
        case DocumentType.estimation:
          return '見積書';
        case DocumentType.order:
          return '受注伝票';
        case DocumentType.delivery:
          return '納品書';
        case DocumentType.invoice:
          return '請求書';
        case DocumentType.receipt:
          return '領収書';
      }
    }

    final selected = await showModalBottomSheet<DocumentType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '現在: ${_typeLabel(currentType)}  →  変更先を選択',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            ...options.map(
              (type) => ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.indigo),
                title: Text(_typeLabel(type)),
                onTap: () => Navigator.pop(context, type),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    final newType = selected;

    setState(() {
      _documentType = newType;
    });

    // 編集ログに記録
    await _editLogRepo.addLog(
      _currentId!,
      'ドキュメントタイプを「${_documentTypeLabel(newType)}」に変更しました',
    );
  }

  void _copyAsNew() async {
    if (widget.existingInvoice == null && _currentId == null) return;

    // 複製元の編集ログに記録
    final originalId = _currentId;
    if (originalId != null) {
      await _editLogRepo.addLog(originalId, "伝票をコピーしました");
    }

    final clonedItems = _cloneItems(_items, resetIds: true);
    // 案件名に「複写」接頭辞を追加
    final originalSubject = _subjectController.text;
    final newSubject = originalSubject.isNotEmpty
        ? '[複写]$originalSubject'
        : '[複写]';

    setState(() {
      _currentId = DateTime.now().millisecondsSinceEpoch.toString();
      _isDraft = true;
      _isLocked = false;
      _selectedDate = DateTime.now();
      _items
        ..clear()
        ..addAll(clonedItems);
      _subjectController.text = newSubject;
      _isViewMode = false;
      _showCopyBadge = true;
      _showNewBadge = false;
      _pushHistory(clearRedo: true);
      _editLogs.clear();
    });

    // 複製先の編集ログに記録
    if (_currentId != null) {
      await _editLogRepo.addLog(_currentId!, "伝票をコピーして新規作成しました");
    }
  }

  @override
  void initState() {
    super.initState();
    _subjectController.addListener(_onSubjectChanged);
    _subjectFocusNode.addListener(() {
      if (!_subjectFocusNode.hasFocus) {
        final current = _subjectController.text;
        if (current != _lastLoggedSubject) {
          final id = _ensureCurrentId();
          final msg = "件名を『$current』に更新しました";
          _editLogRepo.addLog(id, msg).then((_) => _loadEditLogs());
          _lastLoggedSubject = current;
        }
      }
    });
    _subjectController.addListener(_onSubjectChanged);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _repository.cleanupOrphanedPdfs();
    final customerRepo = CustomerRepository();
    await customerRepo.getAllCustomers();

    final savedSummary = await _settingsRepo.getSummaryTheme();
    _summaryIsBlue = savedSummary == 'blue';

    // 会社設定のデフォルト消費税率を取得（新規伝票に使用）
    final company = await _companyRepo.getCompanyInfo();
    final defaultTaxRate = company.defaultTaxRate;

    setState(() {
      // 既存伝票がある場合は初期値を上書き
      if (widget.existingInvoice != null) {
        final inv = widget.existingInvoice!;
        _selectedCustomer = inv.customer;
        _items.addAll(inv.items);
        // HASHチェーンでロック済み伝票は保存時点の税率・課税状態を完全に維持（不変）
        // 下書き伝票のみF1(会社設定)のデフォルト税率を反映
        if (inv.isLocked) {
          _taxRate = inv.taxRate;
          _includeTax = inv.taxRate > 0 || inv.includeTax;
        } else {
          _taxRate = inv.taxRate > 0 ? inv.taxRate : defaultTaxRate;
          _includeTax = inv.taxRate > 0 || inv.includeTax || defaultTaxRate > 0;
        }
        _documentType = inv.documentType;
        _selectedDate = inv.date;
        _isDraft = inv.isDraft;
        _currentId = inv.id;
        _isLocked = inv.isLocked;
        if (inv.subject != null) _subjectController.text = inv.subject!;
        _currentInvoice = inv;
      } else {
        _taxRate = defaultTaxRate > 0 ? defaultTaxRate : 0.10;
        _includeTax = true;
        _isDraft = true;
        _documentType = widget.initialDocumentType;
        _currentId = null;
        _isLocked = false;
        _currentInvoice = null;
      }
    });
    _isViewMode = widget.startViewMode; // 指定に従う
    _showNewBadge = widget.showNewBadge;
    _showCopyBadge = widget.showCopyBadge;
    _pushHistory(clearRedo: true);
    _lastLoggedSubject = _subjectController.text;
    if (_currentId != null) {
      _loadEditLogs();
    }
  }

  @override
  void dispose() {
    _subjectFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadEditLogs() async {
    if (_currentId == null) return;
    final logs = await _editLogRepo.getLogs(_currentId!);
    if (!mounted) return;
    setState(() => _editLogs = logs);
  }

  void _onSubjectChanged() {
    if (_isApplyingSnapshot) return;
    _pushHistory();
  }

  void _addItem() {
    Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProductMasterScreen(selectionMode: true),
      ),
    ).then((product) {
      if (product == null) return;
      setState(() {
        _items.add(
          InvoiceItem(
            productId: product.id,
            description: product.name,
            quantity: 1,
            unitPrice: product.defaultUnitPrice,
          ),
        );
      });
      _pushHistory();
      final id = _ensureCurrentId();
      final msg = "商品「${product.name}」を追加しました";
      _editLogRepo.addLog(id, msg).then((_) => _loadEditLogs());
    });
  }

  int get _subTotal =>
      _items.fold(0, (sum, item) => sum + (item.unitPrice * item.quantity));
  Future<void> _saveInvoice({bool generatePdf = true}) async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("取引先を選択してください")));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("明細を1件以上入力してください")));
      return;
    }

    _savingNotifier.value = true;

    // GPS情報の取得
    final gpsService = GpsService();
    final pos = await gpsService.getCurrentLocation();
    if (pos != null) {
      await gpsService.logLocation(); // 履歴テーブルにも保存
    }

    final invoiceId = _ensureCurrentId();

    final invoice = Invoice(
      id: invoiceId,
      customer: _selectedCustomer!,
      date: _selectedDate,
      items: _items,
      taxRate: _includeTax ? _taxRate : 0.0,
      documentType: _documentType,
      customerFormalNameSnapshot: _selectedCustomer!.formalName,
      subject: _subjectController.text.isNotEmpty
          ? _subjectController.text
          : null, // 追加
      notes: _includeTax ? "（消費税 ${(_taxRate * 100).toInt()}% 込み）" : null,
      latitude: pos?.latitude,
      longitude: pos?.longitude,
      isDraft: _isDraft, // 追加
      includeTax: _includeTax,
      priceAdjustmentType: _currentInvoice?.priceAdjustmentType,
      priceAdjustmentUnit: _currentInvoice?.priceAdjustmentUnit,
    );
    try {
      // PDF生成有無に関わらず、まずは保存
      if (generatePdf) {
        final path = await generateInvoicePdf(invoice);
        if (path != null) {
          final updatedInvoice = invoice.copyWith(filePath: path);
          await _repository.saveInvoice(updatedInvoice);
          _currentId = updatedInvoice.id;
          if (mounted) widget.onInvoiceGenerated(updatedInvoice, path);
          if (mounted)
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("伝票を保存し、PDFを生成しました")));
        } else {
          if (mounted)
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("PDF生成に失敗しました")));
        }
      } else {
        await _repository.saveInvoice(invoice);
        _currentId = invoice.id;
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("伝票を保存しました（PDF未生成）")));
      }
      await _editLogRepo.addLog(_currentId!, "伝票を保存しました");
      await _loadEditLogs();
      if (mounted) setState(() => _isViewMode = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) _savingNotifier.value = false;
    }
  }

  void _showPreview() {
    if (_selectedCustomer == null) return;
    final id = _ensureCurrentId();
    _editLogRepo.addLog(id, "PDFプレビューを開きました").then((_) => _loadEditLogs());
    final invoice = Invoice(
      id: id,
      customer: _selectedCustomer!,
      date: _selectedDate, // 修正
      items: _items,
      taxRate: _includeTax ? _taxRate : 0.0,
      documentType: _documentType,
      customerFormalNameSnapshot: _selectedCustomer!.formalName,
      notes: _includeTax ? "（消費税 ${(_taxRate * 100).toInt()}% 込み）" : "（非課税）",
      isDraft: _isDraft,
      isLocked: _isLocked,
      includeTax: _includeTax,
      priceAdjustmentType: _currentInvoice?.priceAdjustmentType,
      priceAdjustmentUnit: _currentInvoice?.priceAdjustmentUnit,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoicePdfPreviewPage(
          invoice: invoice,
          isUnlocked: true,
          isLocked: _isLocked,
          allowFormalIssue: invoice.isDraft && !_isLocked,
          onFormalIssue: invoice.isDraft
              ? () async {
                  final promoted = invoice.copyWith(
                    id: id,
                    isDraft: false,
                    isLocked: true,
                  );
                  await _invoiceRepo.saveInvoice(promoted);
                  final newPath = await generateInvoicePdf(promoted);
                  final saved = newPath != null
                      ? promoted.copyWith(filePath: newPath)
                      : promoted;
                  await _invoiceRepo.saveInvoice(saved);
                  await _editLogRepo.addLog(_ensureCurrentId(), "正式発行しました");
                  if (!context.mounted) return false;
                  setState(() {
                    _isDraft = false;
                    _isLocked = true;
                  });
                  return true;
                }
              : null,
          showShare: true,
          showEmail: true,
          showPrint: true,
        ),
      ),
    );
  }

  void _pushHistory({bool clearRedo = false}) {
    setState(() {
      if (_undoStack.length >= 30) _undoStack.removeAt(0);
      _undoStack.add(
        _InvoiceSnapshot(
          customer: _selectedCustomer,
          items: _cloneItems(_items),
          taxRate: _taxRate,
          includeTax: _includeTax,
          documentType: _documentType,
          date: _selectedDate,
          isDraft: _isDraft,
          subject: _subjectController.text,
        ),
      );
      if (clearRedo) _redoStack.clear();
    });
  }

  void _undo() {
    if (_undoStack.length <= 1) return; // 直前状態がない
    setState(() {
      // 現在の状態をredoへ積む
      _redoStack.add(
        _InvoiceSnapshot(
          customer: _selectedCustomer,
          items: _cloneItems(_items),
          taxRate: _taxRate,
          includeTax: _includeTax,
          documentType: _documentType,
          date: _selectedDate,
          isDraft: _isDraft,
          subject: _subjectController.text,
        ),
      );
      // 一番新しい履歴を捨て、直前のスナップショットを適用
      _undoStack.removeLast();
      final snapshot = _undoStack.last;
      _isApplyingSnapshot = true;
      _selectedCustomer = snapshot.customer;
      _items
        ..clear()
        ..addAll(_cloneItems(snapshot.items));
      _taxRate = snapshot.taxRate;
      _includeTax = snapshot.includeTax;
      _documentType = snapshot.documentType;
      _selectedDate = snapshot.date;
      _isDraft = snapshot.isDraft;
      _subjectController.text = snapshot.subject;
      _isApplyingSnapshot = false;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(
        _InvoiceSnapshot(
          customer: _selectedCustomer,
          items: _cloneItems(_items),
          taxRate: _taxRate,
          includeTax: _includeTax,
          documentType: _documentType,
          date: _selectedDate,
          isDraft: _isDraft,
          subject: _subjectController.text,
        ),
      );
      final snapshot = _redoStack.removeLast();
      _isApplyingSnapshot = true;
      _selectedCustomer = snapshot.customer;
      _items
        ..clear()
        ..addAll(_cloneItems(snapshot.items));
      _taxRate = snapshot.taxRate;
      _includeTax = snapshot.includeTax;
      _documentType = snapshot.documentType;
      _selectedDate = snapshot.date;
      _isDraft = snapshot.isDraft;
      _subjectController.text = snapshot.subject;
      _isApplyingSnapshot = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat("#,###");
    final themeColor = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    final docColor = _documentTypeColor(_documentType);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    // 閲覧モードのみZoomableAppBarを使用（編集モードは入力フィールドと競合するため）
    final appBar = AppBar(
      backgroundColor: docColor,
      leading: const BackButton(),
      title: GestureDetector(
        onTap: _isDraft && !_isLocked && _isViewMode
            ? () async {
                // タップエフェクト
                setState(() => _titleBarFlash = true);
                await Future.delayed(const Duration(milliseconds: 150));
                setState(() => _titleBarFlash = false);
                _showDocumentTypeChangeDialog();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _titleBarFlash
                ? Colors.white.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "${_isViewMode ? 'D3' : 'D4'}:${_documentTypeLabel(_documentType)}${_isViewMode ? '' : '(編集)'}",
          ),
        ),
      ),
      actions: [
        if (_isDraft && _isViewMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: _DraftBadge(),
          ),
        IconButton(
          icon: AnimatedScale(
            scale: _showCopyBadge ? 1.3 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(_showCopyBadge ? 8 : 0),
              decoration: BoxDecoration(
                color: _showCopyBadge
                    ? Colors.green.withOpacity(0.3)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: _showCopyBadge
                    ? Border.all(color: Colors.green, width: 2)
                    : null,
              ),
              child: Icon(
                _showCopyBadge ? Icons.check : Icons.copy,
                color: _showCopyBadge ? Colors.green : null,
              ),
            ),
          ),
          tooltip: "コピーして新規",
          onPressed: () async {
            // コピーエフェクト（派手に）
            setState(() => _showCopyBadge = true);
            await Future.delayed(const Duration(milliseconds: 500));
            setState(() => _showCopyBadge = false);
            _copyAsNew();
          },
        ),
        if (_isLocked)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.lock, color: Colors.white),
          )
        else if (_isViewMode)
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "編集モードにする",
            onPressed: () => setState(() => _isViewMode = false),
          )
        else ...[
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _canUndo ? _undo : null,
            tooltip: "元に戻す",
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _canRedo ? _redo : null,
            tooltip: "やり直す",
          ),
          if (!_isLocked)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: "保存",
              onPressed: _savingNotifier.value
                  ? null
                  : () => _saveInvoice(generatePdf: false),
            ),
        ],
      ],
    );

    // 閲覧モードのみZoomableAppBarでラップ（編集モードは入力フィールドと競合するため）
    final content = Scaffold(
      backgroundColor: themeColor,
      resizeToAvoidBottomInset: false,
      body: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      keyboardInset + 140,
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateSection(),
                        const SizedBox(height: 16),
                        _buildCustomerSection(),
                        const SizedBox(height: 16),
                        _buildSubjectSection(),
                        const SizedBox(height: 20),
                        _buildItemsSection(fmt),
                        const SizedBox(height: 20),
                        _buildSummarySection(fmt),
                        const SizedBox(height: 12),
                        _buildEditLogsSection(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _buildBottomActionBar(),
              ],
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _savingNotifier,
              builder: (context, saving, child) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: saving
                    ? Container(
                        key: const ValueKey('saving'),
                        color: Colors.black45,
                        child: Center(
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 32,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 20),
                                  Text(
                                    '保存中...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    '暗号コード生成中',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('idle')),
              ),
            ),
          ],
        ),
      ),
    );

    // AppBarをジェスチャー検出領域（センサー）として使用
    // ページコンテンツのみ拡大縮小、AppBar自体は通常表示
    final sensorAppBar = PreferredSize(
      preferredSize: appBar.preferredSize,
      child: GestureDetector(
        // タイトルバー左右スワイプでコンテンツをズーム
        onHorizontalDragStart: (details) {
          _titleBarStartScale = _transformationController.value
              .getMaxScaleOnAxis();
          _titleBarStartX = details.globalPosition.dx;
        },
        onHorizontalDragUpdate: (details) {
          final deltaX = details.globalPosition.dx - _titleBarStartX;
          // 感度4倍（/50）でズーム変更
          final scaleChange = deltaX / 50 * 0.1;
          final newScale = (_titleBarStartScale + scaleChange).clamp(1.0, 2.0);
          // InteractiveViewerのスケールを更新
          _transformationController.value = Matrix4.identity()..scale(newScale);
          // スケール1.01以上でパン有効化
          final shouldPan = newScale > 1.01;
          if (shouldPan != _panEnabled) {
            setState(() => _panEnabled = shouldPan);
          }
        },
        onHorizontalDragEnd: (details) {
          _titleBarStartScale = _transformationController.value
              .getMaxScaleOnAxis();
        },
        behavior: HitTestBehavior.translucent,
        child: appBar, // AppBarはそのまま表示（拡大縮小しない）
      ),
    );

    return Scaffold(
      appBar: sensorAppBar,
      backgroundColor: themeColor,
      resizeToAvoidBottomInset: false,
      body: _isViewMode
          ? InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 2.0,
              boundaryMargin: const EdgeInsets.all(100),
              constrained: true,
              panEnabled: _panEnabled,
              child: content.body!,
            )
          : content.body!,
    );
  }

  Widget _buildDateSection() {
    final fmt = DateFormat('yyyy/MM/dd');
    return GestureDetector(
      onTap: _isViewMode
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _pushHistory();
              }
            },
      child: Align(
        alignment: Alignment.centerLeft,
        child: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "伝票日付: ${fmt.format(_selectedDate)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_showNewBadge)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "新規",
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (_showCopyBadge)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "複写",
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (!_isViewMode && !_isLocked) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Colors.indigo,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: const Icon(Icons.business, color: Colors.blueGrey),
        title: Text(
          _selectedCustomer != null
              ? _customerNameWithHonorific(_selectedCustomer!)
              : "取引先を選択してください",
          style: TextStyle(
            color: _selectedCustomer == null
                ? Colors.grey
                : (isDark ? Colors.white : Colors.black87),
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: _isViewMode
            ? null
            : Text(
                "顧客マスターから選択",
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
        trailing: (_isViewMode || _isLocked)
            ? null
            : const Icon(Icons.chevron_right),
        onTap: (_isViewMode || _isLocked)
            ? null
            : () async {
                final Customer? picked = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerMasterScreen(selectionMode: true),
                    fullscreenDialog: true,
                  ),
                );
                if (picked != null) {
                  setState(() => _selectedCustomer = picked);
                  _pushHistory();
                }
              },
      ),
    );
  }

  Widget _buildItemsSection(NumberFormat fmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "明細項目",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (!_isViewMode && !_isLocked)
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text("追加"),
              ),
          ],
        ),
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text("商品が追加されていません", style: TextStyle(color: Colors.grey)),
            ),
          )
        else if (_isViewMode)
          Column(
            children: _items
                .map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    elevation: 0.5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Spacer(flex: 1),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  "￥${fmt.format(item.unitPrice)}",
                                  style: const TextStyle(fontSize: 12.5),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  "× ${item.quantity}",
                                  style: const TextStyle(fontSize: 12.5),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const Spacer(flex: 1),
                              Text(
                                "= ￥${fmt.format(item.unitPrice * item.quantity)}",
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            onReorder: (oldIndex, newIndex) async {
              int targetIndex = newIndex;
              setState(() {
                if (targetIndex > oldIndex) targetIndex -= 1;
                final item = _items.removeAt(oldIndex);
                _items.insert(targetIndex, item);
              });
              _pushHistory();
              final id = _ensureCurrentId();
              final item = _items[targetIndex];
              final msg =
                  "明細を並べ替えました: ${item.description} を ${oldIndex + 1} → ${targetIndex + 1}";
              await _editLogRepo.addLog(id, msg);
              await _loadEditLogs();
            },
            buildDefaultDragHandles: false,
            itemBuilder: (context, idx) {
              final item = _items[idx];
              return ReorderableDelayedDragStartListener(
                key: ValueKey('item_${idx}_${item.description}'),
                index: idx,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  elevation: 0.5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "￥${fmt.format(item.unitPrice)} × ${item.quantity} = ￥${fmt.format(item.unitPrice * item.quantity)}",
                                    style: const TextStyle(fontSize: 12.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (!_isViewMode && !_isLocked)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 18),
                                    onPressed: () async {
                                      if (item.quantity <= 1) return;
                                      setState(
                                        () => _items[idx] = item.copyWith(
                                          quantity: item.quantity - 1,
                                        ),
                                      );
                                      _pushHistory();
                                      final id = _ensureCurrentId();
                                      final msg =
                                          "${item.description} の数量を ${item.quantity - 1} に変更しました";
                                      await _editLogRepo.addLog(id, msg);
                                      await _loadEditLogs();
                                    },
                                    constraints: const BoxConstraints.tightFor(
                                      width: 28,
                                      height: 28,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final ctrl = TextEditingController(
                                        text: '${item.quantity}',
                                      );
                                      final result = await showDialog<int>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('数量を入力'),
                                          content: TextField(
                                            controller: ctrl,
                                            keyboardType: TextInputType.number,
                                            autofocus: true,
                                            decoration: const InputDecoration(
                                              labelText: '数量',
                                            ),
                                            onSubmitted: (v) {
                                              final n = int.tryParse(v);
                                              if (n != null && n >= 1)
                                                Navigator.pop(ctx, n);
                                            },
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('キャンセル'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                final n = int.tryParse(
                                                  ctrl.text,
                                                );
                                                if (n != null && n >= 1)
                                                  Navigator.pop(ctx, n);
                                              },
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (result != null) {
                                        setState(
                                          () => _items[idx] = item.copyWith(
                                            quantity: result,
                                          ),
                                        );
                                        _pushHistory();
                                        final id = _ensureCurrentId();
                                        await _editLogRepo.addLog(
                                          id,
                                          '${item.description} の数量を $result に変更しました',
                                        );
                                        await _loadEditLogs();
                                      }
                                    },
                                    child: SizedBox(
                                      width: 36,
                                      child: Text(
                                        '${item.quantity}',
                                        style: const TextStyle(fontSize: 12.5),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 18),
                                    onPressed: () async {
                                      setState(
                                        () => _items[idx] = item.copyWith(
                                          quantity: item.quantity + 1,
                                        ),
                                      );
                                      _pushHistory();
                                      final id = _ensureCurrentId();
                                      final msg =
                                          "${item.description} の数量を ${item.quantity + 1} に変更しました";
                                      await _editLogRepo.addLog(id, msg);
                                      await _loadEditLogs();
                                    },
                                    constraints: const BoxConstraints.tightFor(
                                      width: 28,
                                      height: 28,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      final removed = _items[idx];
                                      setState(() => _items.removeAt(idx));
                                      _pushHistory();
                                      final id = _ensureCurrentId();
                                      final msg =
                                          "商品「${removed.description}」を削除しました";
                                      await _editLogRepo.addLog(id, msg);
                                      await _loadEditLogs();
                                    },
                                    tooltip: "削除",
                                    constraints: const BoxConstraints.tightFor(
                                      width: 32,
                                      height: 32,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSummarySection(NumberFormat formatter) {
    final int subtotal = _subTotal;
    final int itemDiscountAmount = _calculateItemDiscount();
    final int priceAdjustmentDiscount = _calculatePriceAdjustmentDiscount();
    final int totalDiscountAmount =
        itemDiscountAmount + priceAdjustmentDiscount;
    final int taxableAmount = subtotal - totalDiscountAmount;
    final int tax = _includeTax ? (taxableAmount * _taxRate).floor() : 0;
    final int total = taxableAmount + tax;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final useBlue = _summaryIsBlue;
    final bgColor = useBlue
        ? Colors.indigo
        : (isDark ? const Color(0xFF2C2C2C) : Colors.white);
    final borderColor = Colors.transparent;
    final labelColor = useBlue ? Colors.white70 : textColor;
    final totalColor = useBlue ? Colors.white : textColor;
    final dividerColor = useBlue
        ? Colors.white24
        : (isDark ? Colors.grey.shade700 : Colors.grey.shade300);

    // 数値をフォーマット（0 の場合も "0" として表示）
    String formatAmount(int amount) {
      final formatted = formatter.format(amount);
      return formatted.isEmpty ? "0" : formatted;
    }

    return GestureDetector(
      onLongPress: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.palette, color: Colors.indigo),
                  title: const Text('インディゴ'),
                  onTap: () => Navigator.pop(context, 'blue'),
                ),
                ListTile(
                  leading: const Icon(Icons.palette, color: Colors.grey),
                  title: const Text('白'),
                  onTap: () => Navigator.pop(context, 'white'),
                ),
              ],
            ),
          ),
        );
        if (selected == null) return;
        setState(() => _summaryIsBlue = selected == 'blue');
        await _settingsRepo.setSummaryTheme(selected);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow("小計", "￥${formatAmount(subtotal)}", labelColor),
            if (itemDiscountAmount > 0) ...[
              Divider(color: dividerColor),
              _buildSummaryRow(
                "値引き",
                "-￥${formatAmount(itemDiscountAmount)}",
                Colors.red.shade300,
              ),
            ],
            if (priceAdjustmentDiscount > 0 ||
                (!_isViewMode && !_isLocked)) ...[
              Divider(color: dividerColor),
              GestureDetector(
                onTap: _isViewMode || _isLocked
                    ? null
                    : () => _showPriceAdjustmentDialog(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "価格調整",
                          style: TextStyle(
                            fontSize: 14,
                            color: useBlue ? Colors.white : Colors.indigo.shade700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.settings,
                          size: 16,
                          color: useBlue
                              ? Colors.white
                              : Colors.indigo.shade700,
                        ),
                      ],
                    ),
                    if (priceAdjustmentDiscount > 0)
                      Text(
                        "-￥${formatAmount(priceAdjustmentDiscount)}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: useBlue
                              ? Colors.white
                              : Colors.indigo.shade700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            Divider(color: dividerColor),
            _buildSummaryRow(
              "税抜金額",
              "￥${formatAmount(taxableAmount)}",
              labelColor,
            ),
            if (tax > 0) ...[
              Divider(color: dividerColor),
              _buildSummaryRow("消費税", "￥${formatAmount(tax)}", labelColor),
            ],
            Divider(color: dividerColor),
            _buildSummaryRow(
              tax > 0 ? "合計金額 (税込)" : "合計金額",
              "￥${formatAmount(total)}",
              totalColor,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  /// 明細単位の値引き合計を計算
  int _calculateItemDiscount() {
    return _items.fold(0, (sum, item) {
      if (item.discountAmount != null && item.discountAmount! > 0) {
        return sum + item.discountAmount!;
      }
      if (item.discountRate != null && item.discountRate! > 0) {
        final base = item.quantity * item.unitPrice;
        return sum + (base * item.discountRate!).round();
      }
      return sum;
    });
  }

  /// 価格調整値引きを計算
  int _calculatePriceAdjustmentDiscount() {
    final adjustmentType = _currentInvoice?.priceAdjustmentType;
    final adjustmentUnit = _currentInvoice?.priceAdjustmentUnit;

    if (adjustmentType == null || adjustmentUnit == null) {
      return 0;
    }

    if (adjustmentType == 'manual') {
      return adjustmentUnit;
    }

    final unit = adjustmentUnit;
    final baseAmount = _subTotal - _calculateItemDiscount();
    final taxAmount = _includeTax ? (baseAmount * _taxRate).floor() : 0;
    final totalBeforeAdjustment = baseAmount + taxAmount;

    int adjustedTotal;
    switch (adjustmentType) {
      case 'round_down':
        adjustedTotal = (totalBeforeAdjustment ~/ unit) * unit;
        break;
      case 'round_up':
        adjustedTotal = ((totalBeforeAdjustment + unit - 1) ~/ unit) * unit;
        break;
      case 'round_nearest':
        adjustedTotal = ((totalBeforeAdjustment + unit ~/ 2) ~/ unit) * unit;
        break;
      default:
        return 0;
    }

    return totalBeforeAdjustment - adjustedTotal;
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color textColor, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PDFプレビュー・編集/保存ボタン（スワイプ吸収）
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (_) {}, // 垂直スワイプを吸収
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _items.isEmpty ? null : _showPreview,
                      icon: const Icon(Icons.picture_as_pdf), // アイコン変更
                      label: const Text("PDFプレビュー"), // 名称変更
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.indigo),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isLocked
                        ? ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.lock),
                            label: const Text("ロック済み"),
                          )
                        : (_isViewMode
                              ? ElevatedButton.icon(
                                  onPressed: () =>
                                      setState(() => _isViewMode = false),
                                  icon: const Icon(Icons.edit),
                                  label: const Text("編集"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () =>
                                      _saveInvoice(generatePdf: false),
                                  icon: const Icon(Icons.save),
                                  label: const Text("保存"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                )),
                  ),
                ],
              ),
            ),
            // 通知テロップ（閲覧モード時のみ表示）- ボタンの下に配置
            if (_isViewMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe, size: 16, color: Colors.indigo),
                    const SizedBox(width: 6),
                    Text(
                      'タイトルバー横になぞると拡大縮小できます',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "案件名 / 件名",
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            focusNode: _subjectFocusNode,
            controller: _subjectController,
            style: TextStyle(color: textColor),
            readOnly: _isViewMode || _isLocked,
            enableInteractiveSelection: !(_isViewMode || _isLocked),
            decoration: InputDecoration(
              hintText: "例：事務所改修工事 / 〇〇月分リース料",
              hintStyle: TextStyle(
                color: textColor.withAlpha((0.5 * 255).round()),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditLogsSection() {
    if (_currentId == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.black54;
    final hintColor = isDark ? Colors.grey.shade500 : Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0.5,
          color: cardColor,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.13),
                  blurRadius: 10,
                  spreadRadius: -4,
                  offset: const Offset(0, 2),
                  blurStyle: BlurStyle.inner,
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "編集ログ (直近1週間)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                if (_editLogs.isEmpty)
                  Text(
                    "編集ログはありません",
                    style: TextStyle(color: hintColor, fontSize: 12),
                  )
                else
                  ..._editLogs.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.circle, size: 6, color: hintColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat(
                                    'yyyy/MM/dd HH:mm',
                                  ).format(e.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subtitleColor,
                                  ),
                                ),
                                Text(
                                  e.message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 価格調整ダイアログ
  Future<void> _showPriceAdjustmentDialog() async {
    // _currentInvoiceがnullの場合は初期化
    if (_currentInvoice == null && _selectedCustomer != null) {
      _currentInvoice = Invoice(
        id: _currentId,
        customer: _selectedCustomer!,
        date: _selectedDate,
        items: _items,
        documentType: _documentType,
        taxRate: _taxRate,
        isDraft: _isDraft,
        isLocked: _isLocked,
        subject: _subjectController.text.isEmpty
            ? null
            : _subjectController.text,
        includeTax: _includeTax,
      );
    }

    final mode = ValueNotifier<String>(_currentInvoice?.priceAdjustmentType ?? 'round_down'); // 'round_down' or 'manual'
    final unitController = TextEditingController(
      text: _currentInvoice?.priceAdjustmentUnit?.toString() ?? '1000',
    );
    final manualDiscountController = TextEditingController(
      text: (_currentInvoice?.priceAdjustmentType == 'manual' ? _currentInvoice?.priceAdjustmentUnit?.toString() : '0') ?? '0',
    );
    final calculatedResult = ValueNotifier<Map<String, int>>({});

    void updateCalculation() {
      if (mode.value == 'round_down') {
        final unit = int.tryParse(unitController.text);
        if (unit == null || unit <= 0) {
          calculatedResult.value = {};
          return;
        }

        final baseAmount = _subTotal - _calculateItemDiscount();
        final taxAmount = _includeTax ? (baseAmount * _taxRate).floor() : 0;
        final totalBeforeAdjustment = baseAmount + taxAmount;
        final adjustedTotal = (totalBeforeAdjustment ~/ unit) * unit;
        final discount = totalBeforeAdjustment - adjustedTotal;

        calculatedResult.value = {
          'before': totalBeforeAdjustment,
          'after': adjustedTotal,
          'discount': discount,
        };
      } else {
        // Manual mode
        final discount = int.tryParse(manualDiscountController.text) ?? 0;
        final baseAmount = _subTotal - _calculateItemDiscount();
        final taxAmount = _includeTax ? (baseAmount * _taxRate).floor() : 0;
        final totalBeforeAdjustment = baseAmount + taxAmount;
        final adjustedTotal = totalBeforeAdjustment - discount;

        calculatedResult.value = {
          'before': totalBeforeAdjustment,
          'after': adjustedTotal,
          'discount': discount,
        };
      }
    }

    updateCalculation();

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              child: SizedBox(
                width: 360,
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  children: [
                    // 上部：スクロール可能なコンテンツ
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // モード切り替え
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'round_down',
                                  label: Text('切り捨て計算'),
                                ),
                                ButtonSegment(
                                  value: 'manual',
                                  label: Text('手動入力'),
                                ),
                              ],
                              selected: {mode.value},
                              onSelectionChanged: (Set<String> newSelection) {
                                mode.value = newSelection.first;
                                updateCalculation();
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: 12),
                            
                            // 切り捨て計算モード
                            if (mode.value == 'round_down') ...[
                              const Text(
                                '切り捨て単位:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: unitController,
                                      keyboardType: TextInputType.none,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (_) {
                                        updateCalculation();
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: IconButton(
                                      icon: const Icon(Icons.backspace),
                                      onPressed: () {
                                        if (unitController.text.isNotEmpty) {
                                          unitController.text = unitController.text
                                              .substring(
                                                0,
                                                unitController.text.length - 1,
                                              );
                                          updateCalculation();
                                          setState(() {});
                                        }
                                      },
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            
                            // 手動入力モード
                            if (mode.value == 'manual') ...[
                              const Text(
                                '値引き額:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: manualDiscountController,
                                      keyboardType: TextInputType.none,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (_) {
                                        updateCalculation();
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: IconButton(
                                      icon: const Icon(Icons.backspace),
                                      onPressed: () {
                                        if (manualDiscountController.text.isNotEmpty) {
                                          manualDiscountController.text = manualDiscountController.text
                                              .substring(
                                                0,
                                                manualDiscountController.text.length - 1,
                                              );
                                          updateCalculation();
                                          setState(() {});
                                        }
                                      },
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            
                            const SizedBox(height: 12),
                            ValueListenableBuilder<Map<String, int>>(
                              valueListenable: calculatedResult,
                              builder: (context, result, _) {
                                if (result.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final fmt = NumberFormat('#,###');
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('調整前:'),
                                          Text(
                                            '￥${fmt.format(result['before'])}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            mode.value == 'round_down' ? '切り捨て後:' : '調整後:',
                                          ),
                                          Text(
                                            '￥${fmt.format(result['after'])}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('値引き額:'),
                                          Text(
                                            '-￥${fmt.format(result['discount'])}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 中部：テンキー（固定・スクロールしない）
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildCalculatorKeypad(
                        controller: mode.value == 'round_down' ? unitController : manualDiscountController,
                        onUpdate: () {
                          updateCalculation();
                          setState(() {});
                        },
                      ),
                    ),
                    // 下部：アクションボタン（固定）
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('キャンセル'),
                          ),
                          TextButton(
                            onPressed: () {
                              if (_currentInvoice != null) {
                                this.setState(() {
                                  _currentInvoice = _currentInvoice!.copyWith(
                                    priceAdjustmentType: null,
                                    priceAdjustmentUnit: null,
                                  );
                                });
                                _pushHistory();
                              }
                              Navigator.pop(dialogContext);
                            },
                            child: const Text('クリア', style: TextStyle(color: Colors.red)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (_currentInvoice != null) {
                                if (mode.value == 'round_down') {
                                  final unit = int.tryParse(unitController.text);
                                  if (unit != null && unit > 0) {
                                    this.setState(() {
                                      _currentInvoice = _currentInvoice!.copyWith(
                                        priceAdjustmentType: 'round_down',
                                        priceAdjustmentUnit: unit,
                                      );
                                    });
                                    _pushHistory();
                                    Navigator.pop(dialogContext);
                                  }
                                } else {
                                  final discount = int.tryParse(manualDiscountController.text);
                                  if (discount != null && discount >= 0) {
                                    this.setState(() {
                                      _currentInvoice = _currentInvoice!.copyWith(
                                        priceAdjustmentType: 'manual',
                                        priceAdjustmentUnit: discount,
                                      );
                                    });
                                    _pushHistory();
                                    Navigator.pop(dialogContext);
                                  }
                                }
                              }
                            },
                            child: const Text('設定'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCalculatorKeypad({
    required TextEditingController controller,
    required VoidCallback onUpdate,
  }) {
    return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        childAspectRatio: 2.0,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: [
          for (final num in ['7', '8', '9', 'C'])
            ElevatedButton(
              onPressed: () {
                if (num == 'C') {
                  controller.text = '';
                } else {
                  controller.text += num;
                }
                onUpdate();
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: num == 'C' ? Colors.red.shade100 : Colors.blue.shade100,
                foregroundColor: num == 'C' ? Colors.red.shade900 : Colors.blue.shade900,
              ),
              child: Text(
                num,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          for (final num in ['4', '5', '6', '00'])
            ElevatedButton(
              onPressed: () {
                controller.text += num;
                onUpdate();
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade900,
              ),
              child: Text(
                num,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          for (final num in ['1', '2', '3', '000'])
            ElevatedButton(
              onPressed: () {
                controller.text += num;
                onUpdate();
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade900,
              ),
              child: Text(
                num,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          for (final num in ['0', '0000'])
            ElevatedButton(
              onPressed: () {
                controller.text += num;
                onUpdate();
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade900,
              ),
              child: Text(
                num,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
        ],
    );
  }
}

class _DraftBadge extends StatelessWidget {
  const _DraftBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '下書き',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.orange,
        ),
      ),
    );
  }
}

class _InvoiceSnapshot {
  final Customer? customer;
  final List<InvoiceItem> items;
  final double taxRate;
  final bool includeTax;
  final DocumentType documentType;
  final DateTime date;
  final bool isDraft;
  final String subject;

  _InvoiceSnapshot({
    required this.customer,
    required this.items,
    required this.taxRate,
    required this.includeTax,
    required this.documentType,
    required this.date,
    required this.isDraft,
    required this.subject,
  });
}
