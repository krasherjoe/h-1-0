import 'package:flutter/material.dart';

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
  late AnimationController _bounceController;

  static const double _unlockThreshold = 0.35;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
    if (!widget.isLocked) return const SizedBox.shrink();

    final Color background = widget.backgroundColor ?? Colors.blueGrey.shade900;
    final Color accent = widget.accentColor ?? Colors.indigo.shade400;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (_showSuccessOverlay) return;
        final screenHeight = MediaQuery.of(context).size.height;
        setState(() {
          _dragProgress += (-details.delta.dy) / (screenHeight * 0.5);
          if (_dragProgress < 0) _dragProgress = 0;
          if (_dragProgress > 1.2) _dragProgress = 1.2;
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
          Future.delayed(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            setState(() {
              _dragProgress = 0;
              _showSuccessOverlay = false;
            });
          });
        } else {
          setState(() => _dragProgress = 0);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 140 + (_dragProgress * 100).clamp(0, 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: background.withValues(
            alpha: 0.6 + (_dragProgress * 0.35).clamp(0, 0.35),
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accent.withValues(alpha: 0.3 + _dragProgress * 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: _dragProgress * 0.4),
              blurRadius: 12 + _dragProgress * 20,
              offset: Offset(0, -4 * _dragProgress),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 背景グラデーション（スワイプ進行に応じて）
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        accent.withValues(alpha: _dragProgress * 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // 中央コンテンツ
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _showSuccessOverlay
                      ? Row(
                          key: const ValueKey('unlocked'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(widget.unlockedIcon, color: Colors.green, size: 32),
                            const SizedBox(width: 8),
                            Text(
                              widget.unlockedText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          key: const ValueKey('locked'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _bounceController,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, -8 * (1 - _bounceController.value) - _dragProgress * 30),
                                  child: Icon(
                                    Icons.keyboard_arrow_up,
                                    color: Colors.white.withValues(
                                      alpha: 0.7 + _dragProgress * 0.3,
                                    ),
                                    size: 36 + _dragProgress * 12,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.lockedIcon,
                                  color: Colors.white.withValues(
                                    alpha: 0.8 + _dragProgress * 0.2,
                                  ),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.lockedText,
                                  style: TextStyle(
                                    color: Colors.white.withValues(
                                      alpha: 0.85 + _dragProgress * 0.15,
                                    ),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 進行バー
                            SizedBox(
                              width: 120,
                              child: LinearProgressIndicator(
                                value: _dragProgress.clamp(0, 1),
                                backgroundColor: Colors.white.withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accent.withValues(alpha: 0.9),
                                ),
                                borderRadius: BorderRadius.circular(4),
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
    );
  }
}
