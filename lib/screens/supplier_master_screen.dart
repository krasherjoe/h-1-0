import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/supplier_model.dart';
import '../services/supplier_repository.dart';
import '../widgets/generic_list_screen.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/generic_master_edit_dialog.dart';
import '../widgets/master_field_config.dart';

/// 仕入先一覧画面
class SupplierMasterScreen extends StatefulWidget {
  const SupplierMasterScreen({super.key});

  @override
  State<SupplierMasterScreen> createState() => _SupplierMasterScreenState();
}

class _SupplierMasterScreenState extends State<SupplierMasterScreen> {
  final SupplierRepository _repo = SupplierRepository();

  Future<void> _showEditDialog({Supplier? supplier}) async {
    final result = await showMasterEditDialog<Supplier>(
      context: context,
      titleNew: '仕入先を新規登録',
      titleEdit: '仕入先を編集',
      existing: supplier,
      fields: [
        MasterFieldConfig(
          key: 'displayName',
          label: '表示名',
          hint: '例: 佐々木製作所',
          required: true,
        ),
        MasterFieldConfig(
          key: 'formalName',
          label: '正式名称',
          hint: '例: 株式会社 佐々木製作所',
          required: true,
        ),
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
          hint: '例: ○○市△△町1-2-3',
        ),
        MasterFieldConfig(
          key: 'tel',
          label: '電話番号',
          keyboardType: TextInputType.phone,
        ),
        MasterFieldConfig(
          key: 'email',
          label: 'メール',
          keyboardType: TextInputType.emailAddress,
        ),
        MasterFieldConfig(
          key: 'paymentTerms',
          label: '支払条件',
          hint: '例: 月末締め翌月末払い',
        ),
        MasterFieldConfig(
          key: 'bankAccount',
          label: '銀行口座',
          hint: '例: ○○銀行 △△支店 普通口座 1234567',
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
        MasterFieldConfig(
          key: 'notes',
          label: '備考',
          maxLines: 3,
        ),
      ],
      groups: [
        MasterFieldGroup(
          key: 'title',
          label: '敬称',
          type: MasterFieldType.dropdown,
          options: ['様', '御中', '殿', '貴社'],
        ),
      ],
      initialValues: (s) => {
        'displayName': s?.displayName ?? '',
        'formalName': s?.formalName ?? '',
        'title': s?.title ?? '様',
        'department': s?.department ?? '',
        'address': s?.address ?? '',
        'tel': s?.tel ?? '',
        'email': s?.email ?? '',
        'contactPerson': s?.contactPerson ?? '',
        'paymentTerms': s?.paymentTerms ?? '',
        'bankAccount': s?.bankAccount ?? '',
        'closingDay': s?.closingDay?.toString() ?? '',
        'paymentSiteDays': s?.paymentSiteDays.toString() ?? '30',
        'notes': s?.notes ?? '',
      },
      buildModel: (values) => Supplier(
        id: supplier?.id ?? const Uuid().v4(),
        displayName: values['displayName'],
        formalName: values['formalName'],
        title: values['title'],
        department: values['department']?.isEmpty ? null : values['department'],
        address: values['address']?.isEmpty ? null : values['address'],
        tel: values['tel']?.isEmpty ? null : values['tel'],
        email: values['email']?.isEmpty ? null : values['email'],
        contactPerson: values['contactPerson']?.isEmpty ? null : values['contactPerson'],
        paymentTerms: values['paymentTerms']?.isEmpty ? null : values['paymentTerms'],
        bankAccount: values['bankAccount']?.isEmpty ? null : values['bankAccount'],
        closingDay: values['closingDay']?.isEmpty ? null : int.tryParse(values['closingDay']),
        paymentSiteDays: values['paymentSiteDays']?.isEmpty ? 30 : int.tryParse(values['paymentSiteDays']) ?? 30,
        notes: values['notes']?.isEmpty ? null : values['notes'],
      ),
      onValidate: (values) async {
        // 重複チェック（正式名称）
        if (supplier == null || supplier.formalName != values['formalName']) {
          final existing = await _repo.getAllSuppliers();
          final duplicate = existing.any((s) => 
            s.formalName.toLowerCase() == values['formalName'].toString().toLowerCase()
          );
          if (duplicate) {
            return '同一正式名称の仕入先が既に存在します';
          }
        }
        return null;
      },
    );

    if (result != null) {
      await _repo.saveSupplier(result);
      // GenericListScreenのリフレッシュは自動で行われる
    }
  }
  @override
  Widget build(BuildContext context) {
    return GenericListScreen<Supplier>(
      screenId: 'S1',
      title: '仕入先',
      icon: Icons.business,
      themeColor: Colors.orange,

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
          themeColor: Colors.orange,
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
        iconColor: Colors.orange,
        onAction: () {
          _showEditDialog();
        },
      ),
    );
  }
}
