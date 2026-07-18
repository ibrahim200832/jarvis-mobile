import 'package:shared_preferences/shared_preferences.dart';

/// Persists user configuration (API keys, assistant name) on-device.
class SettingsService {
  static const _keyNewsApi = 'news_api_key';
  static const _keyWeatherApi = 'weather_api_key';
  static const _keyUserName = 'user_name';
  static const _keyAiBackendUrl = 'ai_backend_url';
  static const _keyYoutubeClientId = 'youtube_client_id';

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

  Future<String?> getAiBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAiBackendUrl);
  }

  Future<void> setAiBackendUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiBackendUrl, value);
  }

  Future<String?> getYoutubeClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyYoutubeClientId);
  }

  Future<void> setYoutubeClientId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyYoutubeClientId, value);
  }
}
