import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/command_router.dart';
import '../services/ai_chat_service.dart';
import '../services/ambient_sound_service.dart';
import '../services/anime_service.dart';
import '../services/api_health_service.dart';
import '../services/app_integrity_service.dart';
import '../services/app_launcher_service.dart';
import '../services/app_lock_service.dart';
import '../services/background_task_service.dart';
import '../services/backup_export_service.dart';
import '../services/call_service.dart';
import '../services/challenge_service.dart';
import '../services/code_snippet_service.dart';
import '../services/contacts_service.dart';
import '../services/dashboard_notification_service.dart';
import '../services/device_info_service.dart';
import '../services/email_service.dart';
import '../services/gamification_service.dart';
import '../services/home_assistant_service.dart';
import '../services/home_widget_service.dart';
import '../services/ip_service.dart';
import '../services/joke_service.dart';
import '../services/journal_service.dart';
import '../services/late_night_tease_service.dart';
import '../services/location_service.dart';
import '../services/mood_capture_service.dart';
import '../services/motion_actions_service.dart';
import '../services/music_dj_service.dart';
import '../services/news_service.dart';
import '../services/notes_service.dart';
import '../services/notification_hub_service.dart';
import '../services/notification_service.dart';
import '../services/offline_llm_service.dart';
import '../services/proactive_briefing_service.dart';
import '../services/qr_service.dart';
import '../services/random_fun_service.dart';
import '../services/rpg_service.dart';
import '../services/rss_feed_service.dart';
import '../services/security_breach_service.dart';
import '../services/settings_service.dart';
import '../services/soundboard_service.dart';
import '../services/speech_service.dart';
import '../services/spotify_service.dart';
import '../services/tiktok_upload_service.dart';
import '../services/timer_service.dart';
import '../services/todo_service.dart';
import '../services/tts_service.dart';
import '../services/update_service.dart';
import '../services/weather_service.dart';
import '../services/web_search_service.dart';
import '../services/webdav_sync_service.dart';
import '../services/whatsapp_service.dart';
import '../services/wikipedia_service.dart';
import '../services/youtube_service.dart';
import '../services/youtube_upload_service.dart';
import '../theme/jarvis_theme.dart';
import '../widgets/access_denied_flash.dart';
import '../widgets/blinking_dot.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/emergency_lock_screen.dart';
import '../widgets/glass_container.dart';
import '../widgets/integrity_lockdown_screen.dart';
import '../widgets/scanline_overlay.dart';
import '../widgets/voice_orb_overlay.dart';
import 'camera_screen.dart';
import 'dashboard_screen.dart';
import 'gesture_screen.dart';
import 'settings_screen.dart';
import 'tiktok_upload_screen.dart';
import 'youtube_upload_screen.dart';

const _quickActions = ['Wetter', 'Nachrichten', 'Witz', 'Hilfe'];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _speech = SpeechService();
  final _tts = TtsService();
  final _settings = SettingsService();
  final _briefing = ProactiveBriefingService(
    notifications: NotificationService(),
    weather: WeatherService(),
    news: NewsService(),
    notes: NotesService(),
    location: LocationService(),
    gamification: GamificationService(),
    settings: SettingsService(),
    challenges: ChallengeService(),
    todos: TodoService(),
    notificationHub: NotificationHubService(),
    // A fresh instance (not the offline-fallback-capable one used by
    // CommandRouter) — askNotificationDigest is only ever called when a
    // real custom backend is configured (see ProactiveBriefingService's
    // privacy gating), so there's no offline path to fall back to here.
    aiChat: AiChatService(),
  );
  final _ambient = AmbientSoundService();
  final _soundboard = SoundboardService();
  final _securityBreach = SecurityBreachService();
  final _backgroundTasks = BackgroundTaskService();
  final _dashboardNotification = DashboardNotificationService(
    notifications: NotificationService(),
    todos: TodoService(),
    apiHealth: ApiHealthService(),
    settings: SettingsService(),
  );
  final _homeWidget = HomeWidgetService();
  StreamSubscription<Uri?>? _widgetClickSubscription;
  final _feeds = RssFeedService();
  final _backup = BackupExportService();
  final _webdav = WebDavSyncService();
  final _offlineLlm = OfflineLlmService();
  final _contacts = ContactsService();
  final _timer = TimerService();
  final _spotify = SpotifyService();
  final _tiktok = TikTokUploadService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  late final CommandRouter _router;
  final List<ChatMessage> _messages = [
    ChatMessage(
      kIsWeb
          ? 'Hallo! Ich bin JARVIS. Sag "Hilfe" für eine Liste meiner Befehle. Tipp: Über die Symbole oben rechts kannst du die App für Android (APK) oder iOS herunterladen.'
          : 'Hallo! Ich bin JARVIS. Sag "Hilfe" für eine Liste meiner Befehle.',
      fromUser: false,
    ),
  ];
  bool _listening = false;
  bool _callActive = false;
  bool _processing = false;
  bool _speaking = false;
  bool _muted = false;
  bool _hudEffectsEnabled = true;
  bool _reactiveOrbEnabled = true;
  bool _integrityLocked = false;
  bool _appLocked = false;
  late final _appLock = AppLockService(settings: _settings);
  String _partialText = '';
  final _appIntegrity = AppIntegrityService();

  /// Drives VoiceOrbOverlay's audio-reactive pulse (0.0-1.0): real
  /// microphone level while listening, or a synthetic decaying pulse while
  /// speaking (see _startAmplitudeDecayLoop). Pinned at 0 outside a call.
  final _orbAmplitude = ValueNotifier<double>(0.0);
  Timer? _amplitudeDecayTimer;

  /// Accelerometer-based face-down/shake detection (see
  /// MotionActionsService) — only actually listening while at least one of
  /// the three motion toggles below is enabled, and only while the app is
  /// in the foreground (see didChangeAppLifecycleState), to avoid spending
  /// battery on a sensor stream nobody asked for.
  final _motionActions = MotionActionsService();
  bool _focusMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = CommandRouter(
      wikipedia: WikipediaService(),
      jokes: JokeService(),
      news: NewsService(),
      weather: WeatherService(),
      whatsapp: WhatsappService(),
      email: EmailService(),
      call: CallService(),
      appLauncher: AppLauncherService(),
      youtube: YoutubeService(),
      qr: QrService(),
      location: LocationService(),
      contacts: _contacts,
      settings: _settings,
      ip: IpService(),
      aiChat: AiChatService(offlineLlm: _offlineLlm),
      deviceInfo: DeviceInfoService(),
      timer: _timer,
      notes: NotesService(),
      fun: RandomFunService(),
      notifications: NotificationService(),
      spotify: _spotify,
      webSearch: WebSearchService(),
      snippets: CodeSnippetService(),
      soundboard: _soundboard,
      gamification: GamificationService(),
      musicDj: MusicDjService(),
      briefing: _briefing,
      homeAssistant: HomeAssistantService(),
      anime: AnimeService(),
      lateNightTease: LateNightTeaseService(),
      challenges: ChallengeService(),
      rpg: RpgService(),
      journal: JournalService(),
      ambient: _ambient,
      moodCapture: MoodCaptureService(),
      securityBreach: _securityBreach,
      feeds: _feeds,
      backup: _backup,
      webdav: _webdav,
      offlineLlm: _offlineLlm,
      todos: TodoService(),
      appLock: _appLock,
      notificationHub: NotificationHubService(),
    );
    _timer.onFire = _onTimerFired;
    _speech.init();
    _tts.setWordBoundaryListener((_) {
      if (_reactiveOrbEnabled) _orbAmplitude.value = 1.0;
    });
    unawaited(_checkForUpdate());
    unawaited(_applyStoredTtsSettings());
    unawaited(_loadHudEffectsEnabled());
    unawaited(_loadReactiveOrbEnabled());
    // Not a background fetch (see ProactiveBriefingService) - just makes
    // sure the daily notifications are scheduled/updated with today's data
    // whenever the app is opened, in case Einstellungen enabled them.
    unawaited(_briefing.rescheduleAll());
    unawaited(_maybeDeliverMorningAudioBriefing());
    unawaited(_maybeTriggerSecurityBreach());
    unawaited(_checkAppIntegrity());
    unawaited(_syncBackgroundTasks());
    unawaited(_syncMotionActions());
    unawaited(_checkAppLockState());
    unawaited(_dashboardNotification.refresh());
    unawaited(_refreshHomeWidget());
    _widgetClickSubscription = _homeWidget.widgetClicks.listen(_handleWidgetClick);
    unawaited(_handleColdStartFromWidget());
  }

  /// Pushes the same status/latency + open-to-do content shown in the
  /// dashboard notification (see DashboardNotificationService) to the
  /// native home-screen widget (Einheit 9 — no-op until that native side
  /// exists, and always a no-op on web, see HomeWidgetService).
  Future<void> _refreshHomeWidget() async {
    final statusLine = await _dashboardNotification.currentStatusLine();
    final openCount = (await TodoService().openItems()).length;
    await _homeWidget.refresh(statusLine: statusLine, openTodoCount: openCount);
  }

  /// Handles a tap on the widget's "Blitz-Notiz" quick action while the app
  /// is already running — see _handleColdStartFromWidget for the
  /// app-was-closed case.
  void _handleWidgetClick(Uri? uri) {
    if (uri?.host == 'quicknote' && mounted) {
      unawaited(_showQuickNoteDialog());
    }
  }

  /// If the app was cold-started by tapping the widget, handles it exactly
  /// like a live tap (see _handleWidgetClick) once the first frame is up.
  Future<void> _handleColdStartFromWidget() async {
    final uri = await _homeWidget.initiallyLaunchedFromWidget();
    if (uri?.host == 'quicknote' && mounted) {
      unawaited(_showQuickNoteDialog());
    }
  }

  /// The widget's "Blitz-Notiz" quick action — adds a to-do without going
  /// through the full chat/CommandRouter flow.
  Future<void> _showQuickNoteDialog() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blitz-Notiz'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Was steht an?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Speichern')),
        ],
      ),
    );
    controller.dispose();
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    await TodoService().add(trimmed);
    unawaited(_refreshHomeWidget());
    unawaited(_dashboardNotification.refresh());
    if (mounted) _showSnack('Aufgabe gespeichert: $trimmed');
  }

  /// The emergency lock (unlike everything else in this screen's state)
  /// persists across an app restart — a forgotten PIN has no
  /// recovery/bypass, by design, matching IntegrityLockdownScreen's
  /// "kein Bypass" precedent — so this must be checked fresh on every cold
  /// start, not just set once in response to a trigger.
  Future<void> _checkAppLockState() async {
    final locked = await _appLock.isLocked();
    if (mounted) setState(() => _appLocked = locked);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncMotionActions());
    } else {
      _motionActions.stop();
    }
  }

  /// (Re-)starts or stops the accelerometer listener to match the current
  /// Einstellungen — called on app start, whenever the app returns to the
  /// foreground, and after leaving Einstellungen (in case a toggle
  /// changed). Skips starting the sensor stream entirely if every motion
  /// toggle is off, so nobody pays a battery cost for a feature they
  /// haven't enabled.
  Future<void> _syncMotionActions() async {
    final faceDownEnabled = await _settings.getFaceDownFocusEnabled();
    final shakeVoiceEnabled = await _settings.getShakeStartsVoiceEnabled();
    final shakeLockEnabled = await _settings.getShakeLocksAppEnabled();
    if (!mounted) return;

    if (!faceDownEnabled && !shakeVoiceEnabled && !shakeLockEnabled) {
      _motionActions.stop();
      return;
    }

    _motionActions.start(
      onFaceDown: () {
        if (faceDownEnabled) unawaited(_enterFocusMode());
      },
      onFaceUp: () {
        if (faceDownEnabled) _exitFocusMode();
      },
      onShake: () {
        // Both may be enabled at once (user's explicit choice) — voice
        // input first, then the lock, so at least the current utterance
        // isn't lost if both fire off the same shake.
        if (shakeVoiceEnabled) unawaited(_handleShakeStartsVoice());
        if (shakeLockEnabled) unawaited(_handleShakeLocksApp());
      },
    );
  }

  /// Shake-to-lock: silently does nothing if no PIN is configured yet,
  /// since locking without a PIN would make the app permanently
  /// inaccessible (EmergencyLockScreen has no bypass, by design).
  Future<void> _handleShakeLocksApp() async {
    if (!await _appLock.hasPinConfigured()) return;
    await _appLock.lock();
    if (mounted) setState(() => _appLocked = true);
  }

  /// Verifies [pin] against the stored PIN and clears the locked state on
  /// success — passed straight into EmergencyLockScreen's onUnlock.
  Future<bool> _tryUnlockApp(String pin) async {
    final correct = await _appLock.unlock(pin);
    if (correct && mounted) setState(() => _appLocked = false);
    return correct;
  }

  /// "Stummer Fokus-Modus" (Handy umdrehen): mutes any active TTS/STT and
  /// shows a HUD banner, until the phone is flipped back up. Deliberately
  /// narrow in scope — no other settings/behavior are touched.
  Future<void> _enterFocusMode() async {
    if (_focusMode) return;
    await _tts.stop();
    await _speech.stop();
    if (!mounted) return;
    setState(() {
      _focusMode = true;
      _listening = false;
    });
  }

  void _exitFocusMode() {
    if (!_focusMode || !mounted) return;
    setState(() => _focusMode = false);
  }

  /// Shake-to-listen: starts the same one-shot voice input as the mic
  /// button, unless a call is already active or it's already listening
  /// (nothing to do then).
  Future<void> _handleShakeStartsVoice() async {
    if (_callActive || _listening || _focusMode) return;
    await _toggleListening();
  }

  /// Initializes workmanager and (re-)registers/cancels the periodic RSS
  /// check to match the current Einstellungen toggle — called on every app
  /// open, same convention as _briefing.rescheduleAll() above.
  Future<void> _syncBackgroundTasks() async {
    await _backgroundTasks.initialize();
    await _backgroundTasks.syncRssFeedTask();
    await _backgroundTasks.syncBackupExportTask();
    await _backgroundTasks.syncDashboardTask();
  }

  /// App-Integritäts-Check (Google Play Integrity API, Android only): if
  /// enabled and a Google Cloud project is configured, requests an
  /// attestation token and has the user's own Worker verify it with Google
  /// (see AppIntegrityService, worker/ai-proxy.js's /integrity/verify).
  /// Only an explicit negative verdict from a *configured* backend locks
  /// the app (see IntegrityLockdownScreen) — anything inconclusive (not
  /// enabled, not configured yet, offline, unsupported platform) leaves the
  /// app working normally, since most installs won't have this set up.
  Future<void> _checkAppIntegrity() async {
    if (!_appIntegrity.isSupported) return;
    if (!await _settings.getIntegrityCheckEnabled()) return;
    final projectNumber = await _settings.getGoogleCloudProjectNumber();
    if (projectNumber == null || projectNumber.trim().isEmpty) return;

    final nonceBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final nonce = base64Url.encode(nonceBytes).replaceAll('=', '');
    final token = await _appIntegrity.requestIntegrityToken(nonce: nonce, cloudProjectNumber: projectNumber);
    if (token == null) return;

    final backendUrl = await _settings.getAiBackendUrl();
    if (backendUrl == null || backendUrl.trim().isEmpty) return;
    final result = await _appIntegrity.verifyWithBackend(
      backendUrl: backendUrl,
      token: token,
      nonce: nonce,
      hmacSecret: await _settings.getAiHmacSecret(),
      certPins: await _settings.getCertPins(),
    );
    if (result == false && mounted) {
      setState(() => _integrityLocked = true);
    }
  }

  /// If it's the first app-open at/after 7:00 today (and the morning
  /// briefing is enabled), plays a short sound intro and speaks the
  /// briefing aloud immediately, in addition to it having already been
  /// scheduled as a silent-until-tapped OS notification via rescheduleAll().
  Future<void> _maybeDeliverMorningAudioBriefing() async {
    final briefingText = await _briefing.claimMorningAudioBriefingIfDue();
    if (briefingText == null || !mounted) return;
    await _soundboard.play('boot');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _messages.add(ChatMessage(briefingText, fromUser: false)));
    _scrollToBottom();
    unawaited(_tts.speak(briefingText));
  }

  /// Small, opt-out-able chance (checked once per app open, at most once a
  /// day — see SecurityBreachService) of a simulated "security breach"
  /// mini-challenge appearing in chat. Puts the router into breach mode so
  /// the user's next message is treated as their answer.
  Future<void> _maybeTriggerSecurityBreach() async {
    if (!await _settings.getSecurityBreachEnabled()) return;
    final challenge = await _securityBreach.maybeTriggerOnOpen();
    if (challenge == null || !mounted) return;
    _router.startBreachChallenge(challenge);
    await _soundboard.play('alert');
    if (!mounted) return;
    setState(() => _messages.add(ChatMessage(challenge.prompt, fromUser: false)));
    _scrollToBottom();
    unawaited(_tts.speak(challenge.prompt));
  }

  Future<void> _loadHudEffectsEnabled() async {
    final enabled = await _settings.getHudEffectsEnabled();
    if (mounted) setState(() => _hudEffectsEnabled = enabled);
  }

  Future<void> _loadReactiveOrbEnabled() async {
    final enabled = await _settings.getReactiveOrbEnabled();
    if (mounted) setState(() => _reactiveOrbEnabled = enabled);
  }

  /// Loads the saved TTS voice/pitch/speech-rate (Einstellungen) so JARVIS
  /// speaks with them from the very first utterance, not just after the
  /// user opens Einstellungen once.
  Future<void> _applyStoredTtsSettings() async {
    final voiceName = await _settings.getTtsVoiceName();
    final voiceLocale = await _settings.getTtsVoiceLocale();
    final pitch = await _settings.getTtsPitch();
    final speechRate = await _settings.getTtsSpeechRate();
    await _tts.applyVoiceSettings(
      voiceName: voiceName,
      voiceLocale: voiceLocale,
      pitch: pitch,
      speechRate: speechRate,
    );
  }

  /// Announces a fired timer the same way any other JARVIS reply is shown:
  /// added to the chat, and spoken.
  void _onTimerFired(String message) {
    if (!mounted) return;
    setState(() => _messages.add(ChatMessage(message, fromUser: false)));
    _scrollToBottom();
    unawaited(_tts.speak(message));
  }

  Future<void> _checkForUpdate() async {
    final update = await UpdateService().checkForUpdate();
    if (update == null || !mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update verfügbar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Eine neue Version (${update.version}) von JARVIS ist verfügbar.'),
            if (update.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Neu in dieser Version:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...update.notes.map((note) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('•  $note'),
                  )),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Später')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(update.apkUrl), mode: LaunchMode.externalApplication);
            },
            child: const Text('Jetzt herunterladen'),
          ),
        ],
      ),
    );
  }

  void _showIOSInstallDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auf dem iPhone installieren'),
        content: const Text(
          'JARVIS lässt sich als App auf deinem Home-Bildschirm installieren:\n\n'
          '1. Öffne diese Seite in Safari\n'
          '2. Tippe unten auf das Teilen-Symbol (Quadrat mit Pfeil nach oben)\n'
          '3. Wähle „Zum Home-Bildschirm"\n'
          '4. Bestätige mit „Hinzufügen"\n\n'
          'Danach startet JARVIS wie eine normale App, mit eigenem Symbol.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Verstanden')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motionActions.stop();
    unawaited(_widgetClickSubscription?.cancel());
    _timer.cancelAll();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _amplitudeDecayTimer?.cancel();
    _orbAmplitude.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Starts the recognizer directly, without re-checking the microphone
  /// permission — used when we already know it's granted (mid-call), so
  /// each turn doesn't pay for an extra platform-channel round trip.
  Future<void> _startListening() async {
    setState(() {
      _listening = true;
      _partialText = '';
    });
    await _speech.listen(
      onResult: (text, isFinal) {
        setState(() => _partialText = text);
        if (isFinal && text.trim().isNotEmpty) {
          _submit(text);
        }
      },
      onSoundLevelChange: _onMicSoundLevelChange,
    );
  }

  /// Feeds VoiceOrbOverlay's reactor-ring pulse from the real microphone
  /// level while listening. speech_to_text's raw level isn't documented for
  /// Android and differs by platform (see SpeechService.listen's doc
  /// comment) — this normalization is a first approximation that would need
  /// calibrating against a real device/microphone, not something verifiable
  /// in a sandbox without one.
  void _onMicSoundLevelChange(double level) {
    if (!mounted || !_reactiveOrbEnabled) return;
    _orbAmplitude.value = (level / 10.0).clamp(0.0, 1.0);
  }

  /// Starts a short repeating decay of _orbAmplitude, called while JARVIS is
  /// speaking: each word-boundary event (see initState's
  /// setWordBoundaryListener) snaps the value back up to 1.0, and this loop
  /// lets it fall back towards 0 between words — approximating a "talking"
  /// pulse, since flutter_tts exposes no real playback-amplitude data.
  void _startAmplitudeDecayLoop() {
    if (!_reactiveOrbEnabled) return;
    _amplitudeDecayTimer?.cancel();
    _amplitudeDecayTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _orbAmplitude.value = (_orbAmplitude.value * 0.82).clamp(0.0, 1.0);
    });
  }

  void _stopAmplitudeDecayLoop() {
    _amplitudeDecayTimer?.cancel();
    _amplitudeDecayTimer = null;
    _orbAmplitude.value = 0.0;
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) showAccessDeniedFlash(context);
      _showSnack('Mikrofon-Berechtigung wird benötigt.');
      return;
    }
    await _startListening();
  }

  Future<void> _toggleCall() async {
    if (_callActive) {
      setState(() {
        _callActive = false;
        _muted = false;
        _speaking = false;
      });
      await _speech.stop();
      await _tts.stop();
      _stopAmplitudeDecayLoop();
      if (_listening) setState(() => _listening = false);
      return;
    }
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) showAccessDeniedFlash(context);
      _showSnack('Mikrofon-Berechtigung wird benötigt.');
      return;
    }
    await _ambient.stop();
    setState(() => _callActive = true);
    await _startListening();
  }

  /// Mutes/unmutes the mic during a call, without ending it — mirrors the
  /// mic button in the full-screen call UI.
  Future<void> _toggleMute() async {
    if (_muted) {
      setState(() => _muted = false);
      if (_callActive && !_processing && !_speaking) {
        await _startListening();
      }
      return;
    }
    setState(() => _muted = true);
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
    }
    _orbAmplitude.value = 0.0;
  }

  /// Clears the conversation and starts fresh, without ending the call —
  /// the reset button in the full-screen call UI.
  Future<void> _resetCall() async {
    await _speech.stop();
    await _tts.stop();
    _stopAmplitudeDecayLoop();
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage('Neues Gespräch, Master. Ich höre.', fromUser: false));
      _processing = false;
      _speaking = false;
      _muted = false;
      _partialText = '';
    });
    if (_callActive) {
      await _startListening();
    }
  }

  /// Opens the camera on top of the call screen — the call keeps running in
  /// the background and resumes once the camera is closed.
  Future<void> _openCameraDuringCall() async {
    final status = await Permission.camera.request();
    if (status.isGranted && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CameraScreen()));
    } else {
      if (mounted) showAccessDeniedFlash(context);
      _showSnack('Kamera-Berechtigung wird benötigt.');
    }
  }

  Future<void> _submit(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(trimmed, fromUser: true));
      _listening = false;
      _partialText = '';
      _textCtrl.clear();
      _processing = true;
    });
    _scrollToBottom();

    final result = await _router.handle(trimmed);
    await _deliverReply(result.reply);

    if (result.openCamera) {
      final status = await Permission.camera.request();
      if (status.isGranted && mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CameraScreen()));
      } else {
        if (mounted) showAccessDeniedFlash(context);
        _showSnack('Kamera-Berechtigung wird benötigt.');
      }
    }

    if (result.qrData != null && mounted) {
      _showQrDialog(result.qrData!);
    }

    if (result.openYoutubeUpload && mounted) {
      final clientId = await _settings.getYoutubeClientId();
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => YoutubeUploadScreen(
              uploadService: YoutubeUploadService(
                webClientId: (clientId != null && clientId.isNotEmpty) ? clientId : null,
              ),
              initialPrivacy: result.youtubePrivacy,
              initialPublishAt: result.youtubePublishAt,
            ),
          ),
        );
      }
    }

    if (result.openTiktokUpload && mounted) {
      final backendUrl = await _settings.getAiBackendUrl();
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TikTokUploadScreen(uploadService: _tiktok, backendUrl: backendUrl ?? ''),
          ),
        );
      }
    }

    if (result.requestMoodCheck && mounted) {
      await _runMoodCheck();
    }

    if (result.openDashboard && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DashboardScreen(gamification: _router.gamification)),
      );
    }

    if (result.triggerAppLock && mounted) {
      await _appLock.lock();
      if (mounted) setState(() => _appLocked = true);
    }

    if (result.triggerFocusModeOn && mounted) {
      await _enterFocusMode();
    }

    if (result.triggerFocusModeOff && mounted) {
      _exitFocusMode();
    }
  }

  /// Shows [reply] as a new chat bubble and speaks it, call-mode aware —
  /// shared by the normal command flow and the mood-check follow-up so
  /// neither has to duplicate the speak/relisten tail.
  Future<void> _deliverReply(String reply) async {
    setState(() {
      _processing = false;
      _messages.add(ChatMessage(reply, fromUser: false));
    });
    _scrollToBottom();
    // Cheap enough to run after every reply, and the simplest way to keep
    // the dashboard notification/widget (status/latency/open-to-do-count)
    // fresh after a chat command mutates to-dos — CommandRouter has no
    // per-mutation callback to hook into instead.
    unawaited(_dashboardNotification.refresh());
    unawaited(_refreshHomeWidget());

    if (_callActive) {
      setState(() => _speaking = true);
      _startAmplitudeDecayLoop();
      await _tts.speakAndWait(reply);
      _stopAmplitudeDecayLoop();
      if (mounted) setState(() => _speaking = false);
      if (_callActive && mounted && !_muted) {
        await _startListening();
      }
    } else {
      unawaited(_tts.speak(reply));
    }
  }

  /// Follow-up triggered by CommandResult.requestMoodCheck ("stimmungscheck"):
  /// confirms mic permission (reusing the existing Permission.microphone
  /// flow, same as _toggleListening/_toggleCall), stops any active
  /// speech_to_text session first (mood capture must be sequential, not
  /// concurrent — see MoodCaptureService), then runs the capture+analysis
  /// and delivers the result like any other reply.
  Future<void> _runMoodCheck() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) showAccessDeniedFlash(context);
      _showSnack('Mikrofon-Berechtigung wird benötigt.');
      return;
    }
    await _speech.stop();
    if (mounted) setState(() => _processing = true);
    final reply = await _router.runMoodCheck();
    if (mounted) await _deliverReply(reply);
  }

  void _showQrDialog(String data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR-Code'),
        content: SizedBox(
          width: 240,
          height: 240,
          child: QrImageView(data: data, size: 240),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')),
        ],
      ),
    );
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  VoiceOrbState get _orbState {
    if (_processing) return VoiceOrbState.thinking;
    if (_speaking) return VoiceOrbState.speaking;
    return VoiceOrbState.listening;
  }

  String get _orbStatusText {
    if (_processing) return 'JARVIS denkt nach…';
    if (_speaking) return 'JARVIS spricht…';
    if (_muted) return 'Mikrofon stumm';
    return _partialText.isEmpty ? 'Ich höre zu…' : _partialText;
  }

  @override
  Widget build(BuildContext context) {
    if (_appLocked) {
      return EmergencyLockScreen(onUnlock: _tryUnlockApp);
    }
    if (_integrityLocked) {
      return const IntegrityLockdownScreen();
    }

    final colorScheme = Theme.of(context).colorScheme;

    if (_callActive) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            VoiceOrbOverlay(
              state: _orbState,
              statusText: _orbStatusText,
              muted: _muted,
              onToggleMute: _toggleMute,
              onEndCall: _toggleCall,
              onReset: _resetCall,
              onOpenCamera: _openCameraDuringCall,
              amplitude: _orbAmplitude,
            ),
            if (_hudEffectsEnabled) const Positioned.fill(child: ScanlineOverlay()),
          ],
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Stack(
            children: [
              if (_hudEffectsEnabled) const Positioned.fill(child: ScanlineOverlay()),
              // Ambient glow — mirrors the blurred radial gradient behind the
              // AETHER web redesign, so the glass header/composer have
              // something to visibly show through.
              Positioned(
                top: -220,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 560,
                    height: 560,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          JarvisColors.accentGlow.withValues(alpha: 0.16),
                          JarvisColors.accentGlow.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  _buildHeader(context, colorScheme),
                  if (_listening)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(
                        _partialText.isEmpty ? 'Ich höre zu…' : _partialText,
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    )
                  else if (_processing)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(
                        'JARVIS denkt nach…',
                        style: TextStyle(color: colorScheme.primary),
                      ),
                    )
                  else if (_focusMode)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(
                        'Fokus-Modus — Handy umdrehen, um zurückzukehren.',
                        style: TextStyle(color: JarvisColors.accent),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => ChatBubble(message: _messages[index]),
                    ),
                  ),
                  _buildComposer(context, colorScheme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: JarvisColors.glassFillStrong,
        border: Border(bottom: BorderSide(color: JarvisColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
                ),
                child: ClipOval(child: SvgPicture.asset('assets/icon/logo.svg')),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'J.A.R.V.I.S.',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BlinkingDot(color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('Online', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              if (kIsWeb) ...[
                IconButton(
                  icon: const Icon(Icons.android),
                  tooltip: 'Für Android herunterladen (APK)',
                  onPressed: () => launchUrl(Uri.base.resolve('downloads/jarvis-mobile.apk')),
                ),
                IconButton(
                  icon: const Icon(Icons.apple),
                  tooltip: 'Für iPhone installieren',
                  onPressed: _showIOSInstallDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.front_hand_outlined),
                  tooltip: 'Gesten-Modus (Handerkennung)',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GestureScreen()),
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          settings: _settings,
                          contacts: _contacts,
                          spotify: _spotify,
                          tiktok: _tiktok,
                          tts: _tts,
                          briefing: _briefing,
                          homeAssistant: HomeAssistantService(),
                          backgroundTasks: _backgroundTasks,
                          webdav: _webdav,
                          offlineLlm: _offlineLlm,
                          notificationHub: NotificationHubService(),
                          homeWidget: _homeWidget,
                        ),
                      ),
                    )
                    .then((_) {
                      unawaited(_loadHudEffectsEnabled());
                      unawaited(_loadReactiveOrbEnabled());
                      unawaited(_syncMotionActions());
                    }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context, ColorScheme colorScheme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          children: [
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickActions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final action = _quickActions[index];
                  return GestureDetector(
                    onTap: _processing ? null : () => _submit(action),
                    child: GlassContainer(
                      borderRadius: BorderRadius.circular(999),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _GlassIconButton(
                  icon: Icons.call,
                  tooltip: 'Gespräch mit JARVIS starten',
                  onTap: _toggleCall,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassContainer(
                    strong: true,
                    borderRadius: BorderRadius.circular(999),
                    padding: const EdgeInsets.all(6),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                    ],
                    child: Row(
                      children: [
                        _RoundActionButton(
                          icon: _listening ? Icons.mic : Icons.mic_none,
                          active: _listening,
                          onTap: _toggleListening,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _textCtrl,
                            enabled: !_processing,
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: _listening ? 'Ich höre zu…' : 'Nachricht an JARVIS…',
                              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                            onSubmitted: _processing ? null : _submit,
                          ),
                        ),
                        _RoundActionButton(
                          icon: Icons.arrow_upward,
                          filled: true,
                          onTap: _processing ? null : () => _submit(_textCtrl.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Verschlüsselte Verbindung aktiv',
              style: TextStyle(fontSize: 10.5, letterSpacing: 0.3, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(999),
      child: Tooltip(
        message: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({required this.icon, required this.onTap, this.active = false, this.filled = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlighted = active || (filled && onTap != null);
    return Material(
      color: highlighted ? colorScheme.primary : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 18,
            color: highlighted
                ? colorScheme.onPrimary
                : (onTap == null ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
