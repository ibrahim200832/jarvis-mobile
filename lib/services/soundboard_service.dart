import 'package:audioplayers/audioplayers.dart';

/// A small board of original, synthesized sci-fi UI sound effects (no
/// sampled/copyrighted movie audio) JARVIS can play on request — HUD clicks,
/// a boot-up chime, a scanning sweep, and similar.
class SoundboardService {
  // Created lazily (not as a field initializer) so a test subclass that
  // overrides play() with a no-op never touches the real audioplayers
  // platform channel, which isn't mocked in plain unit tests.
  AudioPlayer? _player;
  AudioPlayer get _audioPlayer => _player ??= AudioPlayer();

  static const Map<String, String> _sounds = {
    'click': 'sounds/click.wav',
    'bestätigung': 'sounds/confirm.wav',
    'confirm': 'sounds/confirm.wav',
    'fehler': 'sounds/error.wav',
    'error': 'sounds/error.wav',
    'scan': 'sounds/scan.wav',
    'boot': 'sounds/boot.wav',
    'hochfahren': 'sounds/boot.wav',
    'shutdown': 'sounds/shutdown.wav',
    'herunterfahren': 'sounds/shutdown.wav',
    'alarm': 'sounds/alert.wav',
    'warnung': 'sounds/alert.wav',
    'benachrichtigung': 'sounds/notification.wav',
    'notification': 'sounds/notification.wav',
  };

  /// Distinct sound names for the help/listing text (dedupes German/English
  /// synonyms that point at the same file).
  List<String> get availableNames {
    final seen = <String>{};
    final names = <String>[];
    for (final entry in _sounds.entries) {
      if (seen.add(entry.value)) names.add(entry.key);
    }
    return names;
  }

  bool has(String name) => _sounds.containsKey(name.toLowerCase().trim());

  Future<void> play(String name) async {
    final asset = _sounds[name.toLowerCase().trim()];
    if (asset == null) return;
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(asset));
  }
}
