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
}
