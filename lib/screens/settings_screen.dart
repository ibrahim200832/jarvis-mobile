import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/admin_auth_service.dart';
import '../services/api_health_service.dart';
import '../services/background_task_service.dart';
import '../services/contacts_service.dart';
import '../services/home_assistant_service.dart';
import '../services/home_widget_service.dart';
import '../services/log_service.dart';
import '../services/notification_hub_service.dart';
import '../services/proactive_briefing_service.dart';
import '../services/settings_service.dart';
import '../services/spotify_service.dart';
import '../services/tiktok_upload_service.dart';
import '../services/offline_llm_service.dart';
import '../services/tts_service.dart';
import '../services/webdav_sync_service.dart';
import '../widgets/admin_gate_screen.dart';
import 'admin_console_screen.dart';
import 'api_health_screen.dart';
import 'changelog_screen.dart';
import 'dashboard_screen.dart';
import 'log_viewer_screen.dart';

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
    required this.backgroundTasks,
    required this.webdav,
    required this.offlineLlm,
    required this.notificationHub,
    required this.homeWidget,
    required this.onClearAiMemory,
  });

  final SettingsService settings;
  final ContactsService contacts;
  final SpotifyService spotify;
  final TikTokUploadService tiktok;
  final TtsService tts;
  final ProactiveBriefingService briefing;
  final HomeAssistantService homeAssistant;
  final BackgroundTaskService backgroundTasks;
  final WebDavSyncService webdav;
  final OfflineLlmService offlineLlm;
  final NotificationHubService notificationHub;
  final HomeWidgetService homeWidget;

  /// Admin-Konsole "KI-Gedächtnis löschen" — routed all the way from
  /// home_screen.dart, since CommandRouter (the only thing that actually
  /// holds the conversation history) lives there, not in this screen.
  final Future<void> Function() onClearAiMemory;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _newsKeyCtrl = TextEditingController();
  final _weatherKeyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _googleCloudProjectNumberCtrl = TextEditingController();
  final _youtubeClientIdCtrl = TextEditingController();
  final _spotifyClientIdCtrl = TextEditingController();
  final _tiktokClientKeyCtrl = TextEditingController();
  final _homeAssistantUrlCtrl = TextEditingController();
  final _homeAssistantTokenCtrl = TextEditingController();
  final _webDavUrlCtrl = TextEditingController();
  final _webDavUsernameCtrl = TextEditingController();
  final _webDavPasswordCtrl = TextEditingController();
  final _offlineModelUrlCtrl = TextEditingController();
  final _appLockPinCtrl = TextEditingController();
  final _appLockPinConfirmCtrl = TextEditingController();
  final _appLockUsernameCtrl = TextEditingController();
  final _appLockPasswordCtrl = TextEditingController();
  final _appLockPasswordConfirmCtrl = TextEditingController();
  final _adminUsernameCtrl = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();
  final _adminPasswordConfirmCtrl = TextEditingController();
  late final _adminAuth = AdminAuthService(settings: widget.settings);
  List<Contact> _contacts = [];
  String _appVersion = '';
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
  bool _nightAlertEnabled = false;
  bool _securityBreachEnabled = true;
  bool _dashboardNotificationEnabled = false;
  bool _notificationHubEnabled = false;
  bool _notificationDigestAiEnabled = false;
  bool _notificationListenerActive = false;
  bool _notificationHubBusy = false;
  bool _widgetPinSupported = false;
  bool _hudEffectsEnabled = true;
  bool _reactiveOrbEnabled = true;
  bool _faceDownFocusEnabled = false;
  bool _shakeStartsVoiceEnabled = false;
  bool _shakeLocksAppEnabled = false;
  bool _hasAppLockPin = false;
  bool _appLockPinBusy = false;
  bool _hasAppLockCredentials = false;
  bool _appLockCredentialsBusy = false;
  bool _hasAdminAccounts = false;
  String? _adminOwnerUsername;
  bool _adminBootstrapBusy = false;
  bool _moodAutoAdjustEnabled = true;
  bool _testingHomeAssistant = false;
  bool _testingWebDav = false;
  bool? _offlineModelInstalled;
  bool _offlineModelBusy = false;
  int _offlineModelDownloadPercent = 0;
  bool _integrityCheckEnabled = false;
  bool _rssFeedCheckEnabled = false;
  bool _weeklyBackupExportEnabled = false;

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
    _googleCloudProjectNumberCtrl.text = await widget.settings.getGoogleCloudProjectNumber() ?? '';
    _integrityCheckEnabled = await widget.settings.getIntegrityCheckEnabled();
    _youtubeClientIdCtrl.text = await widget.settings.getYoutubeClientId() ?? '';
    _spotifyClientIdCtrl.text = await widget.settings.getSpotifyClientId() ?? '';
    _tiktokClientKeyCtrl.text = await widget.settings.getTiktokClientKey() ?? '';
    _homeAssistantUrlCtrl.text = await widget.settings.getHomeAssistantUrl() ?? '';
    _homeAssistantTokenCtrl.text = await widget.settings.getHomeAssistantToken() ?? '';
    _webDavUrlCtrl.text = await widget.settings.getWebDavUrl() ?? '';
    _webDavUsernameCtrl.text = await widget.settings.getWebDavUsername() ?? '';
    _webDavPasswordCtrl.text = await widget.settings.getWebDavPassword() ?? '';
    _offlineModelUrlCtrl.text = await widget.settings.getOfflineLlmModelUrl() ?? '';
    _offlineModelInstalled = await widget.offlineLlm.isModelInstalled();
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
    _nightAlertEnabled = await widget.settings.getNightAlertEnabled();
    _securityBreachEnabled = await widget.settings.getSecurityBreachEnabled();
    _hudEffectsEnabled = await widget.settings.getHudEffectsEnabled();
    _reactiveOrbEnabled = await widget.settings.getReactiveOrbEnabled();
    _faceDownFocusEnabled = await widget.settings.getFaceDownFocusEnabled();
    _shakeStartsVoiceEnabled = await widget.settings.getShakeStartsVoiceEnabled();
    _shakeLocksAppEnabled = await widget.settings.getShakeLocksAppEnabled();
    _hasAppLockPin = await widget.settings.hasAppLockPin();
    _hasAppLockCredentials = await widget.settings.hasAppLockCredentials();
    final adminAccounts = await widget.settings.getAdminAccounts();
    _hasAdminAccounts = adminAccounts.isNotEmpty;
    _adminOwnerUsername = adminAccounts.where((a) => a.isOwner).firstOrNull?.username;
    _moodAutoAdjustEnabled = await widget.settings.getMoodAutoAdjustEnabled();
    _rssFeedCheckEnabled = await widget.settings.getRssFeedCheckEnabled();
    _weeklyBackupExportEnabled = await widget.settings.getWeeklyBackupExportEnabled();
    _dashboardNotificationEnabled = await widget.settings.getDashboardNotificationEnabled();
    _notificationHubEnabled = await widget.settings.getNotificationHubEnabled();
    _notificationDigestAiEnabled = await widget.settings.getNotificationDigestAiEnabled();
    _notificationListenerActive = await widget.notificationHub.isListenerEnabled();
    _widgetPinSupported = await widget.homeWidget.isPinSupported();
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
    await widget.settings.setGoogleCloudProjectNumber(_googleCloudProjectNumberCtrl.text.trim());
    await widget.settings.setIntegrityCheckEnabled(_integrityCheckEnabled);
    await widget.settings.setYoutubeClientId(_youtubeClientIdCtrl.text.trim());
    await widget.settings.setSpotifyClientId(_spotifyClientIdCtrl.text.trim());
    await widget.settings.setTiktokClientKey(_tiktokClientKeyCtrl.text.trim());
    await widget.settings.setHomeAssistantUrl(_homeAssistantUrlCtrl.text.trim());
    await widget.settings.setHomeAssistantToken(_homeAssistantTokenCtrl.text.trim());
    await widget.settings.setWebDavUrl(_webDavUrlCtrl.text.trim());
    await widget.settings.setWebDavUsername(_webDavUsernameCtrl.text.trim());
    await widget.settings.setWebDavPassword(_webDavPasswordCtrl.text.trim());
    await widget.settings.setOfflineLlmModelUrl(_offlineModelUrlCtrl.text.trim());
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
    await widget.settings.setNightAlertEnabled(_nightAlertEnabled);
    await widget.settings.setSecurityBreachEnabled(_securityBreachEnabled);
    await widget.settings.setHudEffectsEnabled(_hudEffectsEnabled);
    await widget.settings.setReactiveOrbEnabled(_reactiveOrbEnabled);
    await widget.settings.setFaceDownFocusEnabled(_faceDownFocusEnabled);
    await widget.settings.setShakeStartsVoiceEnabled(_shakeStartsVoiceEnabled);
    await widget.settings.setShakeLocksAppEnabled(_shakeLocksAppEnabled);
    await widget.settings.setMoodAutoAdjustEnabled(_moodAutoAdjustEnabled);
    await widget.settings.setRssFeedCheckEnabled(_rssFeedCheckEnabled);
    await widget.settings.setWeeklyBackupExportEnabled(_weeklyBackupExportEnabled);
    await widget.settings.setDashboardNotificationEnabled(_dashboardNotificationEnabled);
    await widget.settings.setNotificationHubEnabled(_notificationHubEnabled);
    await widget.settings.setNotificationDigestAiEnabled(_notificationDigestAiEnabled);
    await widget.notificationHub.setCaptureEnabled(_notificationHubEnabled);
    await widget.briefing.rescheduleAll();
    await widget.backgroundTasks.syncRssFeedTask();
    await widget.backgroundTasks.syncBackupExportTask();
    await widget.backgroundTasks.syncDashboardTask();
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

  Future<void> _testWebDav() async {
    final url = _webDavUrlCtrl.text.trim();
    final username = _webDavUsernameCtrl.text.trim();
    final password = _webDavPasswordCtrl.text.trim();
    if (url.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte zuerst URL, Benutzername und Passwort eintragen.')));
      return;
    }
    setState(() => _testingWebDav = true);
    final ok = await widget.webdav.testConnection(baseUrl: url, username: username, password: password);
    if (!mounted) return;
    setState(() => _testingWebDav = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? 'Verbindung zum WebDAV-Server erfolgreich.' : 'Verbindung fehlgeschlagen.')));
  }

  Future<void> _downloadOfflineModel() async {
    final url = _offlineModelUrlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte zuerst eine Modell-Datei-URL eintragen.')));
      return;
    }
    await widget.settings.setOfflineLlmModelUrl(url);
    setState(() {
      _offlineModelBusy = true;
      _offlineModelDownloadPercent = 0;
    });
    try {
      await widget.offlineLlm.installModel(
        url,
        onProgress: (percent) {
          if (mounted) setState(() => _offlineModelDownloadPercent = percent);
        },
      );
      if (!mounted) return;
      setState(() {
        _offlineModelInstalled = true;
        _offlineModelBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline-Modell heruntergeladen.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _offlineModelBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download fehlgeschlagen: $e')));
    }
  }

  Future<void> _deleteOfflineModel() async {
    setState(() => _offlineModelBusy = true);
    await widget.offlineLlm.deleteModel();
    if (!mounted) return;
    setState(() {
      _offlineModelInstalled = false;
      _offlineModelBusy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline-Modell gelöscht.')));
  }

  Future<void> _saveAppLockPin() async {
    final pin = _appLockPinCtrl.text.trim();
    final confirm = _appLockPinConfirmCtrl.text.trim();
    if (pin.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte eine PIN eingeben.')));
      return;
    }
    if (pin != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Die beiden PINs stimmen nicht überein.')));
      return;
    }
    setState(() => _appLockPinBusy = true);
    await widget.settings.setAppLockPin(pin);
    if (!mounted) return;
    _appLockPinCtrl.clear();
    _appLockPinConfirmCtrl.clear();
    setState(() {
      _hasAppLockPin = true;
      _appLockPinBusy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN gespeichert.')));
  }

  Future<void> _removeAppLockPin() async {
    setState(() => _appLockPinBusy = true);
    await widget.settings.clearAppLockPin();
    if (!mounted) return;
    setState(() {
      _hasAppLockPin = false;
      _appLockPinBusy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN entfernt.')));
  }

  Future<void> _saveAppLockCredentials() async {
    final username = _appLockUsernameCtrl.text.trim();
    final password = _appLockPasswordCtrl.text;
    final confirm = _appLockPasswordConfirmCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte Benutzername und Passwort eingeben.')));
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Die beiden Passwörter stimmen nicht überein.')));
      return;
    }
    setState(() => _appLockCredentialsBusy = true);
    await widget.settings.setAppLockCredentials(username, password);
    if (!mounted) return;
    _appLockPasswordCtrl.clear();
    _appLockPasswordConfirmCtrl.clear();
    setState(() {
      _hasAppLockCredentials = true;
      _appLockCredentialsBusy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zugangsdaten gespeichert.')));
  }

  Future<void> _removeAppLockCredentials() async {
    setState(() => _appLockCredentialsBusy = true);
    await widget.settings.clearAppLockCredentials();
    if (!mounted) return;
    _appLockUsernameCtrl.clear();
    setState(() {
      _hasAppLockCredentials = false;
      _appLockCredentialsBusy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zugangsdaten entfernt.')));
  }

  /// Sets up the one owner account — only offered while no Admin-Konsole
  /// account exists yet (see [_hasAdminAccounts]). Every further account
  /// (helpers) and any password change happens only from inside the
  /// console once logged in, never from here again.
  Future<void> _bootstrapOwnerAccount() async {
    final username = _adminUsernameCtrl.text.trim();
    final password = _adminPasswordCtrl.text;
    final confirm = _adminPasswordConfirmCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bitte Benutzername und Passwort eingeben.')));
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Die beiden Passwörter stimmen nicht überein.')));
      return;
    }
    setState(() => _adminBootstrapBusy = true);
    await widget.settings.addAdminAccount(username: username, password: password, isOwner: true);
    if (!mounted) return;
    _adminUsernameCtrl.clear();
    _adminPasswordCtrl.clear();
    _adminPasswordConfirmCtrl.clear();
    setState(() {
      _hasAdminAccounts = true;
      _adminOwnerUsername = username;
      _adminBootstrapBusy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Besitzer-Konto eingerichtet.')));
  }

  /// Entry point for the "Admin-Einstellungen" button: already logged in
  /// this session → straight to the console; no accounts set up yet →
  /// point at the bootstrap form above instead of showing a gate with
  /// nothing to log into; otherwise → AdminGateScreen first.
  Future<void> _openAdminConsole() async {
    if (_adminAuth.currentAccount != null) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminConsoleScreen(
            settings: widget.settings,
            onClearAiMemory: widget.onClearAiMemory,
            adminAuth: _adminAuth,
          ),
        ),
      );
      return;
    }
    if (!_hasAdminAccounts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst oben ein Besitzer-Konto einrichten.')),
      );
      return;
    }
    final unlocked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminGateScreen(checkLockout: _adminAuth.remainingLockout, onLogin: _adminAuth.login),
      ),
    );
    if (unlocked == true && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminConsoleScreen(
            settings: widget.settings,
            onClearAiMemory: widget.onClearAiMemory,
            adminAuth: _adminAuth,
          ),
        ),
      );
    }
  }

  Future<void> _openNotificationListenerSettings() async {
    await widget.notificationHub.openListenerSettings();
    // The user grants this in a separate OS settings screen, not a normal
    // in-app dialog — refresh the status once they come back to this one.
    final active = await widget.notificationHub.isListenerEnabled();
    if (mounted) setState(() => _notificationListenerActive = active);
  }

  Future<void> _clearCapturedNotifications() async {
    setState(() => _notificationHubBusy = true);
    await widget.notificationHub.clearCaptured();
    if (!mounted) return;
    setState(() => _notificationHubBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erfasste Benachrichtigungen gelöscht.')));
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sarkastische Notfall-Warnungen'),
            subtitle: const Text(
              'Zusätzliche Push-Benachrichtigung, wenn JARVIS dich spätnachts noch beim Programmieren erwischt.',
              style: TextStyle(fontSize: 12),
            ),
            value: _nightAlertEnabled,
            onChanged: (value) => setState(() => _nightAlertEnabled = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Simulierte Sicherheitsbrüche'),
            subtitle: const Text(
              'JARVIS zeigt beim App-Start gelegentlich (max. 1x/Tag, kleine Zufallschance) eine harmlose '
              'Firewall-Mini-Challenge im Chat. Auch jederzeit manuell per "simuliere einen sicherheitsbruch".',
              style: TextStyle(fontSize: 12),
            ),
            value: _securityBreachEnabled,
            onChanged: (value) => setState(() => _securityBreachEnabled = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('RSS-Hintergrundprüfung'),
            subtitle: const Text(
              'Prüft abonnierte Feeds alle paar Stunden im Hintergrund (auch bei geschlossener App) und '
              'benachrichtigt bei neuen Schlagzeilen. Feeds verwaltest du im Chat, z.B. "abonniere feed <URL>".',
              style: TextStyle(fontSize: 12),
            ),
            value: _rssFeedCheckEnabled,
            onChanged: (value) => setState(() => _rssFeedCheckEnabled = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Wöchentlicher Backup-Export'),
            subtitle: const Text(
              'Sichert Notizen, Journal, XP/Erfolge, RPG-Spielstand, Feeds und Einstellungen wöchentlich als '
              'AES-256-verschlüsselte Datei — rein lokal auf dem Gerät, kein Mail-/Bot-Versand. Auch jederzeit '
              'manuell per "erstelle jetzt ein backup".',
              style: TextStyle(fontSize: 12),
            ),
            value: _weeklyBackupExportEnabled,
            onChanged: (value) => setState(() => _weeklyBackupExportEnabled = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lockscreen-Dashboard'),
            subtitle: const Text(
              'Dauerhafte, nicht wegwischbare Benachrichtigung mit Status/Latenz deines KI-Servers und '
              'offenen Aufgaben — auch bei gesperrtem Handy sichtbar. Android hat seit Version 5 keine echten '
              'Sperrbildschirm-Widgets mehr, das ist die nächstliegende Alternative.',
              style: TextStyle(fontSize: 12),
            ),
            value: _dashboardNotificationEnabled,
            onChanged: (value) => setState(() => _dashboardNotificationEnabled = value),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Audio-reaktiver Reaktor-Ring'),
            subtitle: const Text(
              'Der Reaktor-Ring im Anruf-Modus schlägt im Takt der Mikrofon-Lautstärke bzw. der '
              'Sprachausgabe von JARVIS aus, statt nur einer festen Animation zu folgen.',
              style: TextStyle(fontSize: 12),
            ),
            value: _reactiveOrbEnabled,
            onChanged: (value) => setState(() => _reactiveOrbEnabled = value),
          ),
          const SizedBox(height: 24),
          Text('Bewegungssteuerung & Notfall-Sperre', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Nutzt den Bewegungssensor des Geräts — alles standardmäßig aus.',
            style: TextStyle(fontSize: 12),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Handy umdrehen → Fokus-Modus'),
            subtitle: const Text(
              'Legst du das Handy mit dem Display nach unten, mutet JARVIS sich (TTS/Mikrofon), bis du es '
              'wieder umdrehst.',
              style: TextStyle(fontSize: 12),
            ),
            value: _faceDownFocusEnabled,
            onChanged: (value) => setState(() => _faceDownFocusEnabled = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Schütteln → Spracheingabe starten'),
            value: _shakeStartsVoiceEnabled,
            onChanged: (value) => setState(() => _shakeStartsVoiceEnabled = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Schütteln → Notfall-Sperre auslösen'),
            subtitle: const Text(
              'Braucht eine gesetzte PIN oder Zugangsdaten (siehe unten) — ohne eins von beidem passiert '
              'beim Schütteln nichts.',
              style: TextStyle(fontSize: 12),
            ),
            value: _shakeLocksAppEnabled,
            onChanged: (value) => setState(() => _shakeLocksAppEnabled = value),
          ),
          const SizedBox(height: 12),
          Text(
            _hasAppLockPin ? 'PIN ist gesetzt.' : 'Noch keine PIN gesetzt.',
            style: const TextStyle(fontSize: 12),
          ),
          const Text(
            'Achtung: Es gibt keinen "PIN/Passwort vergessen"-Weg — merk sie dir gut. Zum Entfernen musst du '
            'die App noch entsperrt haben.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _appLockPinCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Neue PIN'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _appLockPinConfirmCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'PIN bestätigen'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _appLockPinBusy ? null : _saveAppLockPin,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('PIN speichern'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_appLockPinBusy || !_hasAppLockPin) ? null : _removeAppLockPin,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('PIN entfernen'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _hasAppLockCredentials ? 'Zugangsdaten sind gesetzt.' : 'Noch keine Zugangsdaten gesetzt.',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _appLockUsernameCtrl,
            decoration: const InputDecoration(labelText: 'Benutzername'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _appLockPasswordCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Passwort'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _appLockPasswordConfirmCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Passwort bestätigen'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _appLockCredentialsBusy ? null : _saveAppLockCredentials,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Zugangsdaten speichern'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_appLockCredentialsBusy || !_hasAppLockCredentials)
                      ? null
                      : _removeAppLockCredentials,
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Zugangsdaten entfernen'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Admin-Zugang', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Schützt fortgeschrittene/sensible Einstellungen (KI-Server, System-Prompt, Diagnose usw.) '
            'hinter individuellen Konten, getrennt von der Notfall-Sperre oben — jede/r Berechtigte meldet '
            'sich mit dem eigenen Nutzernamen+Passwort an.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (!_hasAdminAccounts) ...[
            const Text(
              'Richte einmalig dein eigenes Besitzer-Konto ein — es hat volle Rechte, auch um später '
              'weitere Helfer-Konten anzulegen. Das geht danach nur noch direkt in der Admin-Konsole, '
              'nicht mehr hier.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _adminUsernameCtrl,
              decoration: const InputDecoration(labelText: 'Benutzername'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _adminPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passwort'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _adminPasswordConfirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passwort bestätigen'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _adminBootstrapBusy ? null : _bootstrapOwnerAccount,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Besitzer-Konto einrichten'),
            ),
          ] else ...[
            Text(
              'Admin-Konsole eingerichtet (Besitzer: ${_adminOwnerUsername ?? "?"}).',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openAdminConsole,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Admin-Einstellungen'),
            ),
          ],
          const SizedBox(height: 24),
          Text('Homescreen-Widget', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Zeigt Server-Status/Latenz und offene Aufgaben direkt auf dem Startbildschirm, mit einer '
            '"Blitz-Notiz"-Schnellaktion — ganz ohne die App zu öffnen. Lang auf den Startbildschirm drücken → '
            'Widgets → J.A.R.V.I.S., um es hinzuzufügen.',
            style: TextStyle(fontSize: 12),
          ),
          if (_widgetPinSupported) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => widget.homeWidget.requestPin(),
              icon: const Icon(Icons.add_to_home_screen_outlined),
              label: const Text('Widget anheften'),
            ),
          ],
          const SizedBox(height: 24),
          Text('App-Integrität (Play Integrity)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Prüft beim Start, ob Gerät und Installation vertrauenswürdig sind (nicht gerootet, unveränderte '
            'APK) — nur Android, braucht ein eigenes Google-Cloud-Projekt und einen eingerichteten Worker-'
            'Endpunkt (siehe README). Ohne Einrichtung bleibt das aus, ohne dass etwas fehlschlägt.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _googleCloudProjectNumberCtrl,
            decoration: const InputDecoration(
              labelText: 'Google-Cloud-Projektnummer',
              helperText: 'Aus der Google Cloud Console, mit Play Console verknüpft (siehe README)',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('App-Integritäts-Check aktivieren'),
            value: _integrityCheckEnabled,
            onChanged: (value) => setState(() => _integrityCheckEnabled = value),
          ),
          const SizedBox(height: 24),
          Text('Benachrichtigungs-Zusammenfasser', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Erfasst Vorschautexte von Benachrichtigungen anderer Apps, damit JARVIS sie abends kurz '
            'zusammenfasst. Das ist eine Sonderberechtigung, die Android nicht per normalem Dialog abfragt — '
            'du musst sie manuell in den System-Einstellungen erlauben.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            _notificationListenerActive ? 'Benachrichtigungszugriff: aktiv' : 'Benachrichtigungszugriff: nicht aktiv',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.notificationHub.isSupported ? _openNotificationListenerSettings : null,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Benachrichtigungszugriff einrichten'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Benachrichtigungen erfassen'),
            value: _notificationHubEnabled,
            onChanged: (value) => setState(() => _notificationHubEnabled = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('KI-Zusammenfassung erlauben'),
            subtitle: const Text(
              'Sendet kurze Vorschautexte deiner Benachrichtigungen an deinen eigenen KI-Server (nie an den '
              'öffentlichen Gratis-Fallback). Ohne eigenen Server bleibt es bei der lokalen, einfachen '
              'Zusammenfassung.',
              style: TextStyle(fontSize: 12),
            ),
            value: _notificationDigestAiEnabled,
            onChanged: (value) => setState(() => _notificationDigestAiEnabled = value),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _notificationHubBusy ? null : _clearCapturedNotifications,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Erfasste Benachrichtigungen jetzt löschen'),
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
          const SizedBox(height: 24),
          Text('WebDAV-Cloud-Sync', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Ende-zu-Ende-verschlüsselt: dein Backup wird bereits auf dem Gerät verschlüsselt, bevor es zum '
            'Server geht — dieser sieht nur Chiffretext. Sync per Chat: "cloud-backup hochladen" / '
            '"cloud-backup herunterladen".',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webDavUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'WebDAV-Server-URL',
              helperText: 'z.B. https://cloud.example.com/remote.php/dav/files/nutzername/',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _webDavUsernameCtrl,
            decoration: const InputDecoration(labelText: 'WebDAV-Benutzername', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _webDavPasswordCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'WebDAV-Passwort', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _testingWebDav ? null : _testWebDav,
            icon: _testingWebDav
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync_outlined),
            label: const Text('Verbindung testen'),
          ),
          const SizedBox(height: 24),
          Text('Offline-KI (lokales Sprachmodell)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Läuft komplett auf dem Gerät, auch ohne Internetverbindung — für grundlegende Fragen, Notizen und '
            'Berechnungen. Trage den direkten Download-Link zu einer .litertlm-Modelldatei ein (z.B. ein '
            'Gemma-Modell von huggingface.co/litert-community). Größere Modelle (mehrere GB) antworten besser, '
            'brauchen aber mehr Speicherplatz und RAM.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            _offlineModelInstalled == null
                ? 'Status: wird geprüft…'
                : _offlineModelInstalled!
                ? 'Status: Modell installiert.'
                : 'Status: kein Modell installiert.',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _offlineModelUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'Modell-Datei-URL (.litertlm)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_offlineModelBusy && _offlineModelDownloadPercent > 0) ...[
            LinearProgressIndicator(value: _offlineModelDownloadPercent / 100),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _offlineModelBusy ? null : _downloadOfflineModel,
                  icon: _offlineModelBusy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_outlined),
                  label: const Text('Herunterladen'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_offlineModelBusy || _offlineModelInstalled != true) ? null : _deleteOfflineModel,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Löschen'),
                ),
              ),
            ],
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
              MaterialPageRoute(builder: (_) => DashboardScreen(gamification: widget.briefing.gamification)),
            ),
            icon: const Icon(Icons.bar_chart),
            label: const Text('Lebens-Dashboard'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangelogScreen()),
            ),
            icon: const Icon(Icons.history),
            label: const Text('Änderungsverlauf'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => LogViewerScreen(logService: LogService()))),
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('Log-Viewer'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ApiHealthScreen(apiHealth: ApiHealthService(), settings: widget.settings),
              ),
            ),
            icon: const Icon(Icons.monitor_heart_outlined),
            label: const Text('API-Health-Monitor'),
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
