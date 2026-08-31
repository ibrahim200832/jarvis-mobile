import 'package:flutter/material.dart';

import '../services/settings_service.dart';

/// Advanced/sensitive settings gated behind the Admin-PIN (see
/// AdminAuthService/AdminGateScreen) — reachable only via the
/// "Admin-Einstellungen" button in the normal settings screen. Filled in
/// section by section across Runde 15's units; other services it needs are
/// constructed inline at point of use here, matching the rest of this
/// app's screens-navigated-from-settings convention rather than growing
/// this constructor with every new section.
class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin-Konsole')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Weitere Admin-Funktionen folgen in den nächsten Einheiten dieser Runde.'),
        ),
      ),
    );
  }
}
