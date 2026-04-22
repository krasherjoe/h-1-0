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
  bool _isDismissed = false;
  late AnimationController _bounceController;

  static const double _unlockThreshold = 0.25;

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

    final Color accent = widget.accentColor ?? Colors.indigo.shade400;
    final double opacity = (0.55 - (_dragProgress * 0.55)).clamp(0.0, 0.55);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (details) {
        if (_showSuccessOverlay) return;
        final screenHeight = MediaQuery.of(context).size.height;
        setState(() {
          _dragProgress += (-details.delta.dy) / (screenHeight * 0.4);
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
                              Icon(widget.unlockedIcon, color: Colors.green, size: 64),
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
                        : Icon(
                            widget.lockedIcon,
                            color: Colors.white.withOpacity(
                              (0.8 - _dragProgress * 0.5).clamp(0.3, 0.8),
                            ),
                            size: 48 + _dragProgress * 24,
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
                      Text(
                        widget.lockedText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(
                            (0.85 + _dragProgress * 0.15).clamp(0.0, 1.0),
                          ),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 160,
                        child: LinearProgressIndicator(
                          value: _dragProgress.clamp(0, 1),
                          backgroundColor: Colors.white.withOpacity(0.2),
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
    );
  }
}
