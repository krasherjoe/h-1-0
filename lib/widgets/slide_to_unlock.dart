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
  final double _thumbSize = 50.0;

  @override
  Widget build(BuildContext context) {
    if (!widget.isLocked) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double trackWidth = maxWidth - _thumbSize;

        return Container(
          height: 60,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade100,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  widget.text,
                  style: TextStyle(color: Colors.blueGrey.shade700, fontWeight: FontWeight.bold),
                ),
              ),
              Positioned(
                left: _position,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _position += details.delta.dx;
                      if (_position < 0) _position = 0;
                      if (_position > trackWidth) _position = trackWidth;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_position >= trackWidth * 0.9) {
                      widget.onUnlocked();
                      setState(() => _position = 0); // 念のためリセット
                    } else {
                      setState(() => _position = 0);
                    }
                  },
                  child: Container(
                    width: _thumbSize,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(2, 2)),
                      ],
                    ),
                    child: const Icon(Icons.arrow_forward_ios, color: Colors.white),
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
