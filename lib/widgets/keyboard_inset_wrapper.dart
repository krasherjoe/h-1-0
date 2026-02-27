import 'package:flutter/material.dart';

/// Wraps content with SafeArea and animated bottom padding based on keyboard.
/// Use this to keep forms scrollable without Scaffold resizing.
class KeyboardInsetWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsets basePadding;
  final double extraBottom;
  final Duration duration;
  final Curve curve;

  const KeyboardInsetWrapper({
    super.key,
    required this.child,
    this.basePadding = EdgeInsets.zero,
    this.extraBottom = 0,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOut,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: AnimatedPadding(
        duration: duration,
        curve: curve,
        padding: basePadding.add(EdgeInsets.only(bottom: bottomInset + extraBottom)),
        child: child,
      ),
    );
  }
}
