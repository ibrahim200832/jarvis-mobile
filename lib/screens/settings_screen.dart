import 'package:flutter/material.dart';

import '../services/contacts_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings, required this.contacts});

  final SettingsService settings;
  final ContactsService contacts;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _newsKeyCtrl = TextEditingController();
  final _weatherKeyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _newsKeyCtrl.text = await widget.settings.getNewsApiKey() ?? '';
    _weatherKeyCtrl.text = await widget.settings.getWeatherApiKey() ?? '';
    _nameCtrl.text = await widget.settings.getUserName();
    _contacts = await widget.contacts.all();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    await widget.settings.setNewsApiKey(_newsKeyCtrl.text.trim());
    await widget.settings.setWeatherApiKey(_weatherKeyCtrl.text.trim());
    await widget.settings.setUserName(_nameCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert.')));
  }

  Future<void> _addContact() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kontakt hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefon (+49...)')),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'E-Mail (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern')),
        ],
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty && phoneCtrl.text.trim().isNotEmpty) {
      await widget.contacts.add(Contact(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
      ));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Dein Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newsKeyCtrl,
            decoration: const InputDecoration(
              labelText: 'NewsAPI-Schlüssel',
              helperText: 'Kostenlos unter newsapi.org',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weatherKeyCtrl,
            decoration: const InputDecoration(
              labelText: 'OpenWeatherMap-Schlüssel',
              helperText: 'Kostenlos unter openweathermap.org',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Speichern')),
          const Divider(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kontakte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(onPressed: _addContact, icon: const Icon(Icons.add)),
            ],
          ),
          ..._contacts.map(
            (c) => ListTile(
              title: Text(c.name),
              subtitle: Text(c.phone),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await widget.contacts.remove(c.name);
                  await _load();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
