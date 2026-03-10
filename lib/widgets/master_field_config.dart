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
  final Widget? suffixWidget;  // バーコードスキャナボタン等
  final String? Function(String)? validator; // カスタムバリデーション

  const MasterFieldConfig({
    required this.key,
    required this.label,
    this.hint,
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.maxLength,
    this.suffixWidget,
    this.validator,
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
