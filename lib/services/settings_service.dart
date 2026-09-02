import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/jarvis_theme.dart';
import 'secure_storage_service.dart';

/// One individual Admin-Konsole account — either the single owner (full
/// rights, including managing other accounts) or a helper (same console
/// access, no account management). See SettingsService's
/// getAdminAccounts/addAdminAccount/etc. and AdminAuthService.
class AdminAccount {
  AdminAccount({required this.username, required this.passwordSalt, required this.passwordHash, required this.isOwner});

  final String username;
  final String passwordSalt;
  final String passwordHash;
  final bool isOwner;

  Map<String, dynamic> toJson() => {
    'username': username,
    'passwordSalt': passwordSalt,
    'passwordHash': passwordHash,
    'isOwner': isOwner,
  };

  static AdminAccount fromJson(Map<String, dynamic> json) => AdminAccount(
    username: json['username'] as String,
    passwordSalt: json['passwordSalt'] as String,
    passwordHash: json['passwordHash'] as String,
    isOwner: json['isOwner'] as bool,
  );
}

/// Persists user configuration (API keys, assistant name) on-device.
///
/// Genuinely sensitive values (API keys, tokens, the HMAC request-signing
/// secret) are backed by [SecureStorageService] — AES-256/Keystore-encrypted
/// storage — instead of SharedPreferences' plaintext file; see
/// [_secureGet]/[_secureSet]. Non-secret configuration (names, toggles,
/// public OAuth client IDs, server URLs) stays in plain SharedPreferences,
/// unchanged.
class SettingsService {
  SettingsService({SecureStorageService? secureStorage}) : _secure = secureStorage ?? SecureStorageService();

  final SecureStorageService _secure;

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
  static const _keyReactiveOrbEnabled = 'reactive_orb_enabled';
  static const _keyFaceDownFocusEnabled = 'face_down_focus_enabled';
  static const _keyShakeStartsVoiceEnabled = 'shake_starts_voice_enabled';
  static const _keyMoodAutoAdjustEnabled = 'mood_auto_adjust_enabled';
  static const _keyEveningJournalEnabled = 'evening_journal_enabled';
  static const _keyNightAlertEnabled = 'night_alert_enabled';
  static const _keySecurityBreachEnabled = 'security_breach_enabled';
  static const _keyAiHmacSecret = 'ai_hmac_secret';
  static const _keyCertPins = 'ai_cert_pins';
  static const _keyGoogleCloudProjectNumber = 'google_cloud_project_number';
  static const _keyIntegrityCheckEnabled = 'integrity_check_enabled';
  static const _keyRssFeedCheckEnabled = 'rss_feed_check_enabled';
  static const _keyWeeklyBackupExportEnabled = 'weekly_backup_export_enabled';
  static const _keyWebDavUrl = 'webdav_url';
  static const _keyWebDavUsername = 'webdav_username';
  static const _keyWebDavPassword = 'webdav_password';
  static const _keyOfflineLlmModelUrl = 'offline_llm_model_url';
  static const _keyAppLockPinSalt = 'app_lock_pin_salt';
  static const _keyAppLockPinHash = 'app_lock_pin_hash';
  static const _keyAppLockUsername = 'app_lock_username';
  static const _keyAppLockPasswordSalt = 'app_lock_password_salt';
  static const _keyAppLockPasswordHash = 'app_lock_password_hash';
  static const _keyAppLockFailedAttempts = 'app_lock_failed_attempts';
  static const _keyAppLockLockoutUntil = 'app_lock_lockout_until';
  static const _keyShakeLocksAppEnabled = 'shake_locks_app_enabled';
  static const _keyDashboardNotificationEnabled = 'dashboard_notification_enabled';
  static const _keyNotificationHubEnabled = 'notification_hub_enabled';
  static const _keyNotificationDigestAiEnabled = 'notification_digest_ai_enabled';
  static const _keyAdminPinSalt = 'admin_pin_salt';
  static const _keyAdminPinHash = 'admin_pin_hash';
  static const _keyAdminBiometricEnabled = 'admin_biometric_enabled';
  static const _keyAdminUsername = 'admin_username';
  static const _keyAdminPasswordSalt = 'admin_password_salt';
  static const _keyAdminPasswordHash = 'admin_password_hash';
  static const _keyAdminAccounts = 'admin_accounts';
  static const _keyAdminFailedAttempts = 'admin_failed_attempts';
  static const _keyAdminLockoutUntil = 'admin_lockout_until';
  static const _keySystemPromptOverride = 'admin_system_prompt_override';
  static const _keyAiTemperature = 'ai_temperature';
  static const _keyMaxHistoryTurns = 'ai_max_history_turns';
  static const _keyAiModelTier = 'ai_model_tier';
  static const _keyAiRequestCountDate = 'ai_request_count_date';
  static const _keyAiRequestCountValue = 'ai_request_count_value';
  static const _keyThemeVariant = 'theme_variant';
  static const _keyForceLocalAiEnabled = 'force_local_ai_enabled';
  static const _keyDiscordWebhookEnabled = 'discord_webhook_enabled';
  static const _keyInstallId = 'install_id';
  static const _keyCrashReportingEnabled = 'crash_reporting_enabled';
  static const _keyTelemetryBackendUrl = 'telemetry_backend_url';
  static const _keyAdminApiKey = 'admin_api_key';

  /// Reads a secret from secure (AES-256) storage. If it hasn't been
  /// migrated yet, transparently pulls a legacy plaintext SharedPreferences
  /// value (saved before secure storage was introduced) once, moves it into
  /// secure storage, and removes the plaintext copy — so nobody's
  /// already-saved keys get silently lost by this change.
  Future<String?> _secureGet(String key) async {
    final secure = await _secure.read(key);
    if (secure != null) return secure;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy == null) return null;
    await _secure.write(key, legacy);
    await prefs.remove(key);
    return legacy;
  }

  Future<void> _secureSet(String key, String value) async {
    await _secure.write(key, value);
    final prefs = await SharedPreferences.getInstance();
    // In case an old plaintext copy is still lingering from before secure
    // storage existed.
    if (prefs.containsKey(key)) await prefs.remove(key);
  }

  Future<String?> getNewsApiKey() => _secureGet(_keyNewsApi);

  Future<void> setNewsApiKey(String value) => _secureSet(_keyNewsApi, value);

  Future<String?> getWeatherApiKey() => _secureGet(_keyWeatherApi);

  Future<void> setWeatherApiKey(String value) => _secureSet(_keyWeatherApi, value);

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

  Future<String?> getHomeAssistantToken() => _secureGet(_keyHomeAssistantToken);

  Future<void> setHomeAssistantToken(String value) => _secureSet(_keyHomeAssistantToken, value);

  /// The user's own WebDAV server for end-to-end-encrypted cloud sync of
  /// the local backup (see BackupExportService/WebDavSyncService). URL and
  /// username aren't secret; the password is (SecureStorageService-backed,
  /// same convention as the Home Assistant token above).
  Future<String?> getWebDavUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWebDavUrl);
  }

  Future<void> setWebDavUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWebDavUrl, value);
  }

  Future<String?> getWebDavUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyWebDavUsername);
  }

  Future<void> setWebDavUsername(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWebDavUsername, value);
  }

  Future<String?> getWebDavPassword() => _secureGet(_keyWebDavPassword);

  Future<void> setWebDavPassword(String value) => _secureSet(_keyWebDavPassword, value);

  /// Direct download URL for the offline `.litertlm` model file (see
  /// OfflineLlmService). Not secret — a public HuggingFace file link — and
  /// deliberately has no hardcoded default (see OfflineLlmService's doc
  /// comment for why), unlike the AI backend Worker URL above.
  Future<String?> getOfflineLlmModelUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOfflineLlmModelUrl);
  }

  Future<void> setOfflineLlmModelUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOfflineLlmModelUrl, value);
  }

  /// Shared secret for signing requests to the user's own AI backend Worker
  /// with an HMAC (see request_signing_service.dart) — proves a request
  /// really came from this app install and wasn't forged/replayed. Optional:
  /// null means requests to the backend go out unsigned (the Worker itself
  /// decides whether that's still accepted, see worker/ai-proxy.js).
  Future<String?> getAiHmacSecret() => _secureGet(_keyAiHmacSecret);

  Future<void> setAiHmacSecret(String value) => _secureSet(_keyAiHmacSecret, value);

  Future<void> clearAiHmacSecret() async {
    await _secure.delete(_keyAiHmacSecret);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyAiHmacSecret)) await prefs.remove(_keyAiHmacSecret);
  }

  /// SPKI-SHA256 certificate pins for the AI backend Worker (see
  /// tls_pinning_service.dart) — a list, not a single value, so a "backup"
  /// pin can be added ahead of a planned certificate rotation. Not secret
  /// (public-key hashes are, by design, safe to expose), so plain
  /// SharedPreferences is fine here, unlike the HMAC secret above. An empty
  /// list means pinning is inactive — normal TLS validation applies.
  Future<List<String>> getCertPins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyCertPins) ?? const [];
  }

  Future<void> setCertPins(List<String> pins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCertPins, pins);
  }

  /// The Google Cloud project number linked to this app's Play Console
  /// listing (see AppIntegrityService/README) — a public identifier, not a
  /// secret, so plain SharedPreferences is fine.
  Future<String?> getGoogleCloudProjectNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGoogleCloudProjectNumber);
  }

  Future<void> setGoogleCloudProjectNumber(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGoogleCloudProjectNumber, value);
  }

  /// Opt-in, default off: whether the app should run a Play Integrity
  /// attestation check on start (see AppIntegrityService). Off by default
  /// since it needs a Google Cloud project + a Worker endpoint the operator
  /// must set up themselves (see README) — enabling it before that's done
  /// would just fail silently on every app start for no benefit.
  Future<bool> getIntegrityCheckEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIntegrityCheckEnabled) ?? false;
  }

  Future<void> setIntegrityCheckEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIntegrityCheckEnabled, value);
  }

  /// Opt-in, default off: whether BackgroundTaskService should periodically
  /// check subscribed RSS feeds in the background (see RssFeedService) and
  /// proactively notify about new headlines. Off by default since periodic
  /// background network access has a real (if small) battery/data cost that
  /// shouldn't be paid by users who never subscribed to a feed anyway.
  Future<bool> getRssFeedCheckEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRssFeedCheckEnabled) ?? false;
  }

  Future<void> setRssFeedCheckEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRssFeedCheckEnabled, value);
  }

  /// Opt-in, default off: whether BackgroundTaskService should run a
  /// weekly encrypted local backup export (see BackupExportService). Off
  /// by default, same reasoning as the RSS check toggle above — periodic
  /// background work shouldn't run for users who never asked for it.
  Future<bool> getWeeklyBackupExportEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWeeklyBackupExportEnabled) ?? false;
  }

  Future<void> setWeeklyBackupExportEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWeeklyBackupExportEnabled, value);
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

  /// Whether VoiceOrbOverlay's reactor ring reacts to real microphone
  /// volume / a synthetic speaking pulse, or just its original pure-time
  /// animation.
  Future<bool> getReactiveOrbEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyReactiveOrbEnabled) ?? true;
  }

  Future<void> setReactiveOrbEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReactiveOrbEnabled, value);
  }

  /// Whether flipping the phone face-down triggers the silent focus mode
  /// (mutes TTS/STT). Default off — a background-behavior-changing motion
  /// gesture, same opt-in convention as RSS checks/weekly backups/etc.
  Future<bool> getFaceDownFocusEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFaceDownFocusEnabled) ?? false;
  }

  Future<void> setFaceDownFocusEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFaceDownFocusEnabled, value);
  }

  /// Whether shaking the phone starts voice input (see MotionActionsService).
  Future<bool> getShakeStartsVoiceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShakeStartsVoiceEnabled) ?? false;
  }

  Future<void> setShakeStartsVoiceEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShakeStartsVoiceEnabled, value);
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

  /// Whether shaking the phone triggers the emergency PIN lock (see
  /// AppLockService) — independent of [getShakeStartsVoiceEnabled], both
  /// may be on at once.
  Future<bool> getShakeLocksAppEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShakeLocksAppEnabled) ?? false;
  }

  Future<void> setShakeLocksAppEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShakeLocksAppEnabled, value);
  }

  /// Sets/replaces the emergency-lock PIN. Never stores the PIN itself —
  /// only a salted SHA-256 hash (both halves in AES-256/Keystore-backed
  /// secure storage, same as every other secret in this class), so even a
  /// full on-device data extraction can't recover the PIN, only verify a
  /// guess against it.
  Future<void> setAppLockPin(String pin) async {
    final saltBytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final salt = base64Url.encode(saltBytes);
    final hash = sha256.convert(utf8.encode('$salt:$pin')).toString();
    await _secureSet(_keyAppLockPinSalt, salt);
    await _secureSet(_keyAppLockPinHash, hash);
  }

  Future<bool> hasAppLockPin() async {
    return (await _secureGet(_keyAppLockPinHash)) != null;
  }

  /// Recomputes the salted hash for [pin] and compares it against the
  /// stored one. Returns false (never throws) if no PIN is set.
  Future<bool> verifyAppLockPin(String pin) async {
    final salt = await _secureGet(_keyAppLockPinSalt);
    final storedHash = await _secureGet(_keyAppLockPinHash);
    if (salt == null || storedHash == null) return false;
    final hash = sha256.convert(utf8.encode('$salt:$pin')).toString();
    return hash == storedHash;
  }

  Future<void> clearAppLockPin() async {
    await _secure.delete(_keyAppLockPinSalt);
    await _secure.delete(_keyAppLockPinHash);
  }

  /// Sets/replaces the emergency-lock's username+password login — a second,
  /// equally valid way to unlock the whole app, alongside the PIN (see
  /// setAppLockPin), not a replacement for it. Completely separate
  /// credentials from the Admin-Konsole's (see setAdminCredentials) — the
  /// two protect different things and are never shared. Same salted-SHA256
  /// pattern as the PIN; the username itself is a plain (non-secret)
  /// identifier. Never stores the password itself, only a salted hash.
  Future<void> setAppLockCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppLockUsername, username);
    final saltBytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final salt = base64Url.encode(saltBytes);
    final hash = sha256.convert(utf8.encode('$salt:$password')).toString();
    await _secureSet(_keyAppLockPasswordSalt, salt);
    await _secureSet(_keyAppLockPasswordHash, hash);
  }

  Future<bool> hasAppLockCredentials() async {
    return (await _secureGet(_keyAppLockPasswordHash)) != null;
  }

  Future<String?> getAppLockUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAppLockUsername);
  }

  /// Case-sensitive exact match on both username and password. Returns
  /// false (never throws) if no credentials are set, or if the username
  /// doesn't match the stored one.
  Future<bool> verifyAppLockCredentials(String username, String password) async {
    final storedUsername = await getAppLockUsername();
    final salt = await _secureGet(_keyAppLockPasswordSalt);
    final storedHash = await _secureGet(_keyAppLockPasswordHash);
    if (storedUsername == null || salt == null || storedHash == null) return false;
    if (username != storedUsername) return false;
    final hash = sha256.convert(utf8.encode('$salt:$password')).toString();
    return hash == storedHash;
  }

  /// Unlike clearAppLockPin's PIN, removing these credentials carries no
  /// lockout risk — only reachable from the normal (ungated) settings
  /// screen, never while the app is actually locked.
  Future<void> clearAppLockCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAppLockUsername);
    await _secure.delete(_keyAppLockPasswordSalt);
    await _secure.delete(_keyAppLockPasswordHash);
  }

  /// Failed-attempt counter shared by both the emergency-lock PIN and the
  /// username/password login (see AppLockService) — persisted (not just
  /// in-memory) so a simple app restart can't be used to dodge a lockout.
  Future<int> getAppLockFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAppLockFailedAttempts) ?? 0;
  }

  Future<void> setAppLockFailedAttempts(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAppLockFailedAttempts, value);
  }

  Future<DateTime?> getAppLockLockoutUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyAppLockLockoutUntil);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Pass null to clear the lockout.
  Future<void> setAppLockLockoutUntil(DateTime? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_keyAppLockLockoutUntil);
    } else {
      await prefs.setString(_keyAppLockLockoutUntil, value.toIso8601String());
    }
  }

  /// Whether the persistent "Lockscreen-Dashboard" status notification
  /// (see DashboardNotificationService) is shown. Default off — a
  /// permanent, non-dismissible notification is more intrusive than any
  /// other feature in this app, opt-in like every other background toggle.
  Future<bool> getDashboardNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDashboardNotificationEnabled) ?? false;
  }

  Future<void> setDashboardNotificationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDashboardNotificationEnabled, value);
  }

  /// Whether the Notification-Hub captures other apps' notification
  /// previews at all (see NotificationHubService). Default off — a special
  /// OS permission with real privacy implications, opt-in like every other
  /// sensitive feature.
  Future<bool> getNotificationHubEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationHubEnabled) ?? false;
  }

  Future<void> setNotificationHubEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationHubEnabled, value);
  }

  /// Whether captured notification previews may be sent to the user's own
  /// AI backend for a nicer summary (see AiChatService.askNotificationDigest).
  /// Default off — a second, separate opt-in on top of
  /// [getNotificationHubEnabled] itself, since this sends real preview text
  /// off-device (to the user's OWN server only, never the public fallback).
  Future<bool> getNotificationDigestAiEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationDigestAiEnabled) ?? false;
  }

  Future<void> setNotificationDigestAiEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationDigestAiEnabled, value);
  }

  /// All Admin-Konsole accounts (the one owner plus any helpers), stored as
  /// a single JSON-encoded list behind one secure-storage key — same "one
  /// key, one JSON blob" shape as TodoService's SharedPreferences list, just
  /// through [_secureGet]/[_secureSet] since it holds password hashes.
  ///
  /// One-time migration: if no accounts have ever been saved but an old
  /// single shared admin username+password (from before this multi-account
  /// system existed) is still present, it's promoted directly into a new
  /// owner account — reusing the existing salt+hash pair so the user never
  /// has to re-enter their password — and every legacy key (PIN, biometric
  /// toggle, single-credentials) is deleted afterwards so nothing orphaned
  /// lingers in storage. A PIN-only setup (no username/password ever set)
  /// has no compatible data to migrate and simply starts with an empty
  /// account list.
  Future<List<AdminAccount>> getAdminAccounts() async {
    final raw = await _secureGet(_keyAdminAccounts);
    if (raw != null && raw.isNotEmpty) {
      return (jsonDecode(raw) as List).map((e) => AdminAccount.fromJson(e as Map<String, dynamic>)).toList();
    }

    final legacySalt = await _secureGet(_keyAdminPasswordSalt);
    final legacyHash = await _secureGet(_keyAdminPasswordHash);
    final prefs = await SharedPreferences.getInstance();
    final legacyUsername = prefs.getString(_keyAdminUsername);
    if (legacySalt == null || legacyHash == null || legacyUsername == null) {
      await _clearLegacyAdminAuth();
      return [];
    }

    final migrated = [
      AdminAccount(username: legacyUsername, passwordSalt: legacySalt, passwordHash: legacyHash, isOwner: true),
    ];
    await _saveAdminAccounts(migrated);
    await _clearLegacyAdminAuth();
    return migrated;
  }

  Future<void> _clearLegacyAdminAuth() async {
    await _secure.delete(_keyAdminPinSalt);
    await _secure.delete(_keyAdminPinHash);
    await _secure.delete(_keyAdminPasswordSalt);
    await _secure.delete(_keyAdminPasswordHash);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAdminUsername);
    await prefs.remove(_keyAdminBiometricEnabled);
  }

  Future<void> _saveAdminAccounts(List<AdminAccount> accounts) async {
    await _secureSet(_keyAdminAccounts, jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }

  /// Adds a new account. Username uniqueness is checked case-insensitively
  /// (so "Ibrahim" and "ibrahim" can't coexist), even though matching a
  /// login attempt (see [findMatchingAdminAccount]) stays case-sensitive,
  /// like every other username/password pair in this file — returns false
  /// without adding anything if the username is already taken.
  Future<bool> addAdminAccount({required String username, required String password, required bool isOwner}) async {
    final accounts = await getAdminAccounts();
    if (accounts.any((a) => a.username.toLowerCase() == username.toLowerCase())) return false;
    final saltBytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final salt = base64Url.encode(saltBytes);
    final hash = sha256.convert(utf8.encode('$salt:$password')).toString();
    accounts.add(AdminAccount(username: username, passwordSalt: salt, passwordHash: hash, isOwner: isOwner));
    await _saveAdminAccounts(accounts);
    return true;
  }

  /// Returns false (does nothing) if no account with that username exists.
  Future<bool> removeAdminAccount(String username) async {
    final accounts = await getAdminAccounts();
    final removed = accounts.length;
    accounts.removeWhere((a) => a.username == username);
    if (accounts.length == removed) return false;
    await _saveAdminAccounts(accounts);
    return true;
  }

  /// Case-sensitive exact match on username, hash-verified password.
  /// Returns null (never throws) if no account matches.
  Future<AdminAccount?> findMatchingAdminAccount(String username, String password) async {
    final accounts = await getAdminAccounts();
    for (final account in accounts) {
      if (account.username != username) continue;
      final hash = sha256.convert(utf8.encode('${account.passwordSalt}:$password')).toString();
      if (hash == account.passwordHash) return account;
      return null;
    }
    return null;
  }

  /// Returns false (does nothing) if no account with that username exists.
  Future<bool> updateAdminAccountPassword(String username, String newPassword) async {
    final accounts = await getAdminAccounts();
    final index = accounts.indexWhere((a) => a.username == username);
    if (index == -1) return false;
    final saltBytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final salt = base64Url.encode(saltBytes);
    final hash = sha256.convert(utf8.encode('$salt:$newPassword')).toString();
    final existing = accounts[index];
    accounts[index] = AdminAccount(username: existing.username, passwordSalt: salt, passwordHash: hash, isOwner: existing.isOwner);
    await _saveAdminAccounts(accounts);
    return true;
  }

  /// Failed-attempt counter shared across every Admin-Konsole login attempt
  /// (see AdminAuthService), regardless of which account was guessed —
  /// persisted (not just in-memory) so a simple app restart can't be used
  /// to dodge a lockout.
  Future<int> getAdminFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAdminFailedAttempts) ?? 0;
  }

  Future<void> setAdminFailedAttempts(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAdminFailedAttempts, value);
  }

  Future<DateTime?> getAdminLockoutUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyAdminLockoutUntil);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Pass null to clear the lockout.
  Future<void> setAdminLockoutUntil(DateTime? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_keyAdminLockoutUntil);
    } else {
      await prefs.setString(_keyAdminLockoutUntil, value.toIso8601String());
    }
  }

  /// A raw, user-authored system prompt that — when set — fully replaces
  /// JARVIS's built-in sarcasm/persona-based prompt for the default chat
  /// path (see AiChatService.ask/jarvisSystemPrompt, CommandRouter). Never
  /// applied to the story/RPG/journal/notification-digest modes, which
  /// keep their own fixed narrator personas. No secret, plain
  /// SharedPreferences like the other free-text settings in this class.
  Future<String?> getSystemPromptOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySystemPromptOverride);
  }

  Future<void> setSystemPromptOverride(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySystemPromptOverride, value);
  }

  Future<void> clearSystemPromptOverride() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySystemPromptOverride);
  }

  /// Sampling temperature sent to the own KI-Server (see worker/ai-proxy.js
  /// runModel) — 0.0 is precise/deterministic, 1.0 is more creative/
  /// varied. Default 0.3 matches the value the worker used to hard-code
  /// before this became configurable. Has no effect on the free
  /// pollinations.ai fallback, which exposes no such parameter.
  Future<double> getAiTemperature() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyAiTemperature) ?? 0.3;
  }

  Future<void> setAiTemperature(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyAiTemperature, value);
  }

  /// How many past conversation turns (user+assistant pairs) CommandRouter
  /// keeps and sends as context on every ask() call. Default 8 matches the
  /// value that used to be a hard-coded constant. The worker's own
  /// MAX_HISTORY_MESSAGES=16 stays a fixed, independent server-side ceiling
  /// regardless of this value — deliberately not configurable from here,
  /// see worker/ai-proxy.js.
  Future<int> getMaxHistoryTurns() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMaxHistoryTurns) ?? 8;
  }

  Future<void> setMaxHistoryTurns(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMaxHistoryTurns, value);
  }

  /// Which Cloudflare Workers AI model the own KI-Server should use —
  /// 'smart' (default, the existing larger model) or 'fast' (a smaller,
  /// quicker one). Only meaningful with an own KI-Server-Adresse
  /// configured; validated server-side against a fixed allowlist (see
  /// worker/ai-proxy.js ALLOWED_MODELS), never trusted raw.
  Future<String> getAiModelTier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAiModelTier) ?? 'smart';
  }

  Future<void> setAiModelTier(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiModelTier, value);
  }

  /// Admin-Konsole "Erscheinungsbild" (Gold/Dark Cyan) — an unrecognized or
  /// missing stored value falls back to gold, the app's original look.
  Future<ThemeVariant> getThemeVariant() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeVariant) == 'cyan' ? ThemeVariant.cyan : ThemeVariant.gold;
  }

  Future<void> setThemeVariant(ThemeVariant variant) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeVariant, variant == ThemeVariant.cyan ? 'cyan' : 'gold');
  }

  /// Admin-Konsole "Lokale KI erzwingen" — see AiChatService.ask()'s
  /// forceLocalAi parameter.
  Future<bool> getForceLocalAiEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyForceLocalAiEnabled) ?? false;
  }

  Future<void> setForceLocalAiEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyForceLocalAiEnabled, value);
  }

  /// Admin-Konsole "Discord-Bot-Versand" — a placeholder toggle only,
  /// nothing in the app actually sends to Discord yet (discord-bot/ is a
  /// fully separate Node.js project with no connection to this app). No
  /// webhook URL is persisted here, since there's nothing to send it to.
  Future<bool> getDiscordWebhookEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDiscordWebhookEnabled) ?? false;
  }

  Future<void> setDiscordWebhookEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDiscordWebhookEnabled, value);
  }

  /// Local, app-side counter of AI requests made today — NOT a real
  /// provider quota (Cloudflare doesn't expose Workers AI usage to the
  /// Worker itself, see ApiHealthScreen). Resets automatically whenever
  /// the stored date no longer matches today.
  Future<void> recordAiRequestToday({DateTime? now}) async {
    final today = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_keyAiRequestCountDate);
    final currentCount = (storedDate == today) ? (prefs.getInt(_keyAiRequestCountValue) ?? 0) : 0;
    await prefs.setString(_keyAiRequestCountDate, today);
    await prefs.setInt(_keyAiRequestCountValue, currentCount + 1);
  }

  Future<int> getAiRequestCountToday({DateTime? now}) async {
    final today = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyAiRequestCountDate) != today) return 0;
    return prefs.getInt(_keyAiRequestCountValue) ?? 0;
  }

  /// A random, anonymous opaque string identifying this one installation —
  /// never tied to any account or personal data, generated once and reused
  /// for as long as the app stays installed (see CrashReportService). Not a
  /// secret, so plain SharedPreferences is fine, same as any other
  /// non-sensitive identifier in this class.
  Future<String> getInstallId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyInstallId);
    if (existing != null) return existing;
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final id = base64Url.encode(bytes).replaceAll('=', '');
    await prefs.setString(_keyInstallId, id);
    return id;
  }

  /// Whether anonymous crash/error reports (technical data only — never
  /// chat message content, see CrashReportService) are sent to the
  /// developer. Default ON, unlike this app's other background/network
  /// toggles: the whole point of this feature is that the developer sees
  /// errors from every installation, so an opt-in default would defeat it.
  /// Transparency is instead handled by the explanatory text next to the
  /// switch in Einstellungen — anyone who reads it can still turn this off.
  Future<bool> getCrashReportingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCrashReportingEnabled) ?? true;
  }

  Future<void> setCrashReportingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCrashReportingEnabled, value);
  }

  /// Where CrashReportService sends error reports/fetches remote overrides
  /// — deliberately a separate setting from [getAiBackendUrl], even though
  /// both default to the same Worker: a user who points their AI chat at a
  /// different server (their own Worker) shouldn't also silently redirect
  /// their error reports away from the developer, and vice versa.
  Future<String?> getTelemetryBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTelemetryBackendUrl) ?? _defaultAiBackendUrl;
  }

  Future<void> setTelemetryBackendUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTelemetryBackendUrl, value);
  }

  /// Shared secret required by the Worker's /admin/installs* endpoints
  /// (Runde 21) — separate from [getAiHmacSecret], which ordinary
  /// installations never configure and so can't gate admin-only,
  /// all-installations data. Must match ADMIN_API_KEY set on the Worker via
  /// `wrangler secret put` (see README).
  Future<String?> getAdminApiKey() => _secureGet(_keyAdminApiKey);

  Future<void> setAdminApiKey(String value) => _secureSet(_keyAdminApiKey, value);

  Future<void> clearAdminApiKey() async {
    await _secure.delete(_keyAdminApiKey);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_keyAdminApiKey)) await prefs.remove(_keyAdminApiKey);
  }
}
