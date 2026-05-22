import 'package:flutter/material.dart';

/// Flutter Card のカスタマイズサンプル
/// 参照: https://gakogako.com/flutter_card/
///
/// 基本的な Card のカスタマイズオプション:
/// - color: 背景色
/// - margin: 外側の余白
/// - elevation: 影の高さ
/// - shadowColor: 影の色
/// - shape: RoundedRectangleBorder などで角丸を指定
/// - clipBehavior: Card の形状に合わせて子Widgetをクリップ

/// シンプルなカスタムカード（色・影・角丸）
class ColoredCard extends StatelessWidget {
  const ColoredCard({
    super.key,
    required this.child,
    this.color,
    this.elevation = 8,
    this.shadowColor,
    this.borderRadius = 0,
    this.margin = const EdgeInsets.all(30),
  });

  final Widget child;
  final Color? color;
  final double elevation;
  final Color? shadowColor;
  final double borderRadius;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 200,
      child: Card(
        color: color,
        margin: margin,
        elevation: elevation,
        shadowColor: shadowColor,
        shape: borderRadius > 0
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius))
            : null,
        child: Center(child: child),
      ),
    );
  }
}

/// 画像＋テキストのカード（クリッピング対応）
class ImageCard extends StatelessWidget {
  const ImageCard({
    super.key,
    this.imageUrl,
    this.text,
    this.borderRadius = 20,
    this.margin = const EdgeInsets.all(30),
  });

  final String? imageUrl;
  final String? text;
  final double borderRadius;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 200,
      child: Card(
        margin: margin,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: Row(
          children: <Widget>[
            if (imageUrl != null)
              Image.network(imageUrl!, width: 120, height: 200, fit: BoxFit.cover),
            const Spacer(),
            if (text != null) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(text!, style: const TextStyle(fontSize: 16)),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
