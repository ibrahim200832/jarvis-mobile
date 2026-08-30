import 'package:flutter/material.dart';

import '../theme/jarvis_theme.dart';

/// Subtle, continuous animated sci-fi HUD scanline overlay — thin, softly
/// drifting horizontal lines. First CustomPainter in this codebase; chosen
/// deliberately over stacking many Positioned gradient bars, which is the
/// right tool for one true repeating procedural pattern. Wrapped in
/// IgnorePointer so it never eats taps. Gated behind the
/// "hud_effects_enabled" Einstellung by the caller since continuous
/// repainting has a real, if small, cost.
class ScanlineOverlay extends StatefulWidget {
  const ScanlineOverlay({super.key});

  @override
  State<ScanlineOverlay> createState() => _ScanlineOverlayState();
}

class _ScanlineOverlayState extends State<ScanlineOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(size: Size.infinite, painter: _ScanlinePainter(t: _controller.value)),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  _ScanlinePainter({required this.t});

  final double t;
  static const _spacing = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JarvisColors.accentGlow.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    final offset = t * _spacing;
    for (double y = (offset % _spacing) - _spacing; y < size.height; y += _spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) => oldDelegate.t != t;
}
