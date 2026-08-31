import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/ai_chat_service.dart';
import 'package:jarvis_mobile/services/offline_llm_service.dart';

/// Same fake pattern as system_diagnostic_service_test.dart — overriding
/// the two instance methods AiChatService actually calls avoids touching
/// FlutterGemma's real static API, which can't be mocked in a widget/unit
/// test.
class _FakeOfflineLlmService extends OfflineLlmService {
  bool installed = false;
  String? nextReply;
  Object? throwOnAsk;
  int askCallCount = 0;

  @override
  Future<bool> isModelInstalled() async => installed;

  @override
  Future<String> ask(String prompt, {String systemInstruction = ''}) async {
    askCallCount++;
    if (throwOnAsk != null) throw throwOnAsk!;
    return nextReply ?? 'offline reply';
  }
}

void main() {
  late _FakeOfflineLlmService offlineLlm;
  late AiChatService aiChat;

  setUp(() {
    offlineLlm = _FakeOfflineLlmService();
    aiChat = AiChatService(offlineLlm: offlineLlm);
  });

  group('forceLocalAi (Admin-Konsole "Lokale KI erzwingen")', () {
    test('goes straight to the offline model without ever attempting the cloud path', () async {
      offlineLlm.installed = true;
      offlineLlm.nextReply = 'Antwort vom lokalen Modell.';

      // A garbage, unreachable backend URL would time out / throw if the
      // cloud path were attempted — forceLocalAi must skip it entirely.
      final result = await aiChat.ask(
        'https://this-host-does-not-exist.invalid',
        'wie spät ist es',
        forceLocalAi: true,
      );

      expect(offlineLlm.askCallCount, 1);
      expect(result.reply, contains('Antwort vom lokalen Modell.'));
    });

    test('reports a clear error when no offline model is installed, instead of a silent cloud detour', () async {
      offlineLlm.installed = false;

      final result = await aiChat.ask('https://example.com', 'wie spät ist es', forceLocalAi: true);

      expect(offlineLlm.askCallCount, 0);
      expect(result.reply, contains('kein Offline-Modell installiert'));
    });

    test('reports a clear error when the offline model itself fails', () async {
      offlineLlm.installed = true;
      offlineLlm.throwOnAsk = Exception('model crashed');

      final result = await aiChat.ask('https://example.com', 'wie spät ist es', forceLocalAi: true);

      expect(result.reply, contains('Offline-Anfrage ist fehlgeschlagen'));
    });
  });
}
