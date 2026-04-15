import 'package:flutter/material.dart';

/// ピンチインアウトとタイトルバースワイプでズームできるAppBarラッパー
///
/// 機能：
/// - ピンチインアウト（2本指での拡大縮小）
/// - タイトルバー左右スワイプでのズーム
///
/// 使用方法：
/// ```dart
/// ZoomableAppBar(
///   appBar: AppBar(title: Text('C2:顧客編集')),
///   child: YourContent(),
/// )
/// ```
class ZoomableAppBar extends StatefulWidget {
  final PreferredSizeWidget appBar;
  final Widget child;
  final double minScale;
  final double maxScale;
  final double scaleStep;

  const ZoomableAppBar({
    super.key,
    required this.appBar,
    required this.child,
    this.minScale = 0.5,
    this.maxScale = 2.0,
    this.scaleStep = 0.1,
  });

  @override
  State<ZoomableAppBar> createState() => _ZoomableAppBarState();
}

class _ZoomableAppBarState extends State<ZoomableAppBar> {
  double _scale = 1.0;
  double _startScale = 1.0;
  double _startX = 0.0;

  // 水平スワイプでのズーム処理
  void _handleHorizontalDragStart(DragStartDetails details) {
    _startScale = _scale;
    _startX = details.globalPosition.dx;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    final deltaX = details.globalPosition.dx - _startX;
    // 右スワイプ：ズームアップ、左スワイプ：ズームダウン（感度4倍）
    final scaleChange = deltaX / 50 * widget.scaleStep;
    _scale = (_startScale + scaleChange).clamp(
      widget.minScale,
      widget.maxScale,
    );
    setState(() {});
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    // スワイプ終了時にスケールを固定
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // AppBarをGestureDetectorでラップしてタイトルバースワイプ対応
    final wrappedAppBar = PreferredSize(
      preferredSize: widget.appBar.preferredSize,
      child: GestureDetector(
        onHorizontalDragStart: _handleHorizontalDragStart,
        onHorizontalDragUpdate: _handleHorizontalDragUpdate,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        behavior: HitTestBehavior.translucent,
        child: widget.appBar,
      ),
    );

    return Scaffold(
      appBar: wrappedAppBar,
      body: GestureDetector(
        // ピンチインアウト（拡大縮小）ジェスチャー
        behavior: HitTestBehavior.translucent,
        onScaleStart: (details) {
          _startScale = _scale;
        },
        onScaleUpdate: (details) {
          _scale = (_startScale * details.scale).clamp(
            widget.minScale,
            widget.maxScale,
          );
          setState(() {});
        },
        onScaleEnd: (details) {
          setState(() {});
        },
        // body左右スワイプでのズーム
        onHorizontalDragStart: _handleHorizontalDragStart,
        onHorizontalDragUpdate: _handleHorizontalDragUpdate,
        onHorizontalDragEnd: _handleHorizontalDragEnd,
        child: Transform.scale(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}

/// 編集画面で使用するズーム可能なScaffoldのヘルパーメソッド
///
/// 既存の編集画面を簡単にズーム対応にするためのヘルパー
class ZoomableEditScreen extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final double minScale;
  final double maxScale;

  const ZoomableEditScreen({
    super.key,
    required this.title,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.minScale = 0.5,
    this.maxScale = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return ZoomableAppBar(
      minScale: minScale,
      maxScale: maxScale,
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      child: body,
    );
  }
}
