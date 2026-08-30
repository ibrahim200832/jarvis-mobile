import 'package:flutter/material.dart';

import '../theme/jarvis_theme.dart';

/// Pure, testable flash widget driven by [visible] — a translucent red
/// scrim with "ZUGRIFF VERWEIGERT", shown when a real OS permission request
/// is denied (a visual amplifier on an error path that already exists via
/// the app's snackbar messages, not new logic). See showAccessDeniedFlash()
/// for the self-contained overlay helper that drives this automatically.
class AccessDeniedFlash extends StatelessWidget {
  const AccessDeniedFlash({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          color: JarvisColors.error.withValues(alpha: 0.35),
          alignment: Alignment.center,
          child: const Text(
            'ZUGRIFF VERWEIGERT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 3,
              shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a brief AccessDeniedFlash via a self-managed OverlayEntry — no
/// state needs to be threaded into the calling screen, so it can be called
/// from any Permission.x.request() denial site regardless of which
/// Scaffold (main screen or call screen) is currently shown.
void showAccessDeniedFlash(BuildContext context) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final visible = ValueNotifier<bool>(false);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, value, _) => AccessDeniedFlash(visible: value),
      ),
    ),
  );
  overlay.insert(entry);
  WidgetsBinding.instance.addPostFrameCallback((_) => visible.value = true);
  Future.delayed(const Duration(milliseconds: 900), () => visible.value = false);
  Future.delayed(const Duration(milliseconds: 1300), () {
    entry.remove();
    visible.dispose();
  });
}
