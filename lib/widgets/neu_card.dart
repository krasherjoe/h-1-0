import 'package:flutter/material.dart';

/// ニューモーフィズム（Neumorphism / Soft UI）カード
/// 使い方:
/// ```dart
/// NeuCard(
///   icon: Icons.rocket_launch,
///   title: 'タイトル',
///   description: '説明文が入ります',
///   onTap: () {},
/// )
/// ```
class NeuCard extends StatelessWidget {
  const NeuCard({
    super.key,
    this.icon,
    this.title,
    this.description,
    this.width,
    this.onTap,
  });

  final IconData? icon;
  final String? title;
  final String? description;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? MediaQuery.of(context).size.width * 0.4,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.only(top: 30, bottom: 30),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(blurRadius: 10, offset: Offset(-10, -10), color: Colors.white24),
            BoxShadow(blurRadius: 10, offset: Offset(10, 10), color: Colors.grey),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.black45, size: 48),
                const SizedBox(height: 8),
              ],
              if (title != null) ...[
                Text(title!, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
              ],
              if (description != null)
                Text(description!, style: TextStyle(fontSize: 15, color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }
}
