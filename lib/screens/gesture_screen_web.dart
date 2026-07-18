import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

@JS('jarvisGesture.start')
external void _jsGestureStart(JSString containerId, JSFunction onError);

@JS('jarvisGesture.stop')
external void _jsGestureStop();

const _viewType = 'jarvis-gesture-view';
const _containerId = 'jarvis-gesture-container';
bool _viewFactoryRegistered = false;

void _ensureViewFactoryRegistered() {
  if (_viewFactoryRegistered) return;
  _viewFactoryRegistered = true;
  ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
    final div = web.document.createElement('div') as web.HTMLDivElement;
    div.id = _containerId;
    div.style.width = '100%';
    div.style.height = '100%';
    div.style.backgroundColor = '#000000';
    return div;
  });
}

/// Full-screen hand-tracking demo: MediaPipe Hands (running in the browser)
/// detects the hand via the webcam, and a small particle effect follows the
/// index fingertip — a little JARVIS-style hologram gimmick.
class GestureScreen extends StatefulWidget {
  const GestureScreen({super.key});

  @override
  State<GestureScreen> createState() => _GestureScreenState();
}

class _GestureScreenState extends State<GestureScreen> {
  String? _errorMessage;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _ensureViewFactoryRegistered();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (_started) return;
    _started = true;
    _jsGestureStart(
      _containerId.toJS,
      ((JSString msg) {
        if (mounted) setState(() => _errorMessage = msg.toDart);
      }).toJS,
    );
  }

  @override
  void dispose() {
    _jsGestureStop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Gesten-Modus'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: HtmlElementView(viewType: _viewType)),
          if (_errorMessage != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black87,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
