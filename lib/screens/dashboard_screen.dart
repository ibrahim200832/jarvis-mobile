import 'package:flutter/material.dart';

import '../services/gamification_service.dart';
import '../theme/jarvis_theme.dart';
import '../widgets/glass_container.dart';

/// Real-Life-RPG dashboard: a visual view of the same XP/level/achievement
/// state GamificationService already tracks (used elsewhere as plain text
/// in statusText()), plus the new self-reported Energie bar and a
/// rule-based tactical tip. Read-only — sleep is reported via the
/// "ich habe X stunden geschlafen" chat command, not a form here.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.gamification});

  final GamificationService gamification;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.gamification.dashboardData();
    if (mounted) setState(() => _data = data);
  }

  Color _energyColor(JarvisPaletteExtension palette, int energy) {
    if (energy < 30) return palette.error;
    if (energy < 60) return palette.accent;
    return const Color(0xFF6FCF97);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<JarvisPaletteExtension>()!;
    final data = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Lebens-Dashboard')),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level ${data.level} · ${data.rank}',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: palette.accent, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text('XP: ${data.xp} / ${data.xpForNextLevel}'),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: data.xpProgress,
                            minHeight: 10,
                            backgroundColor: palette.secondary,
                            color: palette.accent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Energie: ${data.energy}%'),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: data.energy / 100,
                            minHeight: 10,
                            backgroundColor: palette.secondary,
                            color: _energyColor(palette, data.energy),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Basiert auf "ich habe X Stunden geschlafen" — sinkt ohne neue Meldung langsam.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Charakter-Optimierung', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(data.tacticalAdvice),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Erfolge', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (data.unlockedAchievementTitles.isEmpty)
                          const Text('Noch keine Erfolge freigeschaltet.')
                        else
                          ...data.unlockedAchievementTitles.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Color(0xFF6FCF97), size: 18),
                                  const SizedBox(width: 8),
                                  Text(t),
                                ],
                              ),
                            ),
                          ),
                        if (data.lockedAchievementTitles.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Noch offen: ${data.lockedAchievementTitles.join(', ')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
