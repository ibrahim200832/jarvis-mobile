import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/screens/telemetry_screen.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:jarvis_mobile/services/settings_service.dart';
import 'package:jarvis_mobile/services/telemetry_admin_service.dart';
import 'package:jarvis_mobile/theme/jarvis_theme.dart';

/// Never actually touched — every method TelemetryScreen calls is
/// overridden below, this is only here to satisfy TelemetryAdminService's
/// constructor without hitting a real platform channel.
class _NoopSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

class _FakeTelemetryAdminService extends TelemetryAdminService {
  _FakeTelemetryAdminService({
    this.installs = const [],
    this.errorsByInstall = const {},
    this.setOverrideResult = true,
  }) : super(settings: SettingsService(secureStorage: _NoopSecureStorage()));

  final List<InstallSummary> installs;
  final Map<String, List<InstallError>> errorsByInstall;
  final bool setOverrideResult;
  String? lastOverrideInstallId;
  bool? lastOverrideValue;
  bool overrideWasCalled = false;

  @override
  Future<List<InstallSummary>> listInstalls() async => installs;

  @override
  Future<List<InstallError>> getInstallErrors(String installId) async => errorsByInstall[installId] ?? [];

  @override
  Future<bool> setRemoteOverride(String installId, {required bool? forceLocalAi}) async {
    overrideWasCalled = true;
    lastOverrideInstallId = installId;
    lastOverrideValue = forceLocalAi;
    return setOverrideResult;
  }
}

InstallSummary _install({
  String installId = 'install-a',
  int errorCount = 0,
  bool? forceLocalAiEnabled,
}) => InstallSummary(
  installId: installId,
  firstSeen: DateTime(2026, 1, 1),
  lastSeen: DateTime(2026, 1, 2, 12),
  appVersion: '1.0.0+1',
  platform: 'android',
  errorCount: errorCount,
  forceLocalAiEnabled: forceLocalAiEnabled,
);

void main() {
  Future<void> pumpScreen(WidgetTester tester, TelemetryAdminService service) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildJarvisTheme(), home: TelemetryScreen(telemetryAdmin: service)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an empty-state hint when no installs are reported', (tester) async {
    await pumpScreen(tester, _FakeTelemetryAdminService());

    expect(find.textContaining('Noch keine Installation gemeldet'), findsOneWidget);
  });

  testWidgets('lists installs with platform/version and an error-count badge', (tester) async {
    await pumpScreen(
      tester,
      _FakeTelemetryAdminService(installs: [_install(installId: 'install-a', errorCount: 3)]),
    );

    expect(find.text('install-a'), findsOneWidget);
    expect(find.textContaining('android'), findsOneWidget);
    expect(find.textContaining('1.0.0+1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tapping an install opens its detail screen with recent errors', (tester) async {
    final service = _FakeTelemetryAdminService(
      installs: [_install(installId: 'install-a', errorCount: 1)],
      errorsByInstall: {
        'install-a': [
          InstallError(level: 'error', source: 'FlutterError', message: 'ein Testfehler', createdAt: DateTime(2026, 1, 2)),
        ],
      },
    );
    await pumpScreen(tester, service);

    await tester.tap(find.text('install-a'));
    await tester.pumpAndSettle();

    expect(find.text('ein Testfehler'), findsOneWidget);
    expect(find.text('FlutterError'), findsOneWidget);
  });

  testWidgets('shows the empty state when an install has no errors', (tester) async {
    final service = _FakeTelemetryAdminService(installs: [_install(installId: 'install-a')]);
    await pumpScreen(tester, service);

    await tester.tap(find.text('install-a'));
    await tester.pumpAndSettle();

    expect(find.text('Keine Fehler protokolliert.'), findsOneWidget);
  });

  testWidgets('setting a remote override calls the service with the chosen value', (tester) async {
    final service = _FakeTelemetryAdminService(installs: [_install(installId: 'install-a')]);
    await pumpScreen(tester, service);
    await tester.tap(find.text('install-a'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('An'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-remote-override')));
    await tester.pumpAndSettle();

    expect(service.overrideWasCalled, isTrue);
    expect(service.lastOverrideInstallId, 'install-a');
    expect(service.lastOverrideValue, isTrue);
    expect(find.text('Gespeichert.'), findsOneWidget);
  });

  testWidgets('a failed save shows a failure snackbar', (tester) async {
    final service = _FakeTelemetryAdminService(
      installs: [_install(installId: 'install-a')],
      setOverrideResult: false,
    );
    await pumpScreen(tester, service);
    await tester.tap(find.text('install-a'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-remote-override')));
    await tester.pumpAndSettle();

    expect(find.text('Fehlgeschlagen.'), findsOneWidget);
  });
}
