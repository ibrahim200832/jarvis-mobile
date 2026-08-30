import 'package:shared_preferences/shared_preferences.dart';

/// Persists user configuration (API keys, assistant name) on-device.
class SettingsService {
  static const _keyNewsApi = 'news_api_key';
  static const _keyWeatherApi = 'weather_api_key';
  static const _keyUserName = 'user_name';
  static const _keyAiBackendUrl = 'ai_backend_url';
  static const _keyYoutubeClientId = 'youtube_client_id';
  static const _keyAiModel = 'ai_model';
  static const _keySpotifyClientId = 'spotify_client_id';
  static const _keyTiktokClientKey = 'tiktok_client_key';
  static const _keyTtsVoiceName = 'tts_voice_name';
  static const _keyTtsVoiceLocale = 'tts_voice_locale';
  static const _keyTtsPitch = 'tts_pitch';
  static const _keyTtsSpeechRate = 'tts_speech_rate';
  static const _keySarcasmLevel = 'sarcasm_level';
  static const _keyMorningBriefingEnabled = 'morning_briefing_enabled';
  static const _keyEveningSummaryEnabled = 'evening_summary_enabled';
  static const _keyHomeAssistantUrl = 'home_assistant_url';
  static const _keyHomeAssistantToken = 'home_assistant_token';
  static const _keyPersona = 'jarvis_persona';
  static const _keyHudEffectsEnabled = 'hud_effects_enabled';
  static const _keyMoodAutoAdjustEnabled = 'mood_auto_adjust_enabled';
  static const _keyEveningJournalEnabled = 'evening_journal_enabled';
  static const _keyNightAlertEnabled = 'night_alert_enabled';
  static const _keySecurityBreachEnabled = 'security_breach_enabled';

  Future<String?> getNewsApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNewsApi);
  }

  Future<void> setNewsApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNewsApi, value);
  }

  Future<String?> getWeatherApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWeatherApi);
  }

  Future<void> setWeatherApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWeatherApi, value);
  }

  Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName) ?? 'Boss';
  }

  Future<void> setUserName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, value);
  }

  /// Default AI proxy Worker so function-calling (Anrufe/WhatsApp/Apps aus
  /// dem Gespräch heraus) works without any manual setup; users can still
  /// override it in Einstellungen, or clear it to use the zero-setup
  /// public fallback instead.
  static const _defaultAiBackendUrl = 'https://jarvis-ai.ibrahimcool2818.workers.dev';

  Future<String?> getAiBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAiBackendUrl) ?? _defaultAiBackendUrl;
  }

  Future<void> setAiBackendUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiBackendUrl, value);
  }

  /// Default OAuth web client ID so YouTube sign-in works without any
  /// manual setup; users can still override it in Einstellungen.
  static const _defaultYoutubeClientId =
      '166736977513-1sma3tlh2jtqn29cragq10ei9ohrgrsj.apps.googleusercontent.com';

  Future<String?> getYoutubeClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyYoutubeClientId) ?? _defaultYoutubeClientId;
  }

  Future<void> setYoutubeClientId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyYoutubeClientId, value);
  }

  /// Which free AI model powers JARVIS when no own backend is configured.
  /// Only used by the zero-setup fallback (see AiChatService).
  Future<String> getAiModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAiModel) ?? 'openai';
  }

  Future<void> setAiModel(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiModel, value);
  }

  /// No zero-setup default is possible here, unlike the AI backend or
  /// YouTube — a Spotify app's redirect URI must be registered by whoever
  /// owns the Client ID in their own Spotify Developer Dashboard, so each
  /// user needs their own (see README).
  Future<String?> getSpotifyClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySpotifyClientId);
  }

  Future<void> setSpotifyClientId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySpotifyClientId, value);
  }

  /// No zero-setup default is possible here either — a TikTok app's
  /// redirect URIs must be registered by whoever owns the Client Key in
  /// their own TikTok Developer app, so each user needs their own (see
  /// README).
  Future<String?> getTiktokClientKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTiktokClientKey);
  }

  Future<void> setTiktokClientKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTiktokClientKey, value);
  }

  Future<String?> getTtsVoiceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTtsVoiceName);
  }

  Future<String?> getTtsVoiceLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTtsVoiceLocale);
  }

  /// Pass null/null to reset back to the system default voice.
  Future<void> setTtsVoice(String? name, String? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null || locale == null) {
      await prefs.remove(_keyTtsVoiceName);
      await prefs.remove(_keyTtsVoiceLocale);
    } else {
      await prefs.setString(_keyTtsVoiceName, name);
      await prefs.setString(_keyTtsVoiceLocale, locale);
    }
  }

  Future<double> getTtsPitch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyTtsPitch) ?? 1.0;
  }

  Future<void> setTtsPitch(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTtsPitch, value);
  }

  Future<double> getTtsSpeechRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyTtsSpeechRate) ?? 0.5;
  }

  Future<void> setTtsSpeechRate(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTtsSpeechRate, value);
  }

  /// 0.0 (hyper-höflich) .. 1.0 (voll sarkastisch, Tony-Stark-Stil). Default
  /// matches JARVIS's original personality (fröhlich, Schuss Humor, nie
  /// sarkastisch).
  Future<double> getSarcasmLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keySarcasmLevel) ?? 0.3;
  }

  Future<void> setSarcasmLevel(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySarcasmLevel, value);
  }

  Future<bool> getMorningBriefingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMorningBriefingEnabled) ?? false;
  }

  Future<void> setMorningBriefingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMorningBriefingEnabled, value);
  }

  Future<bool> getEveningSummaryEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEveningSummaryEnabled) ?? false;
  }

  Future<void> setEveningSummaryEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEveningSummaryEnabled, value);
  }

  Future<String?> getHomeAssistantUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyHomeAssistantUrl);
  }

  Future<void> setHomeAssistantUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHomeAssistantUrl, value);
  }

  Future<String?> getHomeAssistantToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyHomeAssistantToken);
  }

  Future<void> setHomeAssistantToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHomeAssistantToken, value);
  }

  /// Which fixed JARVIS persona is active: 'standard', 'drill_sergeant',
  /// 'gaming_buddy', or 'butler'. Non-standard personas replace the
  /// sarcasm-banded personality clause entirely (see ai_chat_service.dart).
  Future<String> getPersona() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPersona) ?? 'standard';
  }

  Future<void> setPersona(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPersona, value);
  }

  Future<bool> getHudEffectsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHudEffectsEnabled) ?? true;
  }

  Future<void> setHudEffectsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHudEffectsEnabled, value);
  }

  /// Whether a "stimmungscheck" voice-tone reading is allowed to nudge the
  /// effective sarcasm level for subsequent replies (see mood_classifier.dart).
  Future<bool> getMoodAutoAdjustEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMoodAutoAdjustEnabled) ?? true;
  }

  /// Opt-in: whether the late-night coding tease also fires as a real OS
  /// push notification (in addition to the in-chat line, which always
  /// appears regardless of this setting).
  Future<bool> getNightAlertEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNightAlertEnabled) ?? false;
  }

  Future<void> setNightAlertEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNightAlertEnabled, value);
  }

  /// Opt-out: whether JARVIS may occasionally simulate a "security breach"
  /// mini-challenge on app open (see security_breach_service.dart).
  Future<bool> getSecurityBreachEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySecurityBreachEnabled) ?? true;
  }

  Future<void> setSecurityBreachEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySecurityBreachEnabled, value);
  }

  Future<void> setMoodAutoAdjustEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMoodAutoAdjustEnabled, value);
  }

  Future<bool> getEveningJournalEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEveningJournalEnabled) ?? false;
  }

  Future<void> setEveningJournalEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEveningJournalEnabled, value);
  }
}
