import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/contacts_service.dart';
import '../services/home_assistant_service.dart';
import '../services/proactive_briefing_service.dart';
import '../services/settings_service.dart';
import '../services/spotify_service.dart';
import '../services/tiktok_upload_service.dart';
import '../services/tts_service.dart';
import 'changelog_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.contacts,
    required this.spotify,
    required this.tiktok,
    required this.tts,
    required this.briefing,
    required this.homeAssistant,
  });

  final SettingsService settings;
  final ContactsService contacts;
  final SpotifyService spotify;
  final TikTokUploadService tiktok;
  final TtsService tts;
  final ProactiveBriefingService briefing;
  final HomeAssistantService homeAssistant;

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
  final _tiktokClientKeyCtrl = TextEditingController();
  final _homeAssistantUrlCtrl = TextEditingController();
  final _homeAssistantTokenCtrl = TextEditingController();
  List<Contact> _contacts = [];
  String _appVersion = '';
  String _aiModel = 'openai';
  String _persona = 'standard';
  bool? _hasDeviceContacts;
  bool _spotifyConnected = false;
  bool _connectingSpotify = false;
  bool _tiktokConnected = false;
  bool _connectingTiktok = false;
  List<Map<String, String>> _voices = [];
  String? _selectedVoiceKey;
  double _ttsPitch = 1.0;
  double _ttsSpeechRate = 0.5;
  double _sarcasmLevel = 0.3;
  bool _morningBriefingEnabled = false;
  bool _eveningSummaryEnabled = false;
  bool _eveningJournalEnabled = false;
  bool _hudEffectsEnabled = true;
  bool _moodAutoAdjustEnabled = true;
  bool _testingHomeAssistant = false;

  static const _aiModels = {
    'openai': 'ChatGPT (Standard)',
    'mistral': 'Mistral',
    'llama': 'Llama',
  };

  static const _personas = {
    'standard': 'JARVIS (Standard)',
    'drill_sergeant': 'Drill-Trainer',
    'gaming_buddy': 'Gaming-Kumpel',
    'butler': 'Butler',
  };

  static const _defaultVoiceKey = 'default';

  String _voiceKey(String name, String locale) => '$name|$locale';

  /// Mirrors the sarcasm bands in ai_chat_service.dart / worker/ai-proxy.js
  /// so the label the user sees matches how JARVIS will actually behave.
  String _sarcasmDescription(double level) {
    if (level < 0.2) return 'Höflich';
    if (level < 0.5) return 'Ausgewogen (Standard)';
    if (level < 0.8) return 'Frech';
    return 'Sarkastisch';
  }

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
    _tiktokClientKeyCtrl.text = await widget.settings.getTiktokClientKey() ?? '';
    _homeAssistantUrlCtrl.text = await widget.settings.getHomeAssistantUrl() ?? '';
    _homeAssistantTokenCtrl.text = await widget.settings.getHomeAssistantToken() ?? '';
    _aiModel = await widget.settings.getAiModel();
    _persona = await widget.settings.getPersona();
    _contacts = await widget.contacts.all();
    _spotifyConnected = await widget.spotify.isConnected();
    _tiktokConnected = await widget.tiktok.isConnected();
    _voices = await widget.tts.getGermanVoices();
    _ttsPitch = await widget.settings.getTtsPitch();
    _ttsSpeechRate = await widget.settings.getTtsSpeechRate();
    _sarcasmLevel = await widget.settings.getSarcasmLevel();
    _morningBriefingEnabled = await widget.settings.getMorningBriefingEnabled();
    _eveningSummaryEnabled = await widget.settings.getEveningSummaryEnabled();
    _eveningJournalEnabled = await widget.settings.getEveningJournalEnabled();
    _hudEffectsEnabled = await widget.settings.getHudEffectsEnabled();
    _moodAutoAdjustEnabled = await widget.settings.getMoodAutoAdjustEnabled();
    final savedVoiceName = await widget.settings.getTtsVoiceName();
    final savedVoiceLocale = await widget.settings.getTtsVoiceLocale();
    if (savedVoiceName != null && savedVoiceLocale != null) {
      final key = _voiceKey(savedVoiceName, savedVoiceLocale);
      _selectedVoiceKey = _voices.any((v) => _voiceKey(v['name']!, v['locale']!) == key) ? key : _defaultVoiceKey;
    } else {
      _selectedVoiceKey = _defaultVoiceKey;
    }
    if (mounted) setState(() {});
  }

  /// Speaks the current (possibly unsaved) voice/pitch/rate picker state so
  /// the user can preview it before hitting "Speichern".
  Future<void> _previewVoice() async {
    final voice = _selectedVoiceKey == _defaultVoiceKey
        ? null
        : _voices.firstWhere((v) => _voiceKey(v['name']!, v['locale']!) == _selectedVoiceKey);
    await widget.tts.applyVoiceSettings(
      voiceName: voice?['name'],
      voiceLocale: voice?['locale'],
      pitch: _ttsPitch,
      speechRate: _ttsSpeechRate,
    );
    await widget.tts.speak('Hallo, ich bin JARVIS. So klinge ich jetzt.');
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
    await widget.settings.setTiktokClientKey(_tiktokClientKeyCtrl.text.trim());
    await widget.settings.setHomeAssistantUrl(_homeAssistantUrlCtrl.text.trim());
    await widget.settings.setHomeAssistantToken(_homeAssistantTokenCtrl.text.trim());
    await widget.settings.setAiModel(_aiModel);
    await widget.settings.setPersona(_persona);
    final voice = _selectedVoiceKey == _defaultVoiceKey || _selectedVoiceKey == null
        ? null
        : _voices.firstWhere((v) => _voiceKey(v['name']!, v['locale']!) == _selectedVoiceKey);
    await widget.settings.setTtsVoice(voice?['name'], voice?['locale']);
    await widget.settings.setTtsPitch(_ttsPitch);
    await widget.settings.setTtsSpeechRate(_ttsSpeechRate);
    await widget.settings.setSarcasmLevel(_sarcasmLevel);
    await widget.tts.applyVoiceSettings(
      voiceName: voice?['name'],
      voiceLocale: voice?['locale'],
      pitch: _ttsPitch,
      speechRate: _ttsSpeechRate,
    );
    await widget.settings.setMorningBriefingEnabled(_morningBriefingEnabled);
    await widget.settings.setEveningSummaryEnabled(_eveningSummaryEnabled);
    await widget.settings.setEveningJournalEnabled(_eveningJournalEnabled);
    await widget.settings.setHudEffectsEnabled(_hudEffectsEnabled);
    await widget.settings.setMoodAutoAdjustEnabled(_moodAutoAdjustEnabled);
    await widget.briefing.rescheduleAll();
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

  Future<void> _testHomeAssistant() async {
    final url = _homeAssistantUrlCtrl.text.trim();
    final token = _homeAssistantTokenCtrl.text.trim();
    if (url.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte zuerst URL und Token eintragen.')));
      return;
    }
    setState(() => _testingHomeAssistant = true);
    final ok = await widget.homeAssistant.testConnection(url, token);
    if (!mounted) return;
    setState(() => _testingHomeAssistant = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Verbindung zu Home Assistant erfolgreich.' : 'Verbindung fehlgeschlagen.')),
    );
  }

  Future<void> _connectTiktok() async {
    final clientKey = _tiktokClientKeyCtrl.text.trim();
    if (clientKey.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte zuerst einen TikTok-Client-Key eintragen und speichern.')));
      return;
    }
    await widget.settings.setTiktokClientKey(clientKey);
    final backendUrl = await widget.settings.getAiBackendUrl();
    if (backendUrl == null || backendUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TikTok-Upload benötigt eine KI-Server-Adresse in den Einstellungen.')),
      );
      return;
    }
    setState(() => _connectingTiktok = true);
    final ok = await widget.tiktok.connect(clientKey, backendUrl);
    if (!mounted) return;
    setState(() {
      _connectingTiktok = false;
      _tiktokConnected = ok;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? 'Mit TikTok verbunden.' : 'TikTok-Verbindung fehlgeschlagen.')));
  }

  Future<void> _disconnectTiktok() async {
    await widget.tiktok.disconnect();
    if (mounted) setState(() => _tiktokConnected = false);
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
          const SizedBox(height: 24),
          Text('JARVIS-Stimme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_voices.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Keine zusätzlichen Stimmen auf diesem Gerät gefunden. Tonhöhe und '
                'Sprechgeschwindigkeit funktionieren trotzdem.',
                style: TextStyle(fontSize: 12),
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedVoiceKey ?? _defaultVoiceKey,
              decoration: const InputDecoration(labelText: 'Stimme', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: _defaultVoiceKey, child: Text('Systemstandard')),
                ..._voices.map(
                  (v) => DropdownMenuItem(
                    value: _voiceKey(v['name']!, v['locale']!),
                    child: Text(v['name']!, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedVoiceKey = value),
            ),
          const SizedBox(height: 8),
          Text('Tonhöhe: ${_ttsPitch.toStringAsFixed(2)}'),
          Slider(
            value: _ttsPitch,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            onChanged: (value) => setState(() => _ttsPitch = value),
          ),
          Text('Sprechgeschwindigkeit: ${_ttsSpeechRate.toStringAsFixed(2)}'),
          Slider(
            value: _ttsSpeechRate,
            min: 0.25,
            max: 1.0,
            divisions: 15,
            onChanged: (value) => setState(() => _ttsSpeechRate = value),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _previewVoice,
            icon: const Icon(Icons.volume_up_outlined),
            label: const Text('Stimme testen'),
          ),
          const SizedBox(height: 24),
          Text('Persönlichkeit', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _persona,
            decoration: const InputDecoration(labelText: 'Charakter', border: OutlineInputBorder()),
            items: _personas.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _persona = value);
            },
          ),
          const SizedBox(height: 8),
          Text('Sarkasmus: ${_sarcasmDescription(_sarcasmLevel)}'),
          Slider(
            value: _sarcasmLevel,
            divisions: 10,
            onChanged: _persona == 'standard' ? (value) => setState(() => _sarcasmLevel = value) : null,
          ),
          if (_persona != 'standard')
            const Text(
              'Wirkt nur bei "JARVIS (Standard)" — andere Charaktere haben einen festen Ton.',
              style: TextStyle(fontSize: 12),
            ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Höflich', style: TextStyle(fontSize: 12)),
              Text('Sarkastisch (Tony Stark)', style: TextStyle(fontSize: 12)),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Automatische Sarkasmus-Anpassung nach Stimmung'),
            subtitle: const Text(
              'Nach einem "Stimmungscheck" darf JARVIS den Ton vorübergehend anpassen.',
              style: TextStyle(fontSize: 12),
            ),
            value: _moodAutoAdjustEnabled,
            onChanged: (value) => setState(() => _moodAutoAdjustEnabled = value),
          ),
          const SizedBox(height: 24),
          Text('Proaktive Nachrichten', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Kommen als Benachrichtigung, auch wenn die App geschlossen ist. Inhalt (Wetter, Notizen, News) '
            'spiegelt den Stand beim letzten App-Start wider, nicht live zum Sendezeitpunkt.',
            style: TextStyle(fontSize: 12),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Morgen-Briefing (7:00 Uhr)'),
            value: _morningBriefingEnabled,
            onChanged: (value) => setState(() => _morningBriefingEnabled = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Abend-Zusammenfassung (21:00 Uhr)'),
            value: _eveningSummaryEnabled,
            onChanged: (value) => setState(() => _eveningSummaryEnabled = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Abend-Tagebuch (21:30 Uhr)'),
            value: _eveningJournalEnabled,
            onChanged: (value) => setState(() => _eveningJournalEnabled = value),
          ),
          const SizedBox(height: 24),
          Text('HUD-Optik', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Dezente Sci-Fi-Scanlines im Hintergrund (Chat- und Anruf-Bildschirm).',
            style: TextStyle(fontSize: 12),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Scanline-Effekt'),
            value: _hudEffectsEnabled,
            onChanged: (value) => setState(() => _hudEffectsEnabled = value),
          ),
          const SizedBox(height: 24),
          Text('Smart-Home (Home Assistant)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _homeAssistantUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'Home Assistant URL',
              helperText: 'z.B. http://192.168.1.50:8123 — nur im eigenen (Heim-)Netzwerk erreichbar',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _homeAssistantTokenCtrl,
            decoration: const InputDecoration(
              labelText: 'Home Assistant Long-Lived Access Token',
              helperText: 'Profil → Sicherheit → Long-Lived Access Tokens in Home Assistant erstellen',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _testingHomeAssistant ? null : _testHomeAssistant,
            icon: _testingHomeAssistant
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.home_outlined),
            label: const Text('Verbindung testen'),
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
          TextField(
            controller: _tiktokClientKeyCtrl,
            decoration: const InputDecoration(
              labelText: 'TikTok-Client-Key (für Video-Upload)',
              helperText: 'Eigene App unter developers.tiktok.com anlegen, siehe README',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_tiktokConnected)
            OutlinedButton.icon(
              onPressed: _disconnectTiktok,
              icon: const Icon(Icons.link_off),
              label: const Text('TikTok trennen'),
            )
          else
            OutlinedButton.icon(
              onPressed: _connectingTiktok ? null : _connectTiktok,
              icon: _connectingTiktok
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.link),
              label: Text(_connectingTiktok ? 'Verbinde…' : 'Mit TikTok verbinden'),
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
