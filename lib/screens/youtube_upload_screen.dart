import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/youtube_upload_service.dart';

/// Lets the user sign in with Google and upload one video from their device
/// to their own YouTube channel — every step (sign-in, file pick, title,
/// upload) is a deliberate tap, never automatic.
class YoutubeUploadScreen extends StatefulWidget {
  const YoutubeUploadScreen({super.key, required this.uploadService});

  final YoutubeUploadService uploadService;

  @override
  State<YoutubeUploadScreen> createState() => _YoutubeUploadScreenState();
}

class _YoutubeUploadScreenState extends State<YoutubeUploadScreen> {
  final _titleCtrl = TextEditingController(text: 'JARVIS Upload');
  XFile? _pickedFile;
  bool _busy = false;
  String? _resultUrl;
  String? _error;

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
      );
      setState(() => _resultUrl = url);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
          FilledButton.icon(
            onPressed: _busy || _pickedFile == null ? null : _upload,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_busy ? 'Lädt hoch…' : 'Auf YouTube hochladen (privat)'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Das Video wird zunächst als "privat" hochgeladen — sichtbar nur für dich. '
            'Öffentlich machen kannst du es danach selbst in YouTube Studio.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
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
