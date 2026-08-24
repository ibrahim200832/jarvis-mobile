import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class _ChangelogSection {
  _ChangelogSection(this.title, this.bullets);

  final String title;
  final List<String> bullets;
}

/// Shows the full version history from CHANGELOG.md (bundled as an asset —
/// see pubspec.yaml), not just the newest section the "Update verfügbar"
/// dialog shows (see UpdateService/deploy-web.yml, which only extracts the
/// topmost "## " section for that dialog).
class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  static List<_ChangelogSection> _parse(String raw) {
    final sections = <_ChangelogSection>[];
    String? currentTitle;
    var bullets = <String>[];

    void flush() {
      if (currentTitle != null) sections.add(_ChangelogSection(currentTitle, bullets));
    }

    for (final line in raw.split('\n')) {
      if (line.startsWith('## ')) {
        flush();
        currentTitle = line.substring(3).trim();
        bullets = [];
      } else if (line.startsWith('- ') && currentTitle != null) {
        bullets.add(line.substring(2).trim());
      }
    }
    flush();
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Änderungsverlauf')),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('CHANGELOG.md'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sections = _parse(snapshot.data!);
          if (sections.isEmpty) {
            return const Center(child: Text('Kein Änderungsverlauf verfügbar.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...section.bullets.map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $b'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
