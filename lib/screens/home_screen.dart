import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/command_router.dart';
import '../services/ai_chat_service.dart';
import '../services/app_launcher_service.dart';
import '../services/call_service.dart';
import '../services/contacts_service.dart';
import '../services/device_info_service.dart';
import '../services/email_service.dart';
import '../services/ip_service.dart';
import '../services/joke_service.dart';
import '../services/location_service.dart';
import '../services/news_service.dart';
import '../services/qr_service.dart';
import '../services/settings_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/update_service.dart';
import '../services/weather_service.dart';
import '../services/whatsapp_service.dart';
import '../services/wikipedia_service.dart';
import '../services/youtube_service.dart';
import '../widgets/chat_bubble.dart';
import 'camera_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _speech = SpeechService();
  final _tts = TtsService();
  final _settings = SettingsService();
  final _contacts = ContactsService();
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
  String _partialText = '';

  @override
  void initState() {
    super.initState();
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
      aiChat: AiChatService(),
      deviceInfo: DeviceInfoService(),
    );
    _speech.init();
    unawaited(_checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final update = await UpdateService().checkForUpdate();
    if (update == null || !mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update verfügbar'),
        content: Text('Eine neue Version (${update.version}) von JARVIS ist verfügbar.'),
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
    _textCtrl.dispose();
    _scrollCtrl.dispose();
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
    );
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _showSnack('Mikrofon-Berechtigung wird benötigt.');
      return;
    }
    await _startListening();
  }

  Future<void> _toggleCall() async {
    if (_callActive) {
      setState(() => _callActive = false);
      await _speech.stop();
      await _tts.stop();
      if (_listening) setState(() => _listening = false);
      return;
    }
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _showSnack('Mikrofon-Berechtigung wird benötigt.');
      return;
    }
    setState(() => _callActive = true);
    _showSnack('Gespräch gestartet — rede einfach ganz normal mit JARVIS.');
    await _startListening();
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

    setState(() {
      _processing = false;
      _messages.add(ChatMessage(result.reply, fromUser: false));
    });
    _scrollToBottom();

    if (_callActive) {
      await _tts.speakAndWait(result.reply);
      if (_callActive && mounted) {
        await _startListening();
      }
    } else {
      unawaited(_tts.speak(result.reply));
    }

    if (result.openCamera) {
      final status = await Permission.camera.request();
      if (status.isGranted && mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CameraScreen()));
      } else {
        _showSnack('Kamera-Berechtigung wird benötigt.');
      }
    }

    if (result.qrData != null && mounted) {
      _showQrDialog(result.qrData!);
    }
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary.withValues(alpha: 0.25), colorScheme.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            ClipOval(
              child: SvgPicture.asset('assets/icon/logo.svg', width: 36, height: 36),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('J.A.R.V.I.S.', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  _callActive ? 'Gespräch läuft…' : 'Dein persönlicher Assistent',
                  style: TextStyle(fontSize: 12, color: _callActive ? colorScheme.primary : null),
                ),
              ],
            ),
          ],
        ),
        actions: [
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
          ],
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(settings: _settings, contacts: _contacts),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => ChatBubble(message: _messages[index]),
                ),
              ),
              if (_listening)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _partialText.isEmpty ? 'Ich höre zu…' : _partialText,
                    style: TextStyle(color: colorScheme.primary),
                  ),
                )
              else if (_processing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'JARVIS denkt nach…',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        iconSize: 30,
                        icon: Icon(_callActive ? Icons.call_end : Icons.call),
                        color: _callActive ? Colors.red : null,
                        tooltip: _callActive ? 'Gespräch beenden' : 'Gespräch mit JARVIS starten',
                        onPressed: _toggleCall,
                      ),
                      IconButton(
                        iconSize: 32,
                        icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                        color: _listening ? Colors.red : null,
                        onPressed: _toggleListening,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          decoration: InputDecoration(
                            hintText: 'Nachricht an JARVIS…',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          ),
                          onSubmitted: _submit,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        icon: const Icon(Icons.send),
                        onPressed: () => _submit(_textCtrl.text),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
