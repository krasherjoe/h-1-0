import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:uuid/uuid.dart';
import '../models/supplier_model.dart';
import '../services/supplier_repository.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/master_field_config.dart';
import '../widgets/rich_master_edit_sheet.dart';
import 'supplier_phonebook_selection_screen.dart';

/// 仕入先一覧画面
class SupplierMasterScreen extends StatefulWidget {
  const SupplierMasterScreen({super.key});

  @override
  State<SupplierMasterScreen> createState() => _SupplierMasterScreenState();
}

class _SupplierMasterScreenState extends State<SupplierMasterScreen> {
  final SupplierRepository _repo = SupplierRepository();

  Future<void> _showEditDialog({Supplier? supplier}) async {
    const allowedTitles = ['様', '御中', '殿', '貴社'];

    String normalizeTitle(String? raw) {
      if (raw == null || raw.isEmpty) {
        return allowedTitles.first;
      }
      return allowedTitles.contains(raw) ? raw : allowedTitles.first;
    }

    bool isCompanyTitle(String title) => title == '御中' || title == '貴社';

    Future<void> prefillFromContacts(
      BuildContext actionContext,
      RichMasterEditController controller,
    ) async {
      final result = await Navigator.push<Map<String, dynamic>>(
        actionContext,
        MaterialPageRoute(
          builder: (context) => const SupplierPhonebookSelectionScreen(),
        ),
      );

      if (result != null && actionContext.mounted) {
        controller.updateValue('displayName', result['displayName'] ?? '', refresh: false);
        controller.updateValue('formalName', result['formalName'] ?? '', refresh: false);
        controller.updateValue('contactPerson', result['contactPerson'] ?? '', refresh: false);
        controller.updateValue('tel', result['tel'] ?? '', refresh: false);
        controller.updateValue('email', result['email'] ?? '', refresh: false);
        controller.updateValue('address', result['address'] ?? '', refresh: false);
        controller.refresh();
      }
    }

    Future<void> pickPaymentTemplate(
      BuildContext actionContext,
      RichMasterEditController controller,
    ) async {
      final templates = const [
        _PaymentTemplate('末締め翌末払い', '月末締め翌月末払い', '31', '30'),
        _PaymentTemplate('20日締め翌15日払い', '20日締め翌月15日払い', '20', '25'),
        _PaymentTemplate('即時払い', '納品後即時払い', '', '0'),
      ];

      final selected = await showModalBottomSheet<_PaymentTemplate>(
        context: actionContext,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: templates
                .map((t) => ListTile(
                      leading: const Icon(Icons.view_list),
                      title: Text(t.title),
                      subtitle: Text(t.description),
                      onTap: () => Navigator.pop(ctx, t),
                    ))
                .toList(),
          ),
        ),
      );

      if (selected == null) return;

      controller.updateValue('paymentTerms', selected.description, refresh: false);
      controller.updateValue('closingDay', selected.closingDay, refresh: false);
      controller.updateValue('paymentSiteDays', selected.paymentSiteDays, refresh: false);
      controller.refresh();
    }

    final sections = [
      RichMasterSection(
        title: '基本情報',
        description: '表示名や正式名称・法人区分を設定します',
        fields: const [
          MasterFieldConfig(
            key: 'displayName',
            label: '表示名（略称）',
            hint: '例: 佐々木製作所',
            required: true,
          ),
          MasterFieldConfig(
            key: 'formalName',
            label: '正式名称',
            hint: '例: 株式会社 佐々木製作所',
            required: true,
          ),
        ],
        accessories: [
          (ctx, controller) {
            final isCompany = controller.valueOf('companyFlag') != 'individual';
            final currentTitle = controller.valueOf('title');
            final title = allowedTitles.contains(currentTitle) ? currentTitle : allowedTitles.first;
            if (currentTitle != title) {
              controller.updateValue('title', title, refresh: false);
            }
            return Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('法人')),
                      ButtonSegment(value: false, label: Text('個人')),
                    ],
                    selected: {isCompany},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) {
                      if (values.isEmpty) return;
                      final nextIsCompany = values.first;
                      controller.updateValue('companyFlag', nextIsCompany ? 'company' : 'individual', refresh: false);
                      controller.updateValue('title', nextIsCompany ? '御中' : '様', refresh: false);
                      controller.refresh();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: title,
                    decoration: const InputDecoration(labelText: '敬称', border: OutlineInputBorder()),
                    items: allowedTitles
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      final nextTitle = val ?? '様';
                      controller.updateValue('title', nextTitle, refresh: false);
                      controller.updateValue(
                        'companyFlag',
                        (nextTitle == '御中' || nextTitle == '貴社') ? 'company' : 'individual',
                        refresh: false,
                      );
                      controller.refresh();
                    },
                  ),
                ),
              ],
            );
          },
        ],
      ),
      RichMasterSection(
        title: '連絡先・所在地',
        description: '担当者・部署・住所・連絡先を入力します',
        fields: const [
          MasterFieldConfig(
            key: 'contactPerson',
            label: '担当者',
            hint: '例: 山田 太郎',
          ),
          MasterFieldConfig(
            key: 'department',
            label: '部署',
            hint: '例: 営業部',
          ),
          MasterFieldConfig(
            key: 'address',
            label: '住所',
            hint: '例: 東京都千代田区1-2-3',
            maxLines: 2,
            flex: 2,
          ),
          MasterFieldConfig(
            key: 'tel',
            label: '電話番号',
            keyboardType: TextInputType.phone,
          ),
          MasterFieldConfig(
            key: 'email',
            label: 'メールアドレス',
            keyboardType: TextInputType.emailAddress,
          ),
        ],
        accessories: [
          (ctx, controller) => Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.contact_phone),
                  label: const Text('電話帳から取得'),
                  onPressed: () => prefillFromContacts(ctx, controller),
                ),
              ),
        ],
      ),
      RichMasterSection(
        title: '支払条件・銀行口座',
        description: '締め日や支払サイト、銀行情報を整理します',
        fields: const [
          MasterFieldConfig(
            key: 'paymentTerms',
            label: '支払条件',
            hint: '例: 月末締め翌月末払い',
            maxLines: 2,
          ),
          MasterFieldConfig(
            key: 'bankAccount',
            label: '銀行口座',
            hint: '例: ○○銀行 △△支店 普通 1234567',
            maxLines: 2,
          ),
          MasterFieldConfig(
            key: 'closingDay',
            label: '締め日',
            hint: '例: 31',
            keyboardType: TextInputType.number,
          ),
          MasterFieldConfig(
            key: 'paymentSiteDays',
            label: '支払サイト（日）',
            hint: '例: 30',
            keyboardType: TextInputType.number,
          ),
        ],
        accessories: [
          (ctx, controller) => Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.view_list),
                  label: const Text('テンプレート適用'),
                  onPressed: () => pickPaymentTemplate(ctx, controller),
                ),
              ),
        ],
      ),
      RichMasterSection(
        title: '社内共有メモ',
        description: '現場メモや注意事項を残しておきましょう',
        fields: const [
          MasterFieldConfig(
            key: 'notes',
            label: '備考',
            maxLines: 4,
            flex: 2,
          ),
        ],
      ),
    ];

    final result = await showRichMasterEditSheet<Supplier>(
      context: context,
      titleNew: '仕入先を新規登録',
      titleEdit: '仕入先を編集',
      existing: supplier,
      sections: sections,
      headerActions: [
        (ctx, controller) => OutlinedButton.icon(
              icon: const Icon(Icons.contact_phone_outlined),
              label: const Text('電話帳参照'),
              onPressed: () => prefillFromContacts(ctx, controller),
            ),
        (ctx, controller) => OutlinedButton.icon(
              icon: const Icon(Icons.view_list_outlined),
              label: const Text('支払テンプレ'),
              onPressed: () => pickPaymentTemplate(ctx, controller),
            ),
      ],
      initialValuesBuilder: (s) => {
        'displayName': s?.displayName ?? '',
        'formalName': s?.formalName ?? '',
        'contactPerson': s?.contactPerson ?? '',
        'department': s?.department ?? '',
        'address': s?.address ?? '',
        'tel': s?.tel ?? '',
        'email': s?.email ?? '',
        'paymentTerms': s?.paymentTerms ?? '',
        'bankAccount': s?.bankAccount ?? '',
        'closingDay': s?.closingDay?.toString() ?? '',
        'paymentSiteDays': s?.paymentSiteDays.toString() ?? '30',
        'notes': s?.notes ?? '',
        'title': normalizeTitle(s?.title),
        'companyFlag': isCompanyTitle(normalizeTitle(s?.title)) ? 'company' : 'individual',
      },
      previewBuilder: (ctx, controller) => SupplierPreviewCard(
        displayName: controller.valueOf('displayName'),
        formalName: controller.valueOf('formalName'),
        contactPerson: controller.valueOf('contactPerson'),
        department: controller.valueOf('department'),
        tel: controller.valueOf('tel'),
        email: controller.valueOf('email'),
        paymentTerms: controller.valueOf('paymentTerms'),
        bankAccount: controller.valueOf('bankAccount'),
        closingDay: controller.valueOf('closingDay'),
        paymentSiteDays: controller.valueOf('paymentSiteDays'),
      ),
      buildModel: (values) {
        final closingDay = int.tryParse(values['closingDay'] ?? '');
        final paymentSiteDays = int.tryParse(values['paymentSiteDays'] ?? '') ?? 30;
        return Supplier(
          id: supplier?.id ?? const Uuid().v4(),
          displayName: values['displayName']?.trim() ?? '',
          formalName: values['formalName']?.trim() ?? '',
          title: values['title']?.trim() ?? '様',
          contactPerson: values['contactPerson']?.trim().isEmpty ?? true
              ? null
              : values['contactPerson']!.trim(),
          department:
              values['department']?.trim().isEmpty ?? true ? null : values['department']!.trim(),
          address: values['address']?.trim().isEmpty ?? true ? null : values['address']!.trim(),
          tel: values['tel']?.trim().isEmpty ?? true ? null : values['tel']!.trim(),
          email: values['email']?.trim().isEmpty ?? true ? null : values['email']!.trim(),
          paymentTerms: values['paymentTerms']?.trim().isEmpty ?? true
              ? null
              : values['paymentTerms']!.trim(),
          bankAccount: values['bankAccount']?.trim().isEmpty ?? true
              ? null
              : values['bankAccount']!.trim(),
          closingDay: closingDay,
          paymentSiteDays: paymentSiteDays,
          notes: values['notes']?.trim().isEmpty ?? true ? null : values['notes']!.trim(),
        );
      },
      onValidate: (values) async {
        final incomingFormal = (values['formalName'] ?? '').trim();
        if (incomingFormal.isEmpty) {
          return '正式名称は必須です';
        }
        if (supplier == null || supplier.formalName != incomingFormal) {
          final existing = await _repo.getAllSuppliers();
          final duplicate = existing.any((s) => s.formalName.toLowerCase() == incomingFormal.toLowerCase());
          if (duplicate) {
            return '同一正式名称の仕入先が既に存在します';
          }
        }
        return null;
      },
    );

    if (result != null) {
      await _repo.saveSupplier(result);
      if (mounted) {
        setState(() {}); // 仕入先保存後にStateを更新する
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return GenericListScreen<Supplier>(
      screenId: 'SUP',
      title: '仕入先マスタ',
      icon: Icons.business,
      themeColor: Theme.of(context).colorScheme.secondary,

      // データ取得
      fetchData: () => _repo.getAllSuppliers(),

      // カード表示
      buildCard: (context, supplier, onRefresh) {
        return DocumentCard(
          title: supplier.displayName,
          subtitle: supplier.contactPerson ?? '',
          amount: '',
          date: supplier.updatedAt,
          status: DocumentStatus.confirmed,
          themeColor: Theme.of(context).colorScheme.secondary,
          onTap: () {
            _showEditDialog(supplier: supplier);
          },
          actions: [
            CardAction(
              label: '編集',
              icon: Icons.edit,
              onPressed: () {
                _showEditDialog(supplier: supplier);
              },
            ),
            CardAction(
              label: '削除',
              icon: Icons.delete,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('確認'),
                    content: const Text('この仕入先を削除しますか？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('キャンセル'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('削除'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  try {
                    await _repo.deleteSupplier(supplier.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('仕入先を削除しました')),
                      );
                    }
                    onRefresh();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('削除に失敗しました: $e')),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },

      // フィルタ
      filters: [
        FilterOption(
          label: '全て',
          value: 'all',
          filter: (suppliers) => suppliers,
        ),
        FilterOption(
          label: '非表示',
          value: 'hidden',
          filter: (suppliers) => suppliers
              .where((s) => s.isHidden)
              .toList(),
        ),
      ],

      // 新規作成
      onCreateNew: () async {
        _showEditDialog();
      },

      // 空状態
      emptyWidget: EmptyStateWidget(
        icon: Icons.business,
        title: '仕入先がありません',
        subtitle: '新しい仕入先を登録してください',
        actionLabel: '新規仕入先',
        iconColor: Theme.of(context).colorScheme.secondary,
        onAction: () {
          _showEditDialog();
        },
      ),
    );
  }
}

class SupplierPreviewCard extends StatelessWidget {
  final String displayName;
  final String formalName;
  final String contactPerson;
  final String department;
  final String tel;
  final String email;
  final String paymentTerms;
  final String bankAccount;
  final String closingDay;
  final String paymentSiteDays;

  const SupplierPreviewCard({
    super.key,
    required this.displayName,
    required this.formalName,
    required this.contactPerson,
    required this.department,
    required this.tel,
    required this.email,
    required this.paymentTerms,
    required this.bankAccount,
    required this.closingDay,
    required this.paymentSiteDays,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <_PreviewRow>[
      _PreviewRow('表示名', displayName),
      _PreviewRow('正式名称', formalName),
      _PreviewRow('担当部署/担当者', [department, contactPerson].where((v) => v.isNotEmpty).join(' / ')),
      _PreviewRow('電話番号', tel),
      _PreviewRow('メール', email),
      _PreviewRow('支払条件', paymentTerms),
      _PreviewRow('銀行口座', bankAccount),
      _PreviewRow('締め日', closingDay),
      _PreviewRow('支払サイト', paymentSiteDays.isEmpty ? '' : '$paymentSiteDays 日'),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
Row(
              children: [
                Icon(Icons.preview_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('保存前プレビュー', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...rows.map((row) => _buildRow(row, context)),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(_PreviewRow row, BuildContext ctx) {
    final value = row.value.trim();
    final isEmpty = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(row.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              isEmpty ? '—' : value,
              style: TextStyle(color: isEmpty ? Theme.of(ctx).colorScheme.onSurfaceVariant : Theme.of(ctx).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow {
  final String label;
  final String value;
  const _PreviewRow(this.label, this.value);
}

class _PaymentTemplate {
  final String title;
  final String description;
  final String closingDay;
  final String paymentSiteDays;

  const _PaymentTemplate(this.title, this.description, this.closingDay, this.paymentSiteDays);
}
