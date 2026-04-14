import 'package:flutter/material.dart';
import '../widgets/keyboard_inset_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/customer_model.dart';
import '../services/customer_repository.dart';
import '../services/customer_data_cleaner.dart';
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
    // 電子帳簿保存法対応：ロック中でも編集可能（履歴は自動保存）
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
    
    // 敬称除去（様、御中、殿、先生）
    n = n.replaceAll(RegExp(r"[\s\u3000]*(様|御中|殿|先生)$"), "");
    
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
        // ロックされた顧客を編集した場合、元のIDを除外して重複チェック
        final originalId = customer?.id;
        await _customerRepo.saveCustomer(result, excludeOriginalId: originalId);
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
      final result = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (context) => const PhonebookSelectionScreen(),
        ),
      );

      if (!context.mounted) return;

      if (result != null) {
        // Map から Customer オブジェクトを取り出す
        final customer = result['customer'] as Customer?;

        if (customer == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('顧客データを取得できませんでした'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        try {
          // Customer オブジェクトを保存（重複チェック付き）
          await _customerRepo.saveCustomer(customer);

          if (!mounted) return;

          // 完了通知を表示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('電話帳から「${customer.displayName}」を追加しました'),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 3),
            ),
          );

          // データ再読み込み（非同期）
          await _loadCustomers();
        } on DuplicateCustomerException catch (e) {
          if (!mounted) return;

          // ローディングを消して重複確認ダイアログを表示
          await Future.delayed(const Duration(milliseconds: 100));
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          // 重複検出時の警告ダイアログ表示
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('顧客が重複しています'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '以下の顧客と重複している可能性があります：',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    _buildDuplicateInfoRow(
                      '表示名:',
                      Text(e.customer.displayName),
                    ),
                    if (e.customer.tel != null &&
                        e.customer.tel!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildDuplicateInfoRow(
                        '電話番号:',
                        Text(
                          e.customer.tel!,
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                    if (e.customer.email != null &&
                        e.customer.email!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildDuplicateInfoRow('メール:', Text(e.customer.email!)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  icon: const Icon(Icons.close),
                  label: const Text('キャンセル'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('上書き登録'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          );

          if (shouldContinue == true) {
            // 強制的に保存（重複チェック無視）
            await _customerRepo.saveCustomer(customer, force: true);

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('顧客を登録しました（重複許容）：${customer.displayName}'),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange.shade700,
                duration: const Duration(seconds: 3),
              ),
            );

            await _loadCustomers();
          } else {
            // キャンセル時の通知
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.cancel, color: Colors.white),
                      SizedBox(width: 12),
                      Text('登録をキャンセルしました：${customer.displayName}'),
                    ],
                  ),
                  backgroundColor: Colors.grey.shade700,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (e) {
          if (!mounted) return;

          // ローディングを消してエラー通知を表示
          await Future.delayed(const Duration(milliseconds: 100));
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          // エラー通知（詳細メッセージ付き）
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(child: Text('顧客登録中にエラーが発生しました')),
                    ],
                  ),
                  if (e.toString().isNotEmpty) ...[
                    const Divider(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Text(
                        e.toString(),
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ],
                ],
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 5),
            ),
          );

          print('C2 インポートエラー：$e');
        }
      } else {
        // キャンセル時の通知（画面から戻る場合）
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('電話帳選択をキャンセルしました'),
              backgroundColor: Colors.grey,
              duration: Duration(seconds: 2),
            ),
          );
        }
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

  /// 重複情報行を構築するヘルパーメソッド
  Widget _buildDuplicateInfoRow(String label, Widget content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(label)),
        Expanded(child: content),
      ],
    );
  }

  /// 敬称の重複を削除
  Future<void> _cleanDuplicateHonorific() async {
    try {
      final duplicates = CustomerDataCleaner.filterDuplicateHonorific(
        _customers,
      );

      if (duplicates.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('敬称の重複がある顧客はいません')));
        return;
      }

      // 確認ダイアログを表示
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('敬称の重複を削除'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${duplicates.length}件の顧客の敬称の重複を削除します。'),
              const SizedBox(height: 12),
              const Text('例：「株式会社 ABC 御中」の敬称を「様」に変更'),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: duplicates.length,
                  itemBuilder: (ctx, i) => Text(
                    '${duplicates[i].formalName} (${duplicates[i].title})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('削除'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      // クリーニング実行
      for (final customer in duplicates) {
        final cleaned = CustomerDataCleaner.cleanCustomer(customer);
        await _customerRepo.saveCustomer(cleaned, force: true);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${duplicates.length}件の敬称の重複を削除しました')),
      );

      // リロード
      _loadCustomers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// 名前から敬称を削除
  Future<void> _cleanHonorificFromName() async {
    try {
      final toClean = _customers
          .where(
            (c) =>
                CustomerDataCleaner.removeTitleFromName(c.formalName) !=
                c.formalName,
          )
          .toList();

      if (toClean.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('名前から削除する敬称がありません')));
        return;
      }

      // 確認ダイアログを表示
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('名前から敬称を削除'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${toClean.length}件の顧客の名前から敬称を削除します。'),
              const SizedBox(height: 12),
              const Text('例：「株式会社 ABC 様」→「株式会社 ABC」'),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: toClean.length,
                  itemBuilder: (ctx, i) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${toClean[i].formalName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '↓ ${CustomerDataCleaner.removeTitleFromName(toClean[i].formalName)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('削除'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      // クリーニング実行
      for (final customer in toClean) {
        final cleaned = CustomerDataCleaner.removeHonorificFromName(customer);
        await _customerRepo.saveCustomer(cleaned, force: true);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${toClean.length}件の名前から敬称を削除しました')),
      );

      // リロード
      _loadCustomers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// 敬称スクリーニング：formalName/displayName に含まれる敬称を検出・修正
  Future<void> _showHonorificsScreening() async {
    if (_isLoading) return;

    final issues = CustomerDataCleaner.screenAll(_customers);

    if (!mounted) return;

    if (issues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('敬称の問題は見つかりませんでした'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    // 選択状態を管理
    final selected = {for (final i in issues) i.original.id: true};

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final checkedIssues = issues
              .where((i) => selected[i.original.id] == true)
              .toList();
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.manage_search, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text('敬称スクリーニング'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${issues.length}件の問題を検出',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setDialogState(() {
                            for (final i in issues)
                              selected[i.original.id] = true;
                          }),
                          child: const Text('全選択'),
                        ),
                        TextButton(
                          onPressed: () => setDialogState(() {
                            for (final i in issues)
                              selected[i.original.id] = false;
                          }),
                          child: const Text('解除'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: issues.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final issue = issues[i];
                        final isChecked = selected[issue.original.id] ?? true;
                        return CheckboxListTile(
                          value: isChecked,
                          onChanged: (v) => setDialogState(
                            () => selected[issue.original.id] = v ?? false,
                          ),
                          dense: true,
                          title: Text(
                            issue.original.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (issue.fixedFormalName !=
                                  issue.original.formalName)
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: '正式: ',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      TextSpan(
                                        text: issue.original.formalName,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const TextSpan(text: ' → '),
                                      TextSpan(
                                        text: issue.fixedFormalName,
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (issue.fixedDisplayName !=
                                  issue.original.displayName)
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: '表示: ',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      TextSpan(
                                        text: issue.original.displayName,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const TextSpan(text: ' → '),
                                      TextSpan(
                                        text: issue.fixedDisplayName,
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                '敬称: ${issue.original.title}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (checkedIssues.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${checkedIssues.length}件を修正します',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: Text('${checkedIssues.length}件を修正'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                ),
                onPressed: checkedIssues.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _applyHonorificsScreening(checkedIssues);
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyHonorificsScreening(List<HonorificsIssue> issues) async {
    try {
      for (final issue in issues) {
        await _customerRepo.saveCustomer(issue.fixed, force: true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${issues.length}件の敬称を修正しました'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _loadCustomers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.selectionMode ? "C2:顧客選択" : "C1:顧客一覧"),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortKey,
              icon: const Icon(Icons.sort, color: Colors.white),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black),
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
          if (!widget.selectionMode) ...[
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'honor_screening') {
                  _showHonorificsScreening();
                } else if (value == 'clean_duplicate') {
                  _cleanDuplicateHonorific();
                } else if (value == 'clean_name') {
                  _cleanHonorificFromName();
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'honor_screening',
                  child: Row(
                    children: [
                      Icon(Icons.manage_search, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('敬称スクリーニング'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'clean_duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, size: 18),
                      SizedBox(width: 8),
                      Text('敬称の重複を削除'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clean_name',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('名前から敬称を削除'),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadCustomers,
            ),
          ],
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
                      subtitle: Text(c.formalName),
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
                              onPressed: () => _addOrEditCustomer(customer: c),
                              tooltip: "編集（電子帳簿保存法対応：ロック中も履歴保存して編集可能）",
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
              enabled: true,
              onTap: () {
                Navigator.pop(context);
                _addOrEditCustomer(customer: c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail),
              title: const Text('連絡先を更新'),
              enabled: true,
              onTap: () {
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
              enabled: true,
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('削除確認（電子帳簿保存法）'),
                    content: Text(
                      '「${c.displayName}」を削除しますか？\n※電子帳簿保存法により、実際の削除は行わずに非表示フラグのみを設定します。履歴は保持されます。',
                    ),
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
                  await _customerRepo.setHidden(c.id, true);
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
                        label: const Text("ロック済み"),
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
                title: Text('電話帳から取り込む'),
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
