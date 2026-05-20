import 'dart:ui';
import 'package:flutter/material.dart';

/// 画面全体を覆うすりガラス（フロストガラス）スワイプアンロックオーバーレイ。
/// 子ウィジェット（コンテンツ）の上に重ねて使用し、
/// ロック中は画面全体を覆い、上にスワイプで解除する。
class SwipeToUnlock extends StatefulWidget {
  final VoidCallback onUnlocked;
  final String lockedText;
  final String unlockedText;
  final IconData lockedIcon;
  final IconData unlockedIcon;
  final bool isLocked;
  final Color? backgroundColor;
  final Color? accentColor;

  const SwipeToUnlock({
    super.key,
    required this.onUnlocked,
    this.lockedText = "画面を上にスワイプして解除",
    this.unlockedText = "解除済",
    this.lockedIcon = Icons.lock,
    this.unlockedIcon = Icons.check_circle,
    this.isLocked = true,
    this.backgroundColor,
    this.accentColor,
  });

  @override
  State<SwipeToUnlock> createState() => _SwipeToUnlockState();
}

class _SwipeToUnlockState extends State<SwipeToUnlock>
    with SingleTickerProviderStateMixin {
  double _dragProgress = 0.0;
  bool _showSuccessOverlay = false;
  bool _isDismissed = false;
  late AnimationController _bounceController;

  static const double _unlockThreshold = 0.6;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bounceController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLocked || _isDismissed) {
      return const SizedBox.shrink();
    }

    final Color accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;
    final double opacity = (0.35 - (_dragProgress * 0.25)).clamp(0.05, 0.35);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (details) {
        if (_showSuccessOverlay) return;
        final screenHeight = MediaQuery.of(context).size.height;
        setState(() {
          _dragProgress += (-details.delta.dy) / (screenHeight * 0.6);
          if (_dragProgress < 0) _dragProgress = 0;
          if (_dragProgress > 1.5) _dragProgress = 1.5;
        });
      },
      onVerticalDragEnd: (details) {
        if (_showSuccessOverlay) return;
        if (_dragProgress >= _unlockThreshold) {
          setState(() {
            _dragProgress = 1.0;
            _showSuccessOverlay = true;
          });
          widget.onUnlocked();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            setState(() => _isDismissed = true);
          });
        } else {
          setState(() => _dragProgress = 0);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        color: Colors.transparent,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 12 + _dragProgress * 18,
              sigmaY: 12 + _dragProgress * 18,
            ),
            child: Container(
              color: Colors.black.withOpacity(opacity),
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _showSuccessOverlay
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  key: const ValueKey('unlocked'),
                                  children: [
                                    Icon(widget.unlockedIcon, color: Theme.of(context).colorScheme.tertiary, size: 64),
                                    const SizedBox(height: 16),
                                    Text(
                                      widget.unlockedText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.15),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        widget.lockedIcon,
                                        color: Colors.white.withOpacity(
                                          (0.85 - _dragProgress * 0.4).clamp(0.4, 0.85),
                                        ),
                                        size: 48 + _dragProgress * 24,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      transform: Matrix4.translationValues(0, -_dragProgress * 80, 0),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _bounceController,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(
                                    0,
                                    -14 * (1 - _bounceController.value) - _dragProgress * 50,
                                  ),
                                  child: Icon(
                                    Icons.keyboard_arrow_up,
                                    color: Colors.white.withOpacity(
                                      (0.7 + _dragProgress * 0.3).clamp(0.0, 1.0),
                                    ),
                                    size: 44 + _dragProgress * 16,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: accent.withOpacity(0.3 + _dragProgress * 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                widget.lockedText,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(
                                    (0.9 + _dragProgress * 0.1).clamp(0.0, 1.0),
                                  ),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 160,
                              child: LinearProgressIndicator(
                                value: _dragProgress.clamp(0, 1),
                                backgroundColor: Colors.white.withOpacity(0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accent.withOpacity(0.9),
                                ),
                                borderRadius: BorderRadius.circular(4),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
