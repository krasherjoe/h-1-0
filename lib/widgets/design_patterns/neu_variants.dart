import 'dart:ui';
import 'package:flutter/material.dart';

/// ニューモーフィズムバリエーション
/// メタリック・ガラスなど素材感のあるカード

/// メタリックシルバーカード
class MetallicCard extends StatelessWidget {
  const MetallicCard({
    super.key,
    this.icon,
    this.title,
    this.description,
    this.gold = false,
  });

  final IconData? icon;
  final String? title;
  final String? description;
  final bool gold; // true=ゴールド, false=シルバー

  @override
  Widget build(BuildContext context) {
    final colors = gold
        ? const [Color(0xFFD4A849), Color(0xFFF2D780)]
        : const [Color(0xFFD8D8D8), Color(0xFFF0F0F0)];
    final shadowLight = gold
        ? const Color(0x66FFFFC8)
        : Colors.white.withValues(alpha: 0.5);
    final shadowDark = gold
        ? const Color(0x4D644600)
        : Colors.black.withValues(alpha: 0.3);
    return Container(
      width: 280,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.only(top: 30, bottom: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(blurRadius: 10, offset: const Offset(-10, -10), color: shadowLight),
          BoxShadow(blurRadius: 10, offset: const Offset(10, 10), color: shadowDark),
        ],
      ),
      child: Column(
        children: [
          if (icon != null) Icon(icon, color: gold ? const Color(0xFF8A6A1A) : Colors.grey[600], size: 48),
          if (icon != null) const SizedBox(height: 8),
          if (title != null) Text(title!, style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: gold ? const Color(0xFF5C4500) : Colors.grey[800],
          )),
          if (title != null) const SizedBox(height: 8),
          if (description != null)
            Text(description!, style: TextStyle(fontSize: 15, color: gold ? const Color(0xFF5C4500) : Colors.grey[600])),
        ],
      ),
    );
  }
}

/// ガラスモーフィズムカード（半透明＋ぼかし）
/// 背景にグラデーションのある親Widgetの上に置くこと
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.icon,
    this.title,
    this.description,
    this.width = 280,
  });

  final IconData? icon;
  final String? title;
  final String? description;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: width,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.only(top: 30, bottom: 30),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              if (icon != null) Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 48),
              if (icon != null) const SizedBox(height: 8),
              if (title != null) Text(title!, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
              if (title != null) const SizedBox(height: 8),
              if (description != null)
                Text(description!, style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

/// グラデーション背景＋GlassCard のセット
class GlassCardExample extends StatelessWidget {
  const GlassCardExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 304,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: const GlassCard(
        icon: Icons.water_drop,
        title: 'Glassmorphism',
        description: 'ガラス風\nぼかし＋半透明＋グラデ背景',
      ),
    );
  }
}
