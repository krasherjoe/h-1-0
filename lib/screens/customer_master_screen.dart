import 'package:flutter/material.dart';
import '../widgets/keyboard_inset_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/customer_model.dart';
import '../services/customer_repository.dart';
import 'customer_edit_screen.dart';
import '../widgets/custom_field_display_widget.dart';
import '../services/custom_field_repository.dart';
import '../services/business_profile_repository.dart';
import '../models/custom_field_model.dart';
import 'phonebook_selection_screen.dart';

class CustomerMasterScreen extends StatefulWidget {
  final bool selectionMode;
  final bool showHidden;

  const CustomerMasterScreen({
    super.key,
    this.selectionMode = false,
    this.showHidden = false,
  });

  @override
  State<CustomerMasterScreen> createState() => _CustomerMasterScreenState();
}

class _CustomerMasterScreenState extends State<CustomerMasterScreen> {
  final CustomerRepository _customerRepo = CustomerRepository();
  final CustomFieldRepository _customFieldRepo = CustomFieldRepository();
  final BusinessProfileRepository _businessProfileRepo =
      BusinessProfileRepository();
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _customers = [];
  List<Customer> _filtered = [];
  bool _isLoading = true;
  String _sortKey = 'name_asc';
  bool _ignoreCorpPrefix = true;
  Map<String, String> _userKanaMap = {};
  List<CustomField> _customFields = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _customerRepo.ensureCustomerColumns();
      await _loadUserKanaMap();
      await _loadCustomFields();
      if (!context.mounted) return;
      _ensureKanaMapsUsed();
      await _loadCustomers();
    } catch (e, st) {
      print('C2 _init エラー: $e');
      print('スタックトレース: $st');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCustomFields() async {
    try {
      final profile = await _businessProfileRepo.getCurrentProfile();
      final fields = await _customFieldRepo.getActiveFieldsByBusinessProfile(
        profile.id,
      );
      setState(() {
        _customFields = fields;
      });
    } catch (e) {
      // カスタムフィールドの読み込み失敗は無視
      setState(() {
        _customFields = [];
      });
    }
  }

  Map<String, String> _buildDefaultKanaMap() {
    return {
      // あ行
      '安': 'あ',
      '阿': 'あ',
      '浅': 'あ',
      '麻': 'あ',
      '新': 'あ',
      '青': 'あ',
      '赤': 'あ',
      '秋': 'あ',
      '明': 'あ',
      '有': 'あ',
      '伊': 'あ',
      // か行
      '加': 'か',
      '鎌': 'か',
      '上': 'か',
      '川': 'か',
      '河': 'か',
      '北': 'か',
      '木': 'か',
      '菊': 'か',
      '岸': 'か',
      '工': 'か',
      '古': 'か',
      '後': 'か',
      '郡': 'か',
      '熊': 'か',
      '桑': 'か',
      '黒': 'か',
      '香': 'か',
      '金': 'か',
      '兼': 'か',
      '小': 'か',
      // さ行
      '佐': 'さ',
      '齋': 'さ',
      '齊': 'さ',
      '斎': 'さ',
      '斉': 'さ',
      '崎': 'さ',
      '柴': 'さ',
      '沢': 'さ',
      '澤': 'さ',
      '桜': 'さ',
      '櫻': 'さ',
      '酒': 'さ',
      '坂': 'さ',
      '榊': 'さ',
      '札': 'さ',
      '庄': 'し',
      '城': 'し',
      '島': 'さ',
      '嶋': 'さ',
      '鈴': 'す',
      // た行
      '田': 'た',
      '高': 'た',
      '竹': 'た',
      '滝': 'た',
      '瀧': 'た',
      '立': 'た',
      '達': 'た',
      '谷': 'た',
      '多': 'た',
      '千': 'た',
      '太': 'た',
      // な行
      '中': 'な', '永': 'な', '長': 'な', '南': 'な', '難': 'な',
      // は行
      '橋': 'は',
      '林': 'は',
      '原': 'は',
      '浜': 'は',
      '服': 'は',
      '福': 'は',
      '藤': 'は',
      '富': 'は',
      '保': 'は',
      '畠': 'は',
      '畑': 'は',
      // ま行
      '松': 'ま', '前': 'ま', '真': 'ま', '町': 'ま', '間': 'ま', '馬': 'ま',
      // や行
      '山': 'や', '矢': 'や', '柳': 'や',
      // ら行
      '良': 'ら', '涼': 'ら', '竜': 'ら',
      // わ行
      '渡': 'わ', '和': 'わ',
      // その他
      '石': 'い',
      '井': 'い',
      '飯': 'い',
      '五': 'い',
      '吉': 'よ',
      '与': 'よ',
      '森': 'も',
      '守': 'も',
      '岡': 'お',
      '奥': 'お',
      '尾': 'お',
      '白': 'し',
      '志': 'し',
      '広': 'ひ',
      '弘': 'ひ',
      '平': 'ひ',
      '日': 'ひ',
      '布': 'ぬ', '内': 'う', '宇': 'う', '浦': 'う', '野': 'の', '能': 'の',
      '宮': 'み', '三': 'み', '水': 'み', '溝': 'み',
    };
  }

  Future<void> _loadUserKanaMap() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('customKanaMap');
    if (json != null && json.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(json);
        _userKanaMap = decoded.map((k, v) => MapEntry(k, v.toString()));
        if (mounted) setState(_applyFilter);
      } catch (_) {
        // ignore decode errors
      }
    }
  }

  Future<void> _showContactUpdateDialog(Customer customer) async {
    if (customer.isLocked) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ロック中の顧客は連絡先を更新できません')));
      }
      return;
    }
    final emailController = TextEditingController(text: customer.email ?? "");
    final telController = TextEditingController(text: customer.tel ?? "");
    final addressController = TextEditingController(
      text: customer.address ?? "",
    );

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('連絡先を更新'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'メール'),
            ),
            TextField(
              controller: telController,
              decoration: const InputDecoration(labelText: '電話番号'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: '住所'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _customerRepo.updateContact(
                customerId: customer.id,
                email: emailController.text.isEmpty
                    ? null
                    : emailController.text,
                tel: telController.text.isEmpty ? null : telController.text,
                address: addressController.text.isEmpty
                    ? null
                    : addressController.text,
              );
              if (!context.mounted) return;
              Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (updated == true) {
      _loadCustomers();
    }
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _customerRepo.getAllCustomers(
        includeHidden: widget.showHidden,
      );
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('顧客の読み込みに失敗しました: $e')));
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    List<Customer> list = _customers.where((c) {
      return c.displayName.toLowerCase().contains(query) ||
          c.formalName.toLowerCase().contains(query);
    }).toList();
    if (!widget.showHidden) {
      list = list.where((c) => !c.isHidden).toList();
    }
    // Kana filtering disabled temporarily for stability
    switch (_sortKey) {
      case 'name_desc':
        list.sort(
          (a, b) => widget.showHidden
              ? b.id.compareTo(a.id)
              : _normalizedName(
                  b.displayName,
                ).compareTo(_normalizedName(a.displayName)),
        );
        break;
      default:
        list.sort(
          (a, b) => widget.showHidden
              ? b.id.compareTo(a.id)
              : _normalizedName(
                  a.displayName,
                ).compareTo(_normalizedName(b.displayName)),
        );
    }
    _filtered = list;
  }

  String _normalizedName(String name) {
    var n = name.replaceAll(RegExp(r"\s+"), "");
    if (_ignoreCorpPrefix) {
      for (final token in [
        "株式会社",
        "（株）",
        "(株)",
        "有限会社",
        "（有）",
        "(有)",
        "合同会社",
        "（同）",
        "(同)",
      ]) {
        n = n.replaceAll(token, "");
      }
    }
    return n.toLowerCase();
  }

  String _headKana(String name) {
    var n = name.replaceAll(RegExp(r"\s+|\u3000"), "");
    for (final token in [
      "株式会社",
      "（株）",
      "(株)",
      "有限会社",
      "（有）",
      "(有)",
      "合同会社",
      "（同）",
      "(同)",
    ]) {
      if (n.startsWith(token)) n = n.substring(token.length);
    }
    if (n.isEmpty) return '他';
    String ch = n.substring(0, 1);
    final code = ch.codeUnitAt(0);
    if (code >= 0x30A1 && code <= 0x30F6) {
      ch = String.fromCharCode(code - 0x60); // katakana -> hiragana
    }
    if (_userKanaMap.containsKey(ch)) return _userKanaMap[ch]!;
    if (_defaultKanaMap.containsKey(ch)) return _defaultKanaMap[ch]!;
    for (final entry in _kanaBuckets.entries) {
      if (entry.value.contains(ch)) return entry.key;
    }
    return '他';
  }

  final Map<String, List<String>> _kanaBuckets = const {
    'あ': ['あ', 'い', 'う', 'え', 'お'],
    'か': ['か', 'き', 'く', 'け', 'こ', 'が', 'ぎ', 'ぐ', 'げ', 'ご'],
    'さ': ['さ', 'し', 'す', 'せ', 'そ', 'ざ', 'じ', 'ず', 'ぜ', 'ぞ'],
    'た': ['た', 'ち', 'つ', 'て', 'と', 'だ', 'ぢ', 'づ', 'で', 'ど'],
    'な': ['な', 'に', 'ぬ', 'ね', 'の'],
    'は': [
      'は',
      'ひ',
      'ふ',
      'へ',
      'ほ',
      'ば',
      'び',
      'ぶ',
      'べ',
      'ぼ',
      'ぱ',
      'ぴ',
      'ぷ',
      'ぺ',
      'ぽ',
    ],
    'ま': ['ま', 'み', 'む', 'め', 'も'],
    'や': ['や', 'ゆ', 'よ'],
    'ら': ['ら', 'り', 'る', 'れ', 'ろ'],
    'わ': ['わ', 'を', 'ん'],
    '他': ['他'],
  };

  late final Map<String, String> _defaultKanaMap = _buildDefaultKanaMap();

  Future<void> _addOrEditCustomer({Customer? customer}) async {
    final result = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(builder: (_) => CustomerEditScreen(customer: customer)),
    );

    if (!mounted) return;

    if (result != null) {
      try {
        await _customerRepo.saveCustomer(result);
        if (widget.selectionMode) {
          if (!mounted) return;
          Navigator.pop(context, result);
        } else {
          _loadCustomers();
        }
      } catch (e, st) {
        print('C2 顧客保存エラー: $e');
        print('スタックトレース: $st');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('顧客の保存に失敗しました: $e')));
        }
      }
    }
  }

  // Force usage so analyzer doesn't flag as unused when kana filter is disabled
  void _ensureKanaMapsUsed() {
    // ignore: unused_local_variable
    final _ = [
      _kanaBuckets.length,
      _defaultKanaMap.length,
      _userKanaMap.length,
    ];
  }

  Future<void> _showPhonebookImport() async {
    try {
      // 新しい検索機能付き電話帳選択画面を呼び出す
      final result = await Navigator.push<Customer>(
        context,
        MaterialPageRoute(
          builder: (context) => const PhonebookSelectionScreen(),
        ),
      );

      if (!context.mounted) return;

      if (result != null) {
        // 選択された顧客データを保存
        await _customerRepo.saveCustomer(result);
        _loadCustomers();
      }
    } catch (e, st) {
      print('C2 _showPhonebookImport エラー：$e');
      print('スタックトレース：$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('電話帳の読み込みに失敗しました：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.selectionMode ? "C2:顧客選択" : "C1:顧客一覧"),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: "ソート",
            onPressed: () {
              showMenu<String>(
                context: context,
                position: const RelativeRect.fromLTRB(100, 80, 0, 0),
                items: const [
                  PopupMenuItem(value: 'name_asc', child: Text('名前昇順')),
                  PopupMenuItem(value: 'name_desc', child: Text('名前降順')),
                ],
              ).then((val) {
                if (val != null) {
                  setState(() {
                    _sortKey = val;
                    _applyFilter();
                  });
                }
              });
            },
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortKey,
              icon: const Icon(Icons.sort, color: Colors.white),
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem(value: 'name_asc', child: Text('名前昇順')),
                DropdownMenuItem(value: 'name_desc', child: Text('名前降順')),
              ],
              onChanged: (v) {
                setState(() {
                  _sortKey = v ?? 'name_asc';
                  _applyFilter();
                });
              },
            ),
          ),
          if (!widget.selectionMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadCustomers,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: widget.selectionMode
                        ? "名前で検索して選択"
                        : "名前で検索 (電話帳参照ボタンは詳細で)",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(_applyFilter),
                ),
              ),
            ),
            if (!widget.selectionMode)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SwitchListTile(
                    title: const Text('株式会社/有限会社などの接頭辞を無視してソート'),
                    value: _ignoreCorpPrefix,
                    onChanged: (v) => setState(() {
                      _ignoreCorpPrefix = v;
                      _applyFilter();
                    }),
                  ),
                ),
              ),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text("顧客が登録されていません")),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 80, top: 4),
                sliver: SliverList.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final c = _filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c.isLocked
                            ? Colors.grey.shade300
                            : Colors.indigo.shade100,
                        child: Stack(
                          children: [
                            const Align(
                              alignment: Alignment.center,
                              child: Icon(Icons.person, color: Colors.indigo),
                            ),
                            if (c.isLocked)
                              const Align(
                                alignment: Alignment.bottomRight,
                                child: Icon(
                                  Icons.lock,
                                  size: 14,
                                  color: Colors.redAccent,
                                ),
                              ),
                          ],
                        ),
                      ),
                      title: Text(
                        c.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: c.isLocked ? Colors.grey : Colors.black87,
                        ),
                      ),
                      subtitle: Text("${c.formalName} ${c.title}"),
                      onTap: widget.selectionMode
                          ? () {
                              if (c.isHidden) return; // do not select hidden
                              Navigator.pop(context, c);
                            }
                          : () => _showDetailPane(c),
                      trailing: widget.selectionMode
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: c.isLocked
                                  ? null
                                  : () => _addOrEditCustomer(customer: c),
                              tooltip: c.isLocked ? "ロック中" : "編集",
                            ),
                      onLongPress: () => _showContextActions(c),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) {
          return FloatingActionButton.extended(
            onPressed: _showAddMenu,
            icon: const Icon(Icons.add),
            label: Text(widget.selectionMode ? "選択" : "追加"),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          );
        },
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('手入力で新規作成'),
              onTap: () {
                Navigator.pop(context);
                _addOrEditCustomer();
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone),
              title: const Text('電話帳から取り込む'),
              onTap: () {
                Navigator.pop(context);
                _showPhonebookImport();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showContextActions(Customer c) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('詳細を表示'),
              onTap: () {
                Navigator.pop(context);
                _showDetailPane(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('編集'),
              enabled: !c.isLocked,
              onTap: () {
                Navigator.pop(context);
                _addOrEditCustomer(customer: c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail),
              title: const Text('連絡先を更新'),
              enabled: !c.isLocked,
              onTap: () {
                if (c.isLocked) return;
                Navigator.pop(context);
                _showContactUpdateDialog(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: const Text('非表示にする'),
              onTap: () async {
                Navigator.pop(context);
                await _customerRepo.setHidden(c.id, true);
                if (!mounted) return;
                _loadCustomers();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                '削除',
                style: TextStyle(color: Colors.redAccent),
              ),
              enabled: !c.isLocked,
              onTap: c.isLocked
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('削除確認'),
                          content: Text('「${c.displayName}」を削除しますか？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('キャンセル'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                '削除',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _customerRepo.deleteCustomer(c.id);
                        if (!mounted) return;
                        _loadCustomers();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailPane(Customer c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Icon(
                    c.isLocked ? Icons.lock : Icons.person,
                    color: c.isLocked ? Colors.redAccent : Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.formalName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("電話帳参照は端末連絡先連携が必要です")),
                      );
                    },
                    tooltip: "電話帳参照",
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (c.address != null)
                Text("住所: ${c.address}")
              else
                const SizedBox.shrink(),
              if (c.tel != null)
                Text("TEL: ${c.tel}")
              else
                const SizedBox.shrink(),
              if (c.email != null)
                Text("メール: ${c.email}")
              else
                const SizedBox.shrink(),
              Text("敬称: ${c.title}"),
              const SizedBox(height: 12),
              if (_customFields.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'カスタムフィールド',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                CustomFieldDisplayWidget(
                  entityId: c.id,
                  entityType: 'customer',
                  fields: _customFields,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: c.isLocked
                        ? null
                        : () {
                            Navigator.pop(context);
                            _addOrEditCustomer(customer: c);
                          },
                    icon: const Icon(Icons.edit),
                    label: const Text("編集"),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: c.isLocked
                        ? null
                        : () {
                            Navigator.pop(context);
                            _showContactUpdateSheet(c);
                          },
                    icon: const Icon(Icons.contact_mail),
                    label: const Text("連絡先を更新"),
                  ),
                  const SizedBox(width: 8),
                  if (!c.isLocked)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("削除確認"),
                            content: Text("「${c.displayName}」を削除しますか？"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("キャンセル"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  "削除",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (!context.mounted) return;
                        if (confirm == true) {
                          await _customerRepo.deleteCustomer(c.id);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _loadCustomers();
                        }
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        "削除",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  if (c.isLocked)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        label: const Text("ロック中"),
                        avatar: const Icon(Icons.lock, size: 16),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactUpdateSheet(Customer c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => KeyboardInsetWrapper(
        basePadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        extraBottom: 16,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.contact_mail),
                title: const Text('連絡先を更新'),
                enabled: !c.isLocked,
                onTap: () {
                  if (c.isLocked) return;
                  Navigator.pop(context);
                  _showContactUpdateDialog(c);
                },
              ),
              ListTile(
                leading: const Icon(Icons.contact_phone),
                title: const Text('電話帳から取り込む'),
                onTap: () {
                  Navigator.pop(context);
                  _showPhonebookImport();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
