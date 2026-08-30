import 'package:flutter/material.dart';

/// A small pulsing status-indicator dot — replaces a static "online" dot
/// with a subtle sci-fi HUD blink. Same AnimationController+FadeTransition
/// idiom as voice_orb_overlay.dart.
class BlinkingDot extends StatefulWidget {
  const BlinkingDot({super.key, required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  State<BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<BlinkingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.35,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}
