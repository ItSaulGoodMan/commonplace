import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the Gemini API key and the Instagram sign-in in the platform
/// keystore, never in plain prefs.
class SecretStore {
  SecretStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _geminiKey = 'gemini_api_key';
  static const _instagramSession = 'instagram_session';
  static const _session = 'commonplace_session';

  /// The Commonplace server session (Play edition).
  Future<String?> readSession() => _storage.read(key: _session);

  Future<void> writeSession(String? value) async {
    if (value == null) {
      await _storage.delete(key: _session);
    } else {
      await _storage.write(key: _session, value: value);
    }
  }

  Future<String?> readInstagramSession() =>
      _storage.read(key: _instagramSession);

  Future<void> writeInstagramSession(String? value) async {
    if (value == null) {
      await _storage.delete(key: _instagramSession);
    } else {
      await _storage.write(key: _instagramSession, value: value);
    }
  }

  Future<String?> readGeminiKey() => _storage.read(key: _geminiKey);

  Future<void> writeGeminiKey(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _storage.delete(key: _geminiKey);
    } else {
      await _storage.write(key: _geminiKey, value: value.trim());
    }
  }
}

/// Plain key-value settings (nothing sensitive).
abstract interface class KeyValueStore {
  String? getString(String key);
  bool? getBool(String key);
  Future<void> setString(String key, String? value);
  Future<void> setBool(String key, bool value);
}

/// [KeyValueStore] backed by shared preferences.
class PreferencesStore implements KeyValueStore {
  PreferencesStore(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static Future<PreferencesStore> open() async => PreferencesStore(
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    ),
  );

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setString(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
}

/// Owns the app's private copies of shared videos and images.
///
/// Shared files arrive in a cache folder the OS may clear at any time, so they
/// are moved here until the AI has read them.
class MediaStore {
  MediaStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDir;

  Future<Directory> _mediaDir() async {
    final dir = Directory(p.join((await _baseDir()).path, 'media'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies [sourcePath] into app storage and returns the new path.
  Future<String> keep(String sourcePath) async {
    final dir = await _mediaDir();
    final ext = p.extension(sourcePath).toLowerCase();
    final name =
        '${DateTime.now().microsecondsSinceEpoch}${ext.isEmpty ? '' : ext}';
    final target = p.join(dir.path, name);
    final source = File(sourcePath);
    try {
      await source.rename(target);
    } on FileSystemException {
      await source.copy(target);
    }
    return target;
  }

  /// A fresh path in app storage for a file about to be downloaded.
  Future<String> newPath(String extension) async {
    final dir = await _mediaDir();
    _counter++;
    return p.join(
      dir.path,
      '${DateTime.now().microsecondsSinceEpoch}_$_counter$extension',
    );
  }

  static var _counter = 0;

  Future<void> discard(Iterable<String> paths) async {
    for (final path in paths) {
      final f = File(path);
      if (await f.exists()) {
        try {
          await f.delete();
        } on FileSystemException {
          // Already gone or locked; nothing useful to do.
        }
      }
    }
  }

  static String mimeTypeFor(String path) {
    final ext = p.extension(path).toLowerCase();
    return switch (ext) {
      '.mp4' || '.m4v' => 'video/mp4',
      '.mov' => 'video/mov',
      '.webm' => 'video/webm',
      '.3gp' => 'video/3gpp',
      '.mkv' => 'video/x-matroska',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.heic' => 'image/heic',
      '.heif' => 'image/heif',
      '.gif' => 'image/gif',
      _ => 'application/octet-stream',
    };
  }

  static bool isVideo(String path) => mimeTypeFor(path).startsWith('video/');
  static bool isImage(String path) => mimeTypeFor(path).startsWith('image/');
}
