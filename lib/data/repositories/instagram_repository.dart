import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/database/app_database.dart';
import '../services/instagram_api.dart';
import '../services/local_stores.dart';
import '../services/web_cookies.dart';

/// Files fetched for one post, already in app storage.
@immutable
class FetchedPost {
  const FetchedPost(this.post, this.mediaPaths);

  final InstagramPost post;
  final List<String> mediaPaths;
}

/// The owner's Instagram sign-in and everything read through it.
class InstagramRepository extends ChangeNotifier {
  InstagramRepository({
    required SecretStore secrets,
    required KeyValueStore prefs,
    required AppDatabase db,
    required MediaStore media,
    required WebCookies cookies,
    required http.Client httpClient,
    Uri? baseUri,
    DateTime Function()? clock,
  }) : _secrets = secrets,
       _prefs = prefs,
       _db = db,
       _media = media,
       _cookies = cookies,
       _now = clock ?? DateTime.now {
    _api = InstagramApi(
      httpClient: httpClient,
      baseUri: baseUri,
      readSession: () async => _session,
      writeSession: _storeSession,
    );
  }

  final SecretStore _secrets;
  final KeyValueStore _prefs;
  final AppDatabase _db;
  final MediaStore _media;
  final WebCookies _cookies;
  final DateTime Function() _now;
  late final InstagramApi _api;

  InstagramSession? _session;

  static const _usernameKey = 'instagram_username';
  static const _signedOutKey = 'instagram_signed_out';
  static const _checkedKey = 'instagram_checked_at';
  static const _baselineKey = 'instagram_baseline_done';

  /// Where the sign-in web view starts.
  Uri get signInUri => _api.baseUri.replace(path: '/accounts/login/');
  Uri get baseUri => _api.baseUri;

  /// Signed in and working.
  bool get isConnected => _session != null && !needsSignIn;

  /// Signed in at some point (possibly signed out by Instagram since).
  bool get hasAccount => _session != null;

  /// Instagram ended the session; the owner has to sign in again.
  bool get needsSignIn => _prefs.getBool(_signedOutKey) ?? false;

  String? get username => _prefs.getString(_usernameKey);

  DateTime? get lastCheckedAt =>
      DateTime.tryParse(_prefs.getString(_checkedKey) ?? '');

  /// Whether the Saved list's starting point has been recorded, so only
  /// saves made after connecting turn into notes.
  bool get baselineDone => _prefs.getBool(_baselineKey) ?? false;

  Future<void> load() async {
    final raw = await _secrets.readInstagramSession();
    if (raw == null) return;
    try {
      _session = InstagramSession.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } on Object catch (e) {
      debugPrint('Dropping unreadable Instagram session: $e');
      await _secrets.writeInstagramSession(null);
    }
  }

  /// Picks up the session from the sign-in web view.
  ///
  /// Returns false while the owner hasn't finished signing in.
  Future<bool> completeSignIn({required String userAgent}) async {
    final header = await _cookies.read(baseUri);
    if (header == null || header.isEmpty) return false;
    final session = InstagramSession.fromCookieHeader(
      header,
      userAgent: userAgent,
    );
    if (!session.isSignedIn) return false;

    final previousUser = _session?.userId;
    await _storeSession(session);
    await _prefs.setBool(_signedOutKey, false);
    if (previousUser != null && previousUser != session.userId) {
      // A different account: start its Saved list from scratch.
      await _prefs.setBool(_baselineKey, false);
    }
    notifyListeners();

    final id = session.userId;
    if (id != null) {
      try {
        final name = await _api.username(id);
        if (name != null) {
          await _prefs.setString(_usernameKey, name);
          notifyListeners();
        }
      } on InstagramException catch (e) {
        debugPrint('Could not read the Instagram username: $e');
      }
    }
    return true;
  }

  /// Forgets the sign-in on this phone. Notes stay.
  Future<void> disconnect() async {
    _session = null;
    await _secrets.writeInstagramSession(null);
    await _prefs.setString(_usernameKey, null);
    await _prefs.setString(_checkedKey, null);
    await _prefs.setBool(_signedOutKey, false);
    await _prefs.setBool(_baselineKey, false);
    try {
      await _cookies.clear();
    } on Object catch (e) {
      debugPrint('Could not clear web view cookies: $e');
    }
    notifyListeners();
  }

  Future<SavedPage> savedPage({String? maxId}) =>
      _guard(() => _api.savedPosts(maxId: maxId));

  /// Looks a post up and downloads its video or images into app storage.
  Future<FetchedPost> fetch({String? pk, String? shortcode}) async {
    final id =
        pk ??
        (shortcode == null ? null : InstagramApi.pkFromShortcode(shortcode));
    if (id == null) {
      throw const InstagramException(InstagramFailure.notFound, 'no id');
    }
    final post = await _guard(() => _api.post(id));
    if (post.assets.isEmpty) {
      throw const InstagramException(
        InstagramFailure.notFound,
        'post has no media',
      );
    }
    final paths = <String>[];
    try {
      for (final asset in post.assets) {
        final path = await _media.newPath(asset.extension);
        await _api.download(asset.url, File(path));
        paths.add(path);
      }
    } on Object {
      await _media.discard(paths);
      rethrow;
    }
    return FetchedPost(post, paths);
  }

  Future<bool> isSeen(String pk) async =>
      await (_db.select(
        _db.seenPosts,
      )..where((t) => t.pk.equals(pk))).getSingleOrNull() !=
      null;

  Future<void> markSeen(Iterable<String> pks) async {
    final now = _now();
    await _db.batch((b) {
      b.insertAll(_db.seenPosts, [
        for (final pk in pks) SeenPostsCompanion.insert(pk: pk, seenAt: now),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  Future<void> markChecked() async {
    await _prefs.setString(_checkedKey, _now().toIso8601String());
    notifyListeners();
  }

  Future<void> markBaselineDone() => _prefs.setBool(_baselineKey, true);

  /// The next check takes the Saved list as it is then as the starting
  /// point, instead of making notes of everything saved in between.
  Future<void> resetBaseline() => _prefs.setBool(_baselineKey, false);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on InstagramException catch (e) {
      if (e.failure == InstagramFailure.signedOut && !needsSignIn) {
        await _prefs.setBool(_signedOutKey, true);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> _storeSession(InstagramSession session) async {
    _session = session;
    await _secrets.writeInstagramSession(jsonEncode(session.toJson()));
  }
}
