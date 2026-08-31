import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_storage_service.dart';

/// Keys that must never end up in an exported backup, even if a legacy
/// plaintext copy is briefly sitting in SharedPreferences before its owning
/// service's next read transparently migrates it into SecureStorageService
/// (see e.g. SettingsService._secureGet). Real secrets belong in the OS
/// keystore, not in a portable file the user might later copy or share —
/// this is a defense-in-depth exclusion, not the primary safeguard.
const backupExcludedKeys = {
  'news_api_key',
  'weather_api_key',
  'home_assistant_token',
  'ai_hmac_secret',
  'spotify_access_token',
  'spotify_refresh_token',
  'tiktok_access_token',
  'tiktok_refresh_token',
  'webdav_password',
};

/// Zips [data] as a single JSON entry, encrypts the zip bytes with
/// AES-256-CBC under [key], and prepends the random IV so the file is
/// self-contained (no separate metadata needed to decrypt it again). Pure
/// byte-level logic — no filesystem or SharedPreferences access — so it's
/// directly unit-testable.
Uint8List buildEncryptedBackup(Map<String, dynamic> data, enc.Key key) {
  final archive = Archive();
  final jsonBytes = utf8.encode(jsonEncode(data));
  archive.addFile(ArchiveFile('jarvis_backup.json', jsonBytes.length, jsonBytes));
  final zipBytes = ZipEncoder().encodeBytes(archive);

  final iv = enc.IV.fromSecureRandom(16);
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  final encrypted = encrypter.encryptBytes(zipBytes, iv: iv);

  return Uint8List.fromList([...iv.bytes, ...encrypted.bytes]);
}

/// Reverses [buildEncryptedBackup]. Throws if [key] is wrong or [fileBytes]
/// is malformed/corrupted (padding/CRC checks inside AES/zip decoding).
Map<String, dynamic> decryptBackup(Uint8List fileBytes, enc.Key key) {
  const ivLength = 16;
  final iv = enc.IV(fileBytes.sublist(0, ivLength));
  final cipherBytes = fileBytes.sublist(ivLength);
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  final zipBytes = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);

  final archive = ZipDecoder().decodeBytes(zipBytes);
  final entry = archive.files.firstWhere((f) => f.name == 'jarvis_backup.json');
  return jsonDecode(utf8.decode(entry.content)) as Map<String, dynamic>;
}

/// Builds, stores, and restores an encrypted local snapshot of the app's
/// own data (Notes, Journal, Gamification/XP state, Challenge progress,
/// RPG save state, RSS subscriptions, non-secret settings) — either on
/// demand from the chat or weekly via BackgroundTaskService
/// (BackgroundTaskNames.weeklyBackupExport). Stays purely local: no email
/// or bot delivery, per explicit user decision — the encrypted file is
/// written to the app's own storage and nowhere else.
///
/// The AES-256 key is generated once per install and kept in
/// SecureStorageService (OS keystore) rather than a user-typed passphrase,
/// specifically so the weekly *automatic* export can run with zero user
/// interaction — there is nobody to prompt for a password at 3am from a
/// headless background isolate. The tradeoff: the exported file can only
/// be decrypted by this same app install, not manually with a generic
/// AES tool — an explicit, documented scope choice for this local-only,
/// automatic-friendly feature.
class BackupExportService {
  // See LogService's identical constructor for why the analyzer's
  // initializing-formal suggestion doesn't apply here (it would make the
  // `directoryOverride` named parameter private).
  BackupExportService({Directory? directoryOverride, SecureStorageService? secureStorage})
    : _directoryOverride = directoryOverride, // ignore: prefer_initializing_formals
      _secure = secureStorage ?? SecureStorageService();

  final Directory? _directoryOverride;
  final SecureStorageService _secure;

  static const fileName = 'jarvis_backup.zip.enc';
  static const _keyStorageKey = 'backup_encryption_key';

  Future<Directory> _dir() async => _directoryOverride ?? await getApplicationSupportDirectory();

  Future<File> _file() async {
    final dir = await _dir();
    return File('${dir.path}/$fileName');
  }

  Future<enc.Key> _getOrCreateKey() async {
    final existing = await _secure.read(_keyStorageKey);
    if (existing != null) return enc.Key.fromBase64(existing);
    final generated = enc.Key.fromSecureRandom(32);
    await _secure.write(_keyStorageKey, generated.base64);
    return generated;
  }

  /// Snapshots everything in SharedPreferences except [backupExcludedKeys].
  Future<Map<String, dynamic>> collectBackupData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (backupExcludedKeys.contains(key)) continue;
      data[key] = prefs.get(key);
    }
    return data;
  }

  /// Restores every key in [data] back into SharedPreferences, dispatching
  /// on each value's runtime type (SharedPreferences only supports bool,
  /// int, double, String, and List<String>) — the reverse of
  /// [collectBackupData].
  Future<void> restoreBackupData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is List) {
        await prefs.setStringList(entry.key, value.whereType<String>().toList());
      }
    }
  }

  /// Builds an encrypted snapshot of the current app data without touching
  /// the filesystem — shared by [exportNow] (writes it to disk) and
  /// WebDavSyncService (uploads it), so both paths use the exact same
  /// encryption and the exact same persisted key.
  Future<Uint8List> buildEncryptedSnapshot() async {
    final data = await collectBackupData();
    final key = await _getOrCreateKey();
    return buildEncryptedBackup(data, key);
  }

  /// Decrypts [bytes] (as produced by [buildEncryptedSnapshot]) and
  /// restores it into SharedPreferences. Shared by [restoreFromDisk] and
  /// WebDavSyncService's download path.
  Future<void> restoreFromBytes(Uint8List bytes) async {
    final key = await _getOrCreateKey();
    final data = decryptBackup(bytes, key);
    await restoreBackupData(data);
  }

  /// Builds a fresh encrypted backup and writes it to disk, overwriting any
  /// previous one. Returns the file so callers can report its size.
  Future<File> exportNow() async {
    final bytes = await buildEncryptedSnapshot();
    final file = await _file();
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Decrypts and restores the on-disk backup, or returns false if none
  /// exists yet.
  Future<bool> restoreFromDisk() async {
    final file = await _file();
    if (!await file.exists()) return false;
    await restoreFromBytes(await file.readAsBytes());
    return true;
  }

  /// When the on-disk backup was last written, or null if none exists yet.
  Future<DateTime?> lastExportTime() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return (await file.stat()).modified;
  }
}
