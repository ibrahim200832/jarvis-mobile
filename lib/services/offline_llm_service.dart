import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

/// Runs a local, on-device GGUF-successor (`.litertlm`) language model via
/// flutter_gemma/flutter_gemma_litertlm (Google's MediaPipe/LiteRT-LM
/// runtime — the "via Mediapipe" option from the original request), so
/// JARVIS can still answer basic questions, take notes, and do calculations
/// without an internet connection.
///
/// Deliberately built on flutter_gemma rather than a llama.cpp binding
/// (e.g. `fllama`): flutter_gemma_litertlm fetches a prebuilt native
/// library at build time via Dart's Native Assets ("no manual setup on
/// native platforms" — see its README), instead of compiling llama.cpp
/// from source via CMake as part of every build. That shifts the
/// highest-risk part of this feature — an on-device C++ toolchain build —
/// away entirely, which matters a lot in a sandbox that cannot run a real
/// Android/iOS build to verify one.
///
/// Per the user's explicit choice, this defaults to a larger, higher-
/// quality model (2-4GB) rather than a small/fast one — expect a real
/// download and noticeable RAM use on older devices. There is no
/// hardcoded default model URL: unlike this app's Cloudflare Worker (which
/// this project's own author deployed and verified), no specific
/// HuggingFace `.litertlm` file has been verified reachable from this
/// environment (huggingface.co isn't reachable from this sandbox), so the
/// user pastes their own model file URL in Einstellungen — same pattern as
/// the Home Assistant URL/token or the WebDAV server.
class OfflineLlmService {
  bool _engineInitialized = false;

  Future<void> _ensureEngineInitialized() async {
    if (_engineInitialized) return;
    await FlutterGemma.initialize(inferenceEngines: [const LiteRtLmEngine()]);
    _engineInitialized = true;
  }

  Future<bool> isModelInstalled() async {
    await _ensureEngineInitialized();
    return (await FlutterGemma.listInstalledModels()).isNotEmpty;
  }

  /// Downloads [modelUrl] (a direct link to a `.litertlm` file) and sets it
  /// as the active offline model. [onProgress] is called periodically with
  /// 0-100.
  Future<void> installModel(String modelUrl, {void Function(int percent)? onProgress}) async {
    await _ensureEngineInitialized();
    final builder = FlutterGemma.installModel(modelType: ModelType.gemmaIt, fileType: ModelFileType.litertlm)
        .fromNetwork(modelUrl);
    if (onProgress != null) builder.withProgress(onProgress);
    await builder.install();
  }

  /// Removes every installed offline model and clears the active-model
  /// pointer, freeing the (multi-GB) storage it used.
  Future<void> deleteModel() async {
    await _ensureEngineInitialized();
    final installed = await FlutterGemma.listInstalledModels();
    for (final modelId in installed) {
      await FlutterGemma.uninstallModel(modelId);
    }
    await FlutterGemma.clearActiveInferenceIdentity();
  }

  /// Runs a single-turn offline completion. Throws if no model is
  /// installed yet (see [isModelInstalled]) — callers (see Unit 8's cloud
  /// fallback) should check that first and fall back to a clear "offline
  /// model not set up" message instead of letting this throw reach the user.
  Future<String> ask(String prompt, {String systemInstruction = _defaultSystemInstruction}) async {
    await _ensureEngineInitialized();
    final model = await FlutterGemma.getActiveModel(maxTokens: 1024);
    final session = await model.createSession(systemInstruction: systemInstruction);
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      return await session.getResponse();
    } finally {
      await session.close();
    }
  }

  static const _defaultSystemInstruction =
      'Du bist JARVIS, ein hilfreicher deutschsprachiger Assistent. Du läufst gerade offline, direkt auf '
      'dem Gerät, ohne Internetverbindung. Antworte kurz, präzise und auf Deutsch. Du kannst keine '
      'Web-Suchen durchführen oder Apps öffnen — beantworte nur, was du aus dir selbst heraus weißt oder '
      'berechnen kannst.';
}
