import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'tts_service.dart';

/// Entry point for the small "Ja, Master"-popup that appears over other apps
/// the instant the "Jarvis" wake word is heard (see wake_word_task_handler.dart,
/// which calls FlutterOverlayWindow.showOverlay() instead of opening the full
/// app). Runs in its own, separate Flutter engine — same mechanism as the
/// wake-word background isolate, so plugins like flutter_tts work the same
/// way here as they already do there.
@pragma('vm:entry-point')
void wakeWordOverlayMain() {
  runApp(const WakeWordOverlayApp());
}

class WakeWordOverlayApp extends StatefulWidget {
  const WakeWordOverlayApp({super.key});

  @override
  State<WakeWordOverlayApp> createState() => _WakeWordOverlayAppState();
}

class _WakeWordOverlayAppState extends State<WakeWordOverlayApp> {
  final _tts = TtsService();
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_tts.speak('Ja, Meister?'));
    // Verschwindet von selbst, falls man nicht antippt — soll kurz auf sich
    // aufmerksam machen, nicht dauerhaft über anderen Apps hängen bleiben.
    _autoCloseTimer = Timer(const Duration(seconds: 4), () {
      FlutterOverlayWindow.closeOverlay();
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  Future<void> _openApp() async {
    _autoCloseTimer?.cancel();
    try {
      FlutterForegroundTask.launchApp('/');
    } catch (_) {
      // Bestenfalls öffnen wir die App — schlägt das fehl, bleibt wenigstens
      // das Popup sichtbar, statt die ganze Funktion abstürzen zu lassen.
    }
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _openApp,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF0891B2), width: 1.4),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF0891B2), size: 20),
                SizedBox(width: 10),
                Text(
                  'Ja, Meister?',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
