import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_storage_service.dart';

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
  static const _keyShakeLocksAppEnabled = 'shake_locks_app_enabled';
  static const _keyDashboardNotificationEnabled = 'dashboard_notification_enabled';
  static const _keyNotificationHubEnabled = 'notification_hub_enabled';
  static const _keyNotificationDigestAiEnabled = 'notification_digest_ai_enabled';
  static const _keyAdminPinSalt = 'admin_pin_salt';
  static const _keyAdminPinHash = 'admin_pin_hash';
  static const _keyAdminBiometricEnabled = 'admin_biometric_enabled';

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

  /// Sets/replaces the Admin-Konsole PIN — a separate credential from the
  /// emergency-lock PIN (see [setAppLockPin]), since the two protect
  /// different things (the whole app in an emergency vs. just the admin
  /// console). Never stores the PIN itself, only a salted SHA-256 hash,
  /// same pattern as [setAppLockPin].
  Future<void> setAdminPin(String pin) async {
    final saltBytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final salt = base64Url.encode(saltBytes);
    final hash = sha256.convert(utf8.encode('$salt:$pin')).toString();
    await _secureSet(_keyAdminPinSalt, salt);
    await _secureSet(_keyAdminPinHash, hash);
  }

  Future<bool> hasAdminPin() async {
    return (await _secureGet(_keyAdminPinHash)) != null;
  }

  /// Recomputes the salted hash for [pin] and compares it against the
  /// stored one. Returns false (never throws) if no PIN is set.
  Future<bool> verifyAdminPin(String pin) async {
    final salt = await _secureGet(_keyAdminPinSalt);
    final storedHash = await _secureGet(_keyAdminPinHash);
    if (salt == null || storedHash == null) return false;
    final hash = sha256.convert(utf8.encode('$salt:$pin')).toString();
    return hash == storedHash;
  }

  /// Unlike [clearAppLockPin], removing this PIN carries no lockout risk —
  /// it's only reachable from the normal (ungated) settings screen, never
  /// from inside the admin console itself.
  Future<void> clearAdminPin() async {
    await _secure.delete(_keyAdminPinSalt);
    await _secure.delete(_keyAdminPinHash);
  }

  /// Whether biometric unlock (fingerprint/face) is offered as an
  /// additional way into the admin console, alongside the PIN — the PIN
  /// always remains the required fallback. Default off.
  Future<bool> getAdminBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAdminBiometricEnabled) ?? false;
  }

  Future<void> setAdminBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAdminBiometricEnabled, value);
  }
}
