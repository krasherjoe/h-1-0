import 'package:flutter/material.dart';

/// マスタ編集ダイアログのフィールド定義
class MasterFieldConfig {
  final String key;            // モデルフィールド名
  final String label;          // 表示ラベル
  final String? hint;          // ヒント
  final bool required;         // 必須フラグ
  final TextInputType keyboardType;
  final int maxLines;          // 備考欄など
  final int? maxLength;        // インデックス文字(1文字)など
  final int flex;              // レイアウト: 1=半幅, 2=全幅
  final Widget? suffixWidget;  // 静的なサフィックスウィジェット
  final Widget Function(
    TextEditingController controller,
    StateSetter setDialogState,
    void Function(String value) updateValue,
  )? suffixBuilder; // 動的サフィックス（例: スキャナ）
  final String? Function(String)? validator; // カスタムバリデーション
  final List<String>? dropdownOptions; // ドロップダウン選択肢（指定時はDropdownButtonFormFieldを描画）

  const MasterFieldConfig({
    required this.key,
    required this.label,
    this.hint,
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.maxLength,
    this.flex = 1,
    this.suffixWidget,
    this.suffixBuilder,
    this.validator,
    this.dropdownOptions,
  });
}

/// セグメント・ドロップダウン等の特殊UIグループ
class MasterFieldGroup {
  final String key;
  final String label;
  final MasterFieldType type;  // segment, dropdown, row
  final List<String> options;  // セグメント/ドロップダウンの選択肢
  final List<MasterFieldConfig>? children; // row内のフィールド

  const MasterFieldGroup({
    required this.key,
    required this.label,
    required this.type,
    required this.options,
    this.children,
  });
}

/// フィールドタイプ
enum MasterFieldType {
  segment,    // SegmentedButton
  dropdown,   // DropdownButtonFormField
  row,        // Row内に複数フィールド
}
