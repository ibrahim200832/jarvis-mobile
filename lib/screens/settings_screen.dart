import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/contacts_service.dart';
import '../services/settings_service.dart';
import '../services/spotify_service.dart';
import 'changelog_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings, required this.contacts, required this.spotify});

  final SettingsService settings;
  final ContactsService contacts;
  final SpotifyService spotify;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _newsKeyCtrl = TextEditingController();
  final _weatherKeyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _aiBackendCtrl = TextEditingController();
  final _youtubeClientIdCtrl = TextEditingController();
  final _spotifyClientIdCtrl = TextEditingController();
  List<Contact> _contacts = [];
  String _appVersion = '';
  String _aiModel = 'openai';
  bool? _hasDeviceContacts;
  bool _spotifyConnected = false;
  bool _connectingSpotify = false;

  static const _aiModels = {
    'openai': 'ChatGPT (Standard)',
    'mistral': 'Mistral',
    'llama': 'Llama',
  };

  @override
  void initState() {
    super.initState();
    _load();
    _loadVersion();
  }

  Future<void> _load() async {
    _newsKeyCtrl.text = await widget.settings.getNewsApiKey() ?? '';
    _weatherKeyCtrl.text = await widget.settings.getWeatherApiKey() ?? '';
    _nameCtrl.text = await widget.settings.getUserName();
    _aiBackendCtrl.text = await widget.settings.getAiBackendUrl() ?? '';
    _youtubeClientIdCtrl.text = await widget.settings.getYoutubeClientId() ?? '';
    _spotifyClientIdCtrl.text = await widget.settings.getSpotifyClientId() ?? '';
    _aiModel = await widget.settings.getAiModel();
    _contacts = await widget.contacts.all();
    _spotifyConnected = await widget.spotify.isConnected();
    if (mounted) setState(() {});
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  Future<void> _save() async {
    await widget.settings.setNewsApiKey(_newsKeyCtrl.text.trim());
    await widget.settings.setWeatherApiKey(_weatherKeyCtrl.text.trim());
    await widget.settings.setUserName(_nameCtrl.text.trim());
    await widget.settings.setAiBackendUrl(_aiBackendCtrl.text.trim());
    await widget.settings.setYoutubeClientId(_youtubeClientIdCtrl.text.trim());
    await widget.settings.setSpotifyClientId(_spotifyClientIdCtrl.text.trim());
    await widget.settings.setAiModel(_aiModel);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gespeichert.')));
  }

  Future<void> _connectSpotify() async {
    final clientId = _spotifyClientIdCtrl.text.trim();
    if (clientId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte zuerst eine Spotify-Client-ID eintragen und speichern.')));
      return;
    }
    await widget.settings.setSpotifyClientId(clientId);
    setState(() => _connectingSpotify = true);
    final ok = await widget.spotify.connect(clientId);
    if (!mounted) return;
    setState(() {
      _connectingSpotify = false;
      _spotifyConnected = ok;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Mit Spotify verbunden.' : 'Spotify-Verbindung fehlgeschlagen.')),
    );
  }

  Future<void> _disconnectSpotify() async {
    await widget.spotify.disconnect();
    if (mounted) setState(() => _spotifyConnected = false);
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

  Future<void> _requestDeviceContacts() async {
    final granted = await widget.contacts.hasDeviceAccess();
    if (mounted) setState(() => _hasDeviceContacts = granted);
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
          TextField(
            controller: _aiBackendCtrl,
            decoration: const InputDecoration(
              labelText: 'KI-Server-Adresse (für freie Gespräche)',
              helperText: 'Die Worker-URL aus der Cloudflare-Bereitstellung, siehe README',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _aiModel,
            decoration: const InputDecoration(
              labelText: 'KI-Modell (kostenlos, ohne Server-Adresse)',
              helperText: 'Nur wenn oben keine eigene KI-Server-Adresse eingetragen ist',
              border: OutlineInputBorder(),
            ),
            items: _aiModels.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _aiModel = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _youtubeClientIdCtrl,
            decoration: const InputDecoration(
              labelText: 'YouTube-Client-ID (für Video-Upload)',
              helperText: 'Web-Client-ID aus Google Cloud Console, siehe README',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _spotifyClientIdCtrl,
            decoration: const InputDecoration(
              labelText: 'Spotify-Client-ID (für Musiksteuerung)',
              helperText: 'Eigene App unter developer.spotify.com anlegen, siehe README',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_spotifyConnected)
            OutlinedButton.icon(
              onPressed: _disconnectSpotify,
              icon: const Icon(Icons.link_off),
              label: const Text('Spotify trennen'),
            )
          else
            OutlinedButton.icon(
              onPressed: _connectingSpotify ? null : _connectSpotify,
              icon: _connectingSpotify
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.link),
              label: Text(_connectingSpotify ? 'Verbinde…' : 'Mit Spotify verbinden'),
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
          if (_hasDeviceContacts != true)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _requestDeviceContacts,
                icon: const Icon(Icons.contacts_outlined),
                label: const Text('Zugriff auf Handy-Kontakte erlauben'),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Zugriff auf Handy-Kontakte erlaubt — JARVIS findet jeden Namen aus deinem Adressbuch, ohne dass du ihn hier eintragen musst.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          const Text(
            'Zusätzliche Kontakte (z. B. für Namen, die nicht im Handy-Adressbuch stehen):',
            style: TextStyle(fontSize: 12),
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
          const Divider(height: 40),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangelogScreen()),
            ),
            icon: const Icon(Icons.history),
            label: const Text('Änderungsverlauf'),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _appVersion.isEmpty ? '' : 'J.A.R.V.I.S. Version $_appVersion',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
