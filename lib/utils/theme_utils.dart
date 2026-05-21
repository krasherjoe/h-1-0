import 'package:flutter/material.dart';

/// 背景色に対して読みやすいテキスト色（白 or 濃いネイビー）を返す。
/// WCAG 最低 AA 基準（4.5:1）を意識した閾値を使用。
Color appBarForeground(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : const Color(0xFF1A1A2E); // near-black navy（純黒より読みやすい）
}
