import 'package:flutter/material.dart';

class SlideToUnlock extends StatefulWidget {
  final VoidCallback onUnlocked;
  final String text;
  final bool isLocked;

  const SlideToUnlock({
    Key? key,
    required this.onUnlocked,
    this.text = "スライドして解除",
    this.isLocked = true,
  }) : super(key: key);

  @override
  State<SlideToUnlock> createState() => _SlideToUnlockState();
}

class _SlideToUnlockState extends State<SlideToUnlock> {
  double _position = 0.0;
  final double _thumbSize = 56.0;

  @override
  Widget build(BuildContext context) {
    if (!widget.isLocked) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double trackWidth = (maxWidth - _thumbSize - 12).clamp(0, maxWidth);

        return Container(
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade900,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            children: [
              // 背景テキストとアニメーション効果（簡易）
              Center(
                child: Opacity(
                  opacity: (1 - (_position / trackWidth)).clamp(0.2, 1.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.keyboard_double_arrow_right, color: Colors.white54, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.text,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
              // スライドつまみ
              Positioned(
                left: _position + 4,
                top: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _position += details.delta.dx;
                      if (_position < 0) _position = 0;
                      if (_position > trackWidth) _position = trackWidth;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_position >= trackWidth * 0.95) {
                      widget.onUnlocked();
                      // 成功時はアニメーションで戻すのではなく、状態が変わるのでリセット
                      setState(() => _position = 0);
                    } else {
                      // 失敗時はバネのように戻る（簡易）
                      setState(() => _position = 0);
                    }
                  },
                  child: Container(
                    width: _thumbSize,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.orangeAccent, Colors.deepOrange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: Colors.black45, blurRadius: 4, offset: const Offset(2, 2)),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.key, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
