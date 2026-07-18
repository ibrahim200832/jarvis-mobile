import 'package:flutter/material.dart';

/// Non-web fallback: hand-tracking (MediaPipe Hands) only runs in the
/// browser, so native builds show an explanation instead.
class GestureScreen extends StatelessWidget {
  const GestureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gesten-Modus')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Der Gesten-Modus mit Handerkennung läuft aktuell nur in der Web-Version von JARVIS. '
            'Öffne die Website im Browser, um ihn auszuprobieren.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
