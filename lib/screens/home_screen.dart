import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/command_router.dart';
import '../services/app_launcher_service.dart';
import '../services/call_service.dart';
import '../services/contacts_service.dart';
import '../services/email_service.dart';
import '../services/ip_service.dart';
import '../services/joke_service.dart';
import '../services/location_service.dart';
import '../services/news_service.dart';
import '../services/qr_service.dart';
import '../services/settings_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
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
    ChatMessage('Hallo! Ich bin JARVIS. Sag "Hilfe" für eine Liste meiner Befehle.', fromUser: false),
  ];
  bool _listening = false;
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
    );
    _speech.init();
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

  Future<void> _submit(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(trimmed, fromUser: true));
      _listening = false;
      _partialText = '';
      _textCtrl.clear();
    });
    _scrollToBottom();

    final result = await _router.handle(trimmed);

    setState(() {
      _messages.add(ChatMessage(result.reply, fromUser: false));
    });
    _scrollToBottom();
    unawaited(_tts.speak(result.reply));

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
            CircleAvatar(
              backgroundColor: colorScheme.primary,
              child: Icon(Icons.graphic_eq, color: colorScheme.onPrimary),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('J.A.R.V.I.S.', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Dein persönlicher Assistent', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
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
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
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
