import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/jarvis_theme.dart';

/// Frosted "iOS glass" surface — a blurred, translucent panel with a
/// hairline border, mirroring the `.glass`/`.glass-strong` utility classes
/// from the companion AETHER web redesign.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.strong = false,
    this.padding,
    this.boxShadow,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final bool strong;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: boxShadow),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: strong ? 24 : 16, sigmaY: strong ? 24 : 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: strong ? JarvisColors.glassFillStrong : JarvisColors.glassFill,
              borderRadius: borderRadius,
              border: Border.all(color: JarvisColors.border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
