import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/youtube_upload_service.dart';

/// Lets the user sign in with Google and upload one video from their device
/// to their own YouTube channel — every step (sign-in, file pick, privacy
/// choice, title, upload) is a deliberate tap, never automatic.
class YoutubeUploadScreen extends StatefulWidget {
  const YoutubeUploadScreen({super.key, required this.uploadService, this.initialPrivacy, this.initialPublishAt});

  final YoutubeUploadService uploadService;

  /// Pre-selected privacy status ('private'/'unlisted'/'public'), e.g. from
  /// a voice command or AI tool call. The user can still change it before
  /// confirming the upload.
  final String? initialPrivacy;

  /// Pre-selected scheduled publish time, from the same sources.
  final DateTime? initialPublishAt;

  @override
  State<YoutubeUploadScreen> createState() => _YoutubeUploadScreenState();
}

class _YoutubeUploadScreenState extends State<YoutubeUploadScreen> {
  final _titleCtrl = TextEditingController(text: 'JARVIS Upload');
  XFile? _pickedFile;
  bool _busy = false;
  String? _resultUrl;
  String? _error;
  late String _privacy;
  DateTime? _publishAt;

  @override
  void initState() {
    super.initState();
    _privacy = widget.initialPrivacy ?? 'private';
    _publishAt = widget.initialPublishAt;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.uploadService.signIn();
    } catch (e) {
      setState(() => _error = 'Anmeldung fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _pickedFile = picked;
      _resultUrl = null;
      _error = null;
    });
  }

  Future<void> _upload() async {
    final file = _pickedFile;
    if (file == null) {
      setState(() => _error = 'Bitte zuerst ein Video auswählen.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _resultUrl = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final url = await widget.uploadService.uploadVideo(
        videoBytes: bytes,
        title: _titleCtrl.text.trim().isEmpty ? file.name : _titleCtrl.text.trim(),
        privacyStatus: _privacy,
        publishAt: _publishAt,
      );
      setState(() => _resultUrl = url);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPublishAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _publishAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_publishAt ?? now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (combined.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      setState(() => _error = 'Der Veröffentlichungszeitpunkt muss in der Zukunft liegen.');
      return;
    }
    setState(() {
      _publishAt = combined;
      _privacy = 'private'; // YouTube verlangt privat bei Zeitplanung
      _error = null;
    });
  }

  String _privacyLabel(String p) => switch (p) {
    'private' => 'privat',
    'unlisted' => 'nicht gelistet',
    'public' => 'öffentlich',
    _ => p,
  };

  @override
  Widget build(BuildContext context) {
    final account = widget.uploadService.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube-Upload')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(account == null ? 'Nicht bei Google angemeldet' : account.email),
              trailing: FilledButton(
                onPressed: _busy ? null : _signIn,
                child: Text(account == null ? 'Anmelden' : 'Erneut anmelden'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickVideo,
            icon: const Icon(Icons.video_file_outlined),
            label: Text(_pickedFile == null ? 'Video auswählen' : _pickedFile!.name),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Titel', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'private', label: Text('Privat'), icon: Icon(Icons.lock_outline)),
              ButtonSegment(value: 'unlisted', label: Text('Nicht gelistet'), icon: Icon(Icons.link)),
              ButtonSegment(value: 'public', label: Text('Öffentlich'), icon: Icon(Icons.public)),
            ],
            selected: {_privacy},
            onSelectionChanged: (_busy || _publishAt != null) ? null : (s) => setState(() => _privacy = s.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickPublishAt,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(
                    _publishAt == null
                        ? 'Später veröffentlichen (optional)'
                        : 'Veröffentlichung: ${DateFormat('dd.MM.yyyy HH:mm').format(_publishAt!)}',
                  ),
                ),
              ),
              if (_publishAt != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _busy ? null : () => setState(() => _publishAt = null),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy || _pickedFile == null ? null : _upload,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(
              _busy
                  ? 'Lädt hoch…'
                  : _publishAt != null
                  ? 'Upload planen'
                  : 'Auf YouTube hochladen (${_privacyLabel(_privacy)})',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _publishAt != null
                ? 'Das Video wird privat hochgeladen und automatisch am '
                      '${DateFormat("dd.MM.yyyy 'um' HH:mm").format(_publishAt!)} Uhr veröffentlicht.'
                : switch (_privacy) {
                    'private' =>
                      'Das Video wird als "privat" hochgeladen — sichtbar nur für dich. '
                          'Öffentlich machen kannst du es danach selbst in YouTube Studio.',
                    'unlisted' =>
                      'Das Video wird als "nicht gelistet" hochgeladen — nur über den direkten Link '
                          'sichtbar, nicht in Suche oder auf deinem Kanal.',
                    _ => 'Das Video wird sofort öffentlich auf YouTube sichtbar.',
                  },
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_resultUrl != null) ...[
            const SizedBox(height: 16),
            Text('Hochgeladen: $_resultUrl'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => launchUrl(Uri.parse(_resultUrl!), mode: LaunchMode.externalApplication),
              child: const Text('Video öffnen'),
            ),
          ],
        ],
      ),
    );
  }
}
