import 'package:flutter/material.dart';

import '../models/product_model.dart';

/// 可変な明細行データを保持するフォームモデル。
class LineItemFormData {
  LineItemFormData({
    this.id,
    this.productId,
    String? productName,
    int? quantity,
    int? unitPrice,
    this.taxRate,
    int? costAmount,
    bool? costIsProvisional,
    this.isTaxInclusive = false,
  })  : descriptionController = TextEditingController(text: productName ?? ''),
        quantityController = TextEditingController(text: quantity?.toString() ?? ''),
        unitPriceController = TextEditingController(text: unitPrice?.toString() ?? ''),
        costAmount = costAmount ?? 0,
        costIsProvisional = costIsProvisional ?? true;

  final String? id;
  String? productId;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  double? taxRate;
  int costAmount;
  bool costIsProvisional;
  bool isTaxInclusive;

  bool get hasProduct => productId != null && productId!.isNotEmpty;
  String get description => descriptionController.text;
  int get quantityValue => int.tryParse(quantityController.text) ?? 0;
  int get unitPriceValue => int.tryParse(unitPriceController.text) ?? 0;

  void applyProduct(Product product) {
    productId = product.id;
    descriptionController.text = product.name;
    if (quantityController.text.trim().isEmpty || quantityController.text.trim() == '0') {
      quantityController.text = '1';
    }
    unitPriceController.text = product.defaultUnitPrice.toString();
    costAmount = product.wholesalePrice;
    costIsProvisional = product.wholesalePrice <= 0;
  }

  void registerChangeListener(VoidCallback listener) {
    descriptionController.addListener(listener);
    quantityController.addListener(listener);
    unitPriceController.addListener(listener);
  }

  void removeChangeListener(VoidCallback listener) {
    descriptionController.removeListener(listener);
    quantityController.removeListener(listener);
    unitPriceController.removeListener(listener);
  }

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
  }
}

/// 明細1行分を編集するカード。仕入/売上どちらの画面でも流用できるよう
/// 追加のメタ情報やフッターを挿入できるようにしている。
class LineItemCard extends StatelessWidget {
  const LineItemCard({
    super.key,
    required this.data,
    required this.onPickProduct,
    required this.onRemove,
    this.onToggleTaxInclusive,
    this.meta,
    this.footer,
  });

  final LineItemFormData data;
  final VoidCallback onPickProduct;
  final VoidCallback onRemove;
  final VoidCallback? onToggleTaxInclusive;
  final Widget? meta;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              title: Text(
                data.descriptionController.text.isEmpty ? '商品を選択' : data.descriptionController.text,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: data.hasProduct
                  ? null
                  : Text(
                      '商品マスタから選択してください',
                      style: TextStyle(color: cs.error),
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [meta, const Icon(Icons.chevron_right)]
                    .whereType<Widget>()
                    .toList(growable: false),
              ),
              onTap: onPickProduct,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: data.quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '数量',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    ),
                    scrollPadding: const EdgeInsets.only(bottom: 160),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: data.unitPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: data.isTaxInclusive ? '単価(税込)' : '単価(税抜)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    ),
                    scrollPadding: const EdgeInsets.only(bottom: 160),
                  ),
                ),
                if (onToggleTaxInclusive != null)
                  IconButton(
                    icon: Text(data.isTaxInclusive ? '税込' : '税抜',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: data.isTaxInclusive ? Colors.orange : Colors.grey)),
                    onPressed: onToggleTaxInclusive,
                    tooltip: data.isTaxInclusive ? '税抜きに切替' : '税込みに切替',
                  ),
                IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline), tooltip: '削除'),
              ],
            ),
            ...[
              footer == null ? null : const SizedBox(height: 8),
              footer,
            ].whereType<Widget>(),
          ],
        ),
      ),
    );
  }
}
