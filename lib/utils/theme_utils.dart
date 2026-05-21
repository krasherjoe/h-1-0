import 'package:flutter/material.dart';
import '../models/invoice_models.dart' show DocumentType;

/// 背景色に対して読みやすいテキスト色（白 or 濃いネイビー）を返す。
/// WCAG 最低 AA 基準（4.5:1）を意識した閾値を使用。
Color appBarForeground(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : const Color(0xFF1A1A2E); // near-black navy（純黒より読みやすい）
}

/// 伝票種別ごとの AppBar 背景色（テーマ対応・ダークモード対応）。
/// AppBar、タイトルバー等に使用する。
Color documentTypeColor(DocumentType type, ColorScheme cs, bool isDark) {
  final base = switch (type) {
    DocumentType.estimation => cs.primary,
    DocumentType.order => cs.secondary,
    DocumentType.delivery => cs.tertiary,
    DocumentType.invoice => cs.error,
    DocumentType.receipt => const Color(0xFF388E3C),
  };
  if (isDark) {
    return HSLColor.fromColor(base).withLightness(0.18).toColor();
  }
  return base;
}

/// 伝票種別ごとのバッジ・アイコン固定色（テーマ非依存）。
/// カードやチップのアイコン色に使用する。
Color documentTypeBadgeColor(DocumentType type) {
  return switch (type) {
    DocumentType.estimation => const Color(0xFF1976D2),
    DocumentType.order => const Color(0xFF7B1FA2),
    DocumentType.delivery => const Color(0xFFF57C00),
    DocumentType.invoice => const Color(0xFFD32F2F),
    DocumentType.receipt => const Color(0xFF388E3C),
  };
}
