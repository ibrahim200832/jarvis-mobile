import 'package:audioplayers/audioplayers.dart';

/// Looping background ambient soundscapes ("Dynamische Soundscapes") —
/// originally synthesized audio (colored noise / additive synthesis), no
/// sampled/copyrighted material, same precedent as SoundboardService's
/// original sci-fi UI sounds. Uses its own separate AudioPlayer instance
/// (not SoundboardService's) so a one-shot HUD click can layer on top of a
/// running ambient bed instead of interrupting it.
class AmbientSoundService {
  // Lazy, not a field initializer, so a test Fake overriding play()/stop()
  // never touches the real audioplayers platform channel — same pattern as
  // SoundboardService.
  AudioPlayer? _player;
  AudioPlayer get _audioPlayer => _player ??= AudioPlayer();

  static const Map<String, String> _sounds = {
    'regen': 'sounds/ambient_rain.wav',
    'regengeräusche': 'sounds/ambient_rain.wav',
    'rain': 'sounds/ambient_rain.wav',
    'café': 'sounds/ambient_cafe.wav',
    'cafe': 'sounds/ambient_cafe.wav',
    'café-geräusche': 'sounds/ambient_cafe.wav',
    'lofi': 'sounds/ambient_lofi.wav',
    'lofi hintergrundmusik': 'sounds/ambient_lofi.wav',
  };

  String? _current;
  String? get current => _current;

  /// Distinct soundscape names for the help/listing text (dedupes synonyms
  /// that point at the same file).
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
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource(asset));
    _current = name.toLowerCase().trim();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _current = null;
  }
}
