import 'package:flutter/services.dart';

/// One quick-reference entry: the code itself plus a one-line explanation.
class CodeSnippet {
  final String title;
  final String code;
  final String explanation;

  const CodeSnippet({required this.title, required this.code, required this.explanation});
}

/// A curated developer quick-reference: common Flutter widgets and Git
/// commands JARVIS can look up on request and copy straight to the
/// clipboard, so you don't have to leave the conversation to grab boilerplate.
class CodeSnippetService {
  static const Map<String, CodeSnippet> _snippets = {
    'statefulwidget': CodeSnippet(
      title: 'StatefulWidget',
      explanation: 'Ein Widget mit veränderlichem Zustand, aufgeteilt in Widget- und State-Klasse.',
      code: 'class MyWidget extends StatefulWidget {\n'
          '  const MyWidget({super.key});\n\n'
          '  @override\n'
          '  State<MyWidget> createState() => _MyWidgetState();\n'
          '}\n\n'
          'class _MyWidgetState extends State<MyWidget> {\n'
          '  @override\n'
          '  Widget build(BuildContext context) {\n'
          '    return Container();\n'
          '  }\n'
          '}',
    ),
    'statelesswidget': CodeSnippet(
      title: 'StatelessWidget',
      explanation: 'Ein Widget ohne eigenen veränderlichen Zustand — baut nur einmal aus seinen Parametern.',
      code: 'class MyWidget extends StatelessWidget {\n'
          '  const MyWidget({super.key});\n\n'
          '  @override\n'
          '  Widget build(BuildContext context) {\n'
          '    return Container();\n'
          '  }\n'
          '}',
    ),
    'listview.builder': CodeSnippet(
      title: 'ListView.builder',
      explanation: 'Baut Listeneinträge erst beim Scrollen, effizient auch für lange/unbekannte Listenlängen.',
      code: 'ListView.builder(\n'
          '  itemCount: items.length,\n'
          '  itemBuilder: (context, index) {\n'
          '    return ListTile(title: Text(items[index]));\n'
          '  },\n'
          ')',
    ),
    'futurebuilder': CodeSnippet(
      title: 'FutureBuilder',
      explanation: 'Baut die UI abhängig vom Status eines Future (lädt/fertig/Fehler) neu.',
      code: 'FutureBuilder<String>(\n'
          '  future: myFuture,\n'
          '  builder: (context, snapshot) {\n'
          '    if (snapshot.connectionState != ConnectionState.done) {\n'
          '      return const CircularProgressIndicator();\n'
          '    }\n'
          '    if (snapshot.hasError) return Text(\'Fehler: \${snapshot.error}\');\n'
          '    return Text(snapshot.data ?? \'\');\n'
          '  },\n'
          ')',
    ),
    'textfield': CodeSnippet(
      title: 'TextField',
      explanation: 'Standard-Texteingabefeld mit Controller und Label.',
      code: 'TextField(\n'
          '  controller: myController,\n'
          '  decoration: const InputDecoration(labelText: \'Name\', border: OutlineInputBorder()),\n'
          ')',
    ),
    'elevatedbutton': CodeSnippet(
      title: 'ElevatedButton',
      explanation: 'Der Standard-Aktionsbutton mit Schatten/Hintergrund.',
      code: 'ElevatedButton(\n'
          '  onPressed: () {},\n'
          '  child: const Text(\'Los\'),\n'
          ')',
    ),
    'streambuilder': CodeSnippet(
      title: 'StreamBuilder',
      explanation: 'Baut die UI bei jedem neuen Wert eines Stream neu.',
      code: 'StreamBuilder<int>(\n'
          '  stream: myStream,\n'
          '  builder: (context, snapshot) {\n'
          '    return Text(\'\${snapshot.data ?? 0}\');\n'
          '  },\n'
          ')',
    ),
    'git commit': CodeSnippet(
      title: 'Git: Commit erstellen',
      explanation: 'Änderungen stagen und mit Nachricht committen.',
      code: 'git add .\ngit commit -m "Beschreibung der Änderung"',
    ),
    'git push': CodeSnippet(
      title: 'Git: Push',
      explanation: 'Lokale Commits zum Remote-Branch hochladen (mit -u beim ersten Mal, um Tracking zu setzen).',
      code: 'git push -u origin mein-branch',
    ),
    'git pull': CodeSnippet(
      title: 'Git: Pull',
      explanation: 'Neueste Änderungen vom Remote-Branch holen und einmergen.',
      code: 'git pull origin mein-branch',
    ),
    'git branch': CodeSnippet(
      title: 'Git: Branch erstellen',
      explanation: 'Neuen Branch erstellen und direkt zu ihm wechseln.',
      code: 'git checkout -b neuer-branch',
    ),
    'git stash': CodeSnippet(
      title: 'Git: Stash',
      explanation: 'Unfertige Änderungen beiseitelegen, um z.B. kurz den Branch zu wechseln.',
      code: 'git stash\ngit stash pop',
    ),
    'git log': CodeSnippet(
      title: 'Git: Log',
      explanation: 'Kompakte Commit-Historie ansehen, ein Commit pro Zeile.',
      code: 'git log --oneline -10',
    ),
    'git merge': CodeSnippet(
      title: 'Git: Merge',
      explanation: 'Einen anderen Branch in den aktuellen einmergen.',
      code: 'git merge anderer-branch',
    ),
    'git rebase': CodeSnippet(
      title: 'Git: Rebase',
      explanation: 'Eigene Commits auf den neuesten Stand eines anderen Branches umsetzen.',
      code: 'git rebase main',
    ),
    'git reset': CodeSnippet(
      title: 'Git: Reset',
      explanation: 'Den letzten Commit rückgängig machen, Änderungen aber behalten (soft reset).',
      code: 'git reset --soft HEAD~1',
    ),
    'git clone': CodeSnippet(
      title: 'Git: Clone',
      explanation: 'Ein Remote-Repository lokal herunterladen.',
      code: 'git clone https://github.com/nutzer/repo.git',
    ),
    'git status': CodeSnippet(
      title: 'Git: Status',
      explanation: 'Zeigt geänderte, gestagte und unversionierte Dateien im Arbeitsverzeichnis.',
      code: 'git status',
    ),
  };

  /// Finds the best-matching snippet for a free-text query (e.g. "git commit"
  /// or "statefulwidget"), trying an exact key match first, then a loose
  /// substring match in either direction. Returns null if nothing fits.
  MapEntry<String, CodeSnippet>? find(String query) {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) return null;
    final exact = _snippets[normalized];
    if (exact != null) return MapEntry(normalized, exact);
    for (final entry in _snippets.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return entry;
      }
    }
    return null;
  }

  List<String> get availableTitles => _snippets.values.map((s) => s.title).toList();

  Future<void> copyToClipboard(String code) => Clipboard.setData(ClipboardData(text: code));
}
