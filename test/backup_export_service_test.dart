import 'dart:io';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/backup_export_service.dart';
import 'package:jarvis_mobile/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for flutter_secure_storage, same pattern as
/// command_router_test.dart's FakeSecureStorageService.
class _FakeSecureStorageService extends SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  group('buildEncryptedBackup / decryptBackup', () {
    test('round-trips arbitrary JSON-safe data under the correct key', () {
      final key = enc.Key.fromSecureRandom(32);
      final data = {
        'notes': ['Erste Notiz', 'Zweite Notiz'],
        'xp': 120,
        'ratio': 0.75,
        'active': true,
      };

      final encrypted = buildEncryptedBackup(data, key);
      final decrypted = decryptBackup(encrypted, key);

      expect(decrypted, data);
    });

    test('produces different ciphertext on every call (random IV)', () {
      final key = enc.Key.fromSecureRandom(32);
      final data = {'a': 1};

      final first = buildEncryptedBackup(data, key);
      final second = buildEncryptedBackup(data, key);

      expect(first, isNot(second));
    });

    test('decrypting with the wrong key fails instead of silently returning garbage', () {
      final data = {'a': 1};
      final encrypted = buildEncryptedBackup(data, enc.Key.fromSecureRandom(32));

      expect(() => decryptBackup(encrypted, enc.Key.fromSecureRandom(32)), throwsA(anything));
    });
  });

  group('BackupExportService', () {
    late Directory tempDir;
    late BackupExportService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('jarvis_backup_test_');
      service = BackupExportService(directoryOverride: tempDir, secureStorage: _FakeSecureStorageService());
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('collectBackupData reflects SharedPreferences and excludes secret-shaped legacy keys', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notes', '["Testnotiz"]');
      await prefs.setBool('rss_feed_check_enabled', true);
      await prefs.setString('news_api_key', 'should-never-be-backed-up');

      final data = await service.collectBackupData();

      expect(data['notes'], '["Testnotiz"]');
      expect(data['rss_feed_check_enabled'], true);
      expect(data.containsKey('news_api_key'), isFalse);
    });

    test('restoreBackupData writes every supported SharedPreferences value type back', () async {
      await service.restoreBackupData({
        'a_string': 'hello',
        'a_bool': true,
        'an_int': 42,
        'a_double': 3.5,
        'a_list': ['x', 'y'],
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('a_string'), 'hello');
      expect(prefs.getBool('a_bool'), true);
      expect(prefs.getInt('an_int'), 42);
      expect(prefs.getDouble('a_double'), 3.5);
      expect(prefs.getStringList('a_list'), ['x', 'y']);
    });

    test('lastExportTime is null before any export exists', () async {
      expect(await service.lastExportTime(), isNull);
    });

    test('exportNow writes a real encrypted file and lastExportTime reflects it', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notes', '["Etwas Wichtiges"]');

      final file = await service.exportNow();

      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));
      expect(await service.lastExportTime(), isNotNull);
    });

    test('the encryption key is persisted and reused across service instances sharing secure storage', () async {
      final sharedSecure = _FakeSecureStorageService();
      final serviceA = BackupExportService(directoryOverride: tempDir, secureStorage: sharedSecure);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notes', '["Von Instanz A"]');
      await serviceA.exportNow();

      await prefs.setString('notes', '["Wird überschrieben"]');
      final serviceB = BackupExportService(directoryOverride: tempDir, secureStorage: sharedSecure);
      final restored = await serviceB.restoreFromDisk();

      expect(restored, isTrue);
      expect(prefs.getString('notes'), '["Von Instanz A"]');
    });

    test('restoreFromDisk returns false when no backup file exists yet', () async {
      expect(await service.restoreFromDisk(), isFalse);
    });

    test('exportNow then restoreFromDisk round-trips the actual app data', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notes', '["Original-Notiz"]');
      await service.exportNow();

      await prefs.setString('notes', '["Überschrieben"]');
      final restored = await service.restoreFromDisk();

      expect(restored, isTrue);
      expect(prefs.getString('notes'), '["Original-Notiz"]');
    });
  });
}
