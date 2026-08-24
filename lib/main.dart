import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'theme/jarvis_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE');
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = buildJarvisTheme();
    return MaterialApp(
      title: 'J.A.R.V.I.S.',
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
