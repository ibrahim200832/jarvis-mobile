/// A search query + a short human-readable label for one music
/// recommendation, e.g. query "chill relax lofi" / label "Entspannungs-Musik".
typedef MoodPick = ({String query, String label});

/// Picks a fitting Spotify search query for a described mood/activity, or
/// falls back to the current time of day when none is given — so JARVIS can
/// recommend/play something appropriate without the user needing to name an
/// exact playlist. Pure lookup logic; actual playback goes through
/// SpotifyService.playMoodPlaylist.
class MusicDjService {
  static const Map<String, MoodPick> _moods = {
    'fokus': (query: 'focus deep work instrumental', label: 'Fokus-Musik'),
    'arbeiten': (query: 'focus deep work instrumental', label: 'Fokus-Musik'),
    'konzentrieren': (query: 'focus deep work instrumental', label: 'Fokus-Musik'),
    'lernen': (query: 'focus deep work instrumental', label: 'Lern-Musik'),
    'entspannen': (query: 'chill relax lofi', label: 'Entspannungs-Musik'),
    'chillen': (query: 'chill relax lofi', label: 'Chill-Musik'),
    'relax': (query: 'chill relax lofi', label: 'Entspannungs-Musik'),
    'workout': (query: 'workout gym pump up', label: 'Workout-Musik'),
    'sport': (query: 'workout gym pump up', label: 'Workout-Musik'),
    'training': (query: 'workout gym pump up', label: 'Workout-Musik'),
    'party': (query: 'party dance hits', label: 'Party-Musik'),
    'feiern': (query: 'party dance hits', label: 'Party-Musik'),
    'schlafen': (query: 'sleep calm ambient', label: 'Einschlaf-Musik'),
    'einschlafen': (query: 'sleep calm ambient', label: 'Einschlaf-Musik'),
    'motivation': (query: 'motivation hype', label: 'Motivations-Musik'),
    'gute laune': (query: 'feel good happy hits', label: 'Gute-Laune-Musik'),
  };

  /// Matches free-text [moodText] against known mood keywords (loose
  /// substring, case-insensitive). Returns null if nothing matches.
  MoodPick? forMood(String moodText) {
    final lower = moodText.toLowerCase();
    for (final entry in _moods.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  List<String> get knownMoods => _moods.keys.toList();

  /// Falls back to a sensible pick based on the current time of day.
  MoodPick forTimeOfDay([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour >= 5 && hour < 11) return (query: 'morning energize wake up', label: 'Morgen-Musik');
    if (hour >= 11 && hour < 17) return (query: 'focus deep work instrumental', label: 'Fokus-Musik');
    if (hour >= 17 && hour < 22) return (query: 'chill relax lofi', label: 'Abend-Musik');
    return (query: 'sleep calm ambient', label: 'Nacht-Musik');
  }
}
