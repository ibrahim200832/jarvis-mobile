import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/tiktok_upload_service.dart';

/// Human-readable labels for TikTok's privacy_level values. Falls back to
/// the raw value for anything not covered here, so a future/unfamiliar
/// option from creator_info still displays instead of disappearing.
String _privacyLabel(String value) => switch (value) {
  'SELF_ONLY' => 'Nur ich (privat)',
  'MUTUAL_FOLLOW_FRIENDS' => 'Nur Freunde',
  'FOLLOWER_OF_CREATOR' => 'Follower',
  'PUBLIC_TO_EVERYONE' => 'Öffentlich',
  _ => value,
};

/// Lets the user upload one video from their device to their own TikTok
/// account. Connecting happens exclusively in Einstellungen (like Spotify),
/// so this screen only handles picking a file, choosing visibility, and
/// uploading — every step a deliberate tap, never automatic.
class TikTokUploadScreen extends StatefulWidget {
  const TikTokUploadScreen({super.key, required this.uploadService, required this.backendUrl});

  final TikTokUploadService uploadService;
  final String backendUrl;

  @override
  State<TikTokUploadScreen> createState() => _TikTokUploadScreenState();
}

class _TikTokUploadScreenState extends State<TikTokUploadScreen> {
  final _titleCtrl = TextEditingController(text: 'JARVIS Upload');
  XFile? _pickedFile;
  bool _busy = false;
  bool _connected = false;
  bool _loadingCreatorInfo = true;
  TikTokCreatorInfo? _creatorInfo;
  String? _privacy;
  String? _resultMessage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final connected = await widget.uploadService.isConnected();
    if (!mounted) return;
    setState(() {
      _connected = connected;
      _loadingCreatorInfo = connected;
    });
    if (!connected) return;

    final info = await widget.uploadService.getCreatorInfo(widget.backendUrl);
    if (!mounted) return;
    setState(() {
      _creatorInfo = info;
      _loadingCreatorInfo = false;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _pickedFile = picked;
      _resultMessage = null;
      _error = null;
    });
  }

  Future<void> _upload() async {
    final file = _pickedFile;
    final privacy = _privacy;
    if (file == null || privacy == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _resultMessage = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final message = await widget.uploadService.uploadVideo(
        widget.backendUrl,
        videoBytes: bytes,
        title: _titleCtrl.text.trim().isEmpty ? file.name : _titleCtrl.text.trim(),
        privacyLevel: privacy,
      );
      setState(() => _resultMessage = message);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TikTok-Upload')),
      body: !_connected
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Bitte zuerst in den Einstellungen mit TikTok verbinden.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Zurück'),
                  ),
                ],
              ),
            )
          : _loadingCreatorInfo
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_creatorInfo != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.account_circle_outlined),
                      title: Text('Verbunden als @${_creatorInfo!.nickname}'),
                      subtitle: Text('Max. ${_creatorInfo!.maxVideoPostDurationSec} Sekunden pro Video'),
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
                  decoration: const InputDecoration(labelText: 'Titel/Beschreibung', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _privacy,
                  decoration: const InputDecoration(labelText: 'Sichtbarkeit', border: OutlineInputBorder()),
                  hint: const Text('Bitte wählen'),
                  items: (_creatorInfo?.privacyLevelOptions ?? const ['SELF_ONLY'])
                      .map((p) => DropdownMenuItem(value: p, child: Text(_privacyLabel(p))))
                      .toList(),
                  onChanged: _busy ? null : (value) => setState(() => _privacy = value),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Solange deine TikTok-App kein TikTok-Audit bestanden hat, landet jedes Video automatisch als '
                  '"Nur ich" (privat) auf TikTok — unabhängig von der Auswahl hier.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy || _pickedFile == null || _privacy == null ? null : _upload,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(_busy ? 'Lädt hoch…' : 'Auf TikTok hochladen'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                if (_resultMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_resultMessage!),
                ],
              ],
            ),
    );
  }
}
