import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Why talking to Instagram failed, with a message for the owner.
enum InstagramFailure {
  signedOut('Instagram signed Commonplace out. Sign in again to continue.'),
  rateLimited(
    'Instagram asked Commonplace to slow down. It will try again in a few minutes.',
  ),
  notFound(
    "Instagram didn't share this post. It may be private or deleted. Add the video yourself.",
  ),
  network("Couldn't reach Instagram. Check your connection and try again."),
  badResponse('Instagram sent something unexpected. Try again later.');

  const InstagramFailure(this.message);

  final String message;
}

class InstagramException implements Exception {
  const InstagramException(this.failure, [this.detail]);

  final InstagramFailure failure;
  final String? detail;

  @override
  String toString() =>
      'InstagramException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// The owner's instagram.com sign-in: the cookies the web view received,
/// and that web view's user agent so requests come from the same browser.
@immutable
class InstagramSession {
  const InstagramSession({
    required this.cookies,
    required this.userAgent,
    this.wwwClaim = '0',
  });

  /// Parses a `Cookie` header value like `a=1; b=2`.
  factory InstagramSession.fromCookieHeader(
    String header, {
    required String userAgent,
  }) {
    final cookies = <String, String>{};
    for (final part in header.split(';')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      final name = part.substring(0, i).trim();
      final value = part.substring(i + 1).trim();
      if (name.isNotEmpty && value.isNotEmpty) cookies[name] = value;
    }
    return InstagramSession(cookies: cookies, userAgent: userAgent);
  }

  factory InstagramSession.fromJson(Map<String, Object?> json) =>
      InstagramSession(
        cookies: {
          for (final e
              in (json['cookies'] as Map<String, Object?>? ?? {}).entries)
            if (e.value is String) e.key: e.value! as String,
        },
        userAgent: json['userAgent'] as String? ?? '',
        wwwClaim: json['wwwClaim'] as String? ?? '0',
      );

  final Map<String, String> cookies;
  final String userAgent;

  /// Echoed back to Instagram the way its web client does.
  final String wwwClaim;

  bool get isSignedIn => (cookies['sessionid'] ?? '').isNotEmpty;
  String? get userId => cookies['ds_user_id'];
  String? get csrfToken => cookies['csrftoken'];

  String get cookieHeader =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Map<String, Object?> toJson() => {
    'cookies': cookies,
    'userAgent': userAgent,
    'wwwClaim': wwwClaim,
  };

  /// Applies `Set-Cookie` headers and a new www-claim from a response.
  InstagramSession updatedBy(http.BaseResponse response) {
    final claim = response.headers['x-ig-set-www-claim'];
    final raw = response.headers['set-cookie'];
    if (raw == null && (claim == null || claim == wwwClaim)) return this;
    final next = Map.of(cookies);
    if (raw != null) {
      for (final cookie in splitSetCookie(raw)) {
        final first = cookie.split(';').first;
        final i = first.indexOf('=');
        if (i <= 0) continue;
        final name = first.substring(0, i).trim();
        final value = first.substring(i + 1).trim();
        final attributes = cookie.toLowerCase();
        final expired =
            value.isEmpty ||
            value == '""' ||
            attributes.contains('max-age=0') ||
            attributes.contains('expires=thu, 01-jan-1970');
        if (expired) {
          next.remove(name);
        } else {
          next[name] = value;
        }
      }
    }
    return InstagramSession(
      cookies: next,
      userAgent: userAgent,
      wwwClaim: claim ?? wwwClaim,
    );
  }

  /// package:http joins repeated `Set-Cookie` headers with commas, and
  /// `Expires` dates contain commas too. Split only where a new `name=` starts.
  @visibleForTesting
  static List<String> splitSetCookie(String header) => header
      .split(RegExp(r',(?=\s*[^;,\s]+=)'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  bool operator ==(Object other) =>
      other is InstagramSession &&
      other.userAgent == userAgent &&
      other.wwwClaim == wwwClaim &&
      mapEquals(other.cookies, cookies);

  @override
  int get hashCode =>
      Object.hash(userAgent, wwwClaim, Object.hashAllUnordered(cookies.keys));
}

enum InstagramAssetKind { video, image }

/// One downloadable file of a post.
@immutable
class InstagramAsset {
  const InstagramAsset(this.url, this.kind);

  final String url;
  final InstagramAssetKind kind;

  String get extension => kind == InstagramAssetKind.video ? '.mp4' : '.jpg';
}

/// A reel, photo or carousel, as Instagram's web API describes it.
@immutable
class InstagramPost {
  const InstagramPost({
    required this.pk,
    required this.code,
    required this.isReel,
    required this.assets,
    this.caption,
    this.username,
  });

  /// Carousels can hold twenty items; the first ten carry the idea.
  static const maxAssets = 10;

  factory InstagramPost.fromJson(Map<String, Object?> m) {
    final pk = m['pk'] ?? m['id'];
    final code = m['code'];
    if (pk == null || code is! String || code.isEmpty) {
      throw const InstagramException(
        InstagramFailure.badResponse,
        'post without pk or code',
      );
    }
    final assets = <InstagramAsset>[];
    final carousel = m['carousel_media'];
    if (carousel is List && carousel.isNotEmpty) {
      for (final item in carousel.whereType<Map<String, Object?>>()) {
        final a = _assetOf(item);
        if (a != null) assets.add(a);
        if (assets.length == maxAssets) break;
      }
    } else {
      final a = _assetOf(m);
      if (a != null) assets.add(a);
    }
    final caption = switch (m['caption']) {
      {'text': final String text} when text.trim().isNotEmpty => text.trim(),
      _ => null,
    };
    final username = switch (m['user']) {
      {'username': final String name} when name.isNotEmpty => name,
      _ => null,
    };
    return InstagramPost(
      // Instagram ids are 64-bit; keep them as strings end to end.
      pk: '${pk is String ? pk.split('_').first : pk}',
      code: code,
      isReel: m['product_type'] == 'clips',
      assets: assets,
      caption: caption,
      username: username,
    );
  }

  final String pk;
  final String code;
  final bool isReel;
  final List<InstagramAsset> assets;
  final String? caption;
  final String? username;

  bool get hasVideo => assets.any((a) => a.kind == InstagramAssetKind.video);

  String get url => 'https://www.instagram.com/${isReel ? 'reel' : 'p'}/$code/';

  static InstagramAsset? _assetOf(Map<String, Object?> m) {
    final videos = _sized(m['video_versions']);
    if (videos.isNotEmpty) {
      // Gemini looks at video in low resolution anyway; a small file uploads
      // faster and stays under the inline limit. Prefer the smallest that is
      // still readable (480 px wide or more).
      videos.sort((a, b) => a.$2.compareTo(b.$2));
      final pick = videos.firstWhere(
        (v) => v.$2 >= 480,
        orElse: () => videos.last,
      );
      return InstagramAsset(pick.$1, InstagramAssetKind.video);
    }
    final images = switch (m['image_versions2']) {
      {'candidates': final Object? c} => _sized(c),
      _ => <(String, int)>[],
    };
    if (images.isEmpty) return null;
    images.sort((a, b) => b.$2.compareTo(a.$2));
    final pick = images.firstWhere(
      (i) => i.$2 <= 1440,
      orElse: () => images.last,
    );
    return InstagramAsset(pick.$1, InstagramAssetKind.image);
  }

  /// `[(url, width)]` from a list of `{url, width, height}`.
  static List<(String, int)> _sized(Object? list) => [
    if (list is List)
      for (final v in list.whereType<Map<String, Object?>>())
        if (v['url'] case final String url when url.isNotEmpty)
          (url, (v['width'] as num?)?.toInt() ?? 0),
  ];
}

/// One page of the Saved list, newest save first.
@immutable
class SavedPage {
  const SavedPage(this.posts, {this.nextMaxId, this.moreAvailable = false});

  final List<InstagramPost> posts;
  final String? nextMaxId;
  final bool moreAvailable;
}

/// Reads the owner's own Instagram data through the endpoints instagram.com
/// itself uses, signed in with the owner's own session.
///
/// Instagram offers no official API for saved posts. This sends what the
/// website sends and nothing more. It never tries to get around a challenge:
/// when Instagram asks for a sign-in or a check, the owner is sent back to
/// the real sign-in page.
class InstagramApi {
  InstagramApi({
    required http.Client httpClient,
    required Future<InstagramSession?> Function() readSession,
    required Future<void> Function(InstagramSession) writeSession,
    Uri? baseUri,
    this.timeout = const Duration(seconds: 30),
  }) : _http = httpClient,
       _readSession = readSession,
       _writeSession = writeSession,
       baseUri = baseUri ?? Uri.parse('https://www.instagram.com');

  final http.Client _http;
  final Future<InstagramSession?> Function() _readSession;
  final Future<void> Function(InstagramSession) _writeSession;
  final Uri baseUri;
  final Duration timeout;

  /// The app id instagram.com's own web client sends with API calls.
  static const webAppId = '936619743392459';
  static const _asbdId = '129477';

  /// Downloads bigger than this are refused (a reel is usually 2 to 20 MB).
  static const maxDownloadBytes = 150 * 1024 * 1024;

  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

  /// The numeric media id behind a shortcode (`C9xYz12AbCd`), or null.
  ///
  /// Shortcodes are the id written in base 64. Private posts use longer
  /// codes whose first eleven characters are the id.
  static String? pkFromShortcode(String code) {
    final c = code.length > 11 ? code.substring(0, 11) : code;
    if (c.isEmpty) return null;
    var n = BigInt.zero;
    for (final ch in c.split('')) {
      final i = _alphabet.indexOf(ch);
      if (i < 0) return null;
      n = n * BigInt.from(64) + BigInt.from(i);
    }
    return n.toString();
  }

  static String shortcodeFromPk(String pk) {
    var n = BigInt.parse(pk);
    if (n == BigInt.zero) return 'A';
    final out = StringBuffer();
    final chars = <String>[];
    while (n > BigInt.zero) {
      chars.add(_alphabet[(n % BigInt.from(64)).toInt()]);
      n = n ~/ BigInt.from(64);
    }
    out.writeAll(chars.reversed);
    return out.toString();
  }

  /// A page of the Saved list ("All posts"), newest first.
  Future<SavedPage> savedPosts({String? maxId}) async {
    final json = await _get('/api/v1/feed/saved/posts/', {'max_id': ?maxId});
    final posts = <InstagramPost>[];
    final items = json['items'];
    if (items is List) {
      for (final item in items.whereType<Map<String, Object?>>()) {
        final media = item['media'] is Map<String, Object?>
            ? item['media']! as Map<String, Object?>
            : item;
        try {
          posts.add(InstagramPost.fromJson(media));
        } on InstagramException catch (e) {
          debugPrint('Skipping saved item: $e');
        }
      }
    }
    final next = json['next_max_id'];
    return SavedPage(
      posts,
      nextMaxId: next == null ? null : '$next',
      moreAvailable: json['more_available'] == true,
    );
  }

  /// One post by its numeric id.
  Future<InstagramPost> post(String pk) async {
    final json = await _get('/api/v1/media/$pk/info/');
    final items = json['items'];
    if (items is! List || items.isEmpty || items.first is! Map) {
      throw const InstagramException(InstagramFailure.notFound);
    }
    return InstagramPost.fromJson(items.first as Map<String, Object?>);
  }

  /// The signed-in account's @handle, or null if Instagram won't say.
  Future<String?> username(String userId) async {
    try {
      final json = await _get('/api/v1/users/$userId/info/');
      return switch (json['user']) {
        {'username': final String name} when name.isNotEmpty => name,
        _ => null,
      };
    } on InstagramException catch (e) {
      if (e.failure == InstagramFailure.signedOut) rethrow;
      return null;
    }
  }

  /// Downloads a post's file from Instagram's CDN into [target].
  ///
  /// CDN links are signed and expire, so they're used right after [post].
  Future<void> download(String url, File target) async {
    final http.StreamedResponse response;
    try {
      final request = http.Request('GET', Uri.parse(url));
      response = await _http.send(request).timeout(timeout);
    } on TimeoutException {
      throw const InstagramException(InstagramFailure.network, 'timeout');
    } on http.ClientException catch (e) {
      throw InstagramException(InstagramFailure.network, e.message);
    } on SocketException catch (e) {
      throw InstagramException(InstagramFailure.network, e.message);
    }
    if (response.statusCode == 403 || response.statusCode == 404) {
      // An expired or withdrawn CDN link.
      throw InstagramException(
        InstagramFailure.notFound,
        'cdn ${response.statusCode}',
      );
    }
    if (response.statusCode != 200) {
      throw InstagramException(
        InstagramFailure.network,
        'cdn ${response.statusCode}',
      );
    }
    final sink = target.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(timeout)) {
        received += chunk.length;
        if (received > maxDownloadBytes) {
          throw const InstagramException(
            InstagramFailure.badResponse,
            'file too large',
          );
        }
        sink.add(chunk);
      }
      await sink.close();
    } catch (e) {
      await sink.close();
      if (await target.exists()) await target.delete();
      if (e is InstagramException) rethrow;
      throw InstagramException(InstagramFailure.network, '$e');
    }
  }

  Future<Map<String, Object?>> _get(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    final session = await _readSession();
    if (session == null || !session.isSignedIn) {
      throw const InstagramException(InstagramFailure.signedOut, 'no session');
    }
    final uri = baseUri.replace(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );
    final http.Response response;
    try {
      response = await _http
          .get(uri, headers: _headers(session))
          .timeout(timeout);
    } on TimeoutException {
      throw const InstagramException(InstagramFailure.network, 'timeout');
    } on http.ClientException catch (e) {
      throw InstagramException(InstagramFailure.network, e.message);
    } on SocketException catch (e) {
      throw InstagramException(InstagramFailure.network, e.message);
    }

    final updated = session.updatedBy(response);
    if (updated != session) await _writeSession(updated);

    return parseResponse(response.statusCode, response.body);
  }

  Map<String, String> _headers(InstagramSession s) => {
    'Accept': '*/*',
    'Cookie': s.cookieHeader,
    if (s.userAgent.isNotEmpty) 'User-Agent': s.userAgent,
    'X-IG-App-ID': webAppId,
    'X-ASBD-ID': _asbdId,
    'X-IG-WWW-Claim': s.wwwClaim,
    'X-Requested-With': 'XMLHttpRequest',
    'X-CSRFToken': ?s.csrfToken,
    'Referer': '${baseUri.origin}/',
  };

  /// Turns a response into JSON, or the failure it stands for.
  @visibleForTesting
  static Map<String, Object?> parseResponse(int status, String body) {
    Map<String, Object?>? json;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) json = decoded;
    } on FormatException {
      json = null;
    }

    if (status == 200 && json != null && json['status'] == 'ok') return json;

    // Only Instagram's own message is inspected, never post content.
    final message = '${json?['message'] ?? ''} ${json?['error_type'] ?? ''}'
        .toLowerCase();
    if (status == 401 ||
        status == 403 ||
        message.contains('login_required') ||
        message.contains('checkpoint_required') ||
        message.contains('challenge_required') ||
        json?['require_login'] == true) {
      throw InstagramException(InstagramFailure.signedOut, message.trim());
    }
    if (status == 429 ||
        message.contains('please wait') ||
        message.contains('spam')) {
      throw InstagramException(InstagramFailure.rateLimited, message.trim());
    }
    if (status == 404 ||
        message.contains('not found') ||
        message.contains('unavailable') ||
        message.contains('media_not_found')) {
      throw InstagramException(InstagramFailure.notFound, message.trim());
    }
    if (status >= 500) {
      throw InstagramException(InstagramFailure.network, 'http $status');
    }
    if (json == null) {
      // A signed-out session is answered with the HTML sign-in page.
      final looksLikePage = body.trimLeft().startsWith('<');
      throw InstagramException(
        looksLikePage
            ? InstagramFailure.signedOut
            : InstagramFailure.badResponse,
        'not json (http $status)',
      );
    }
    throw InstagramException(
      InstagramFailure.badResponse,
      'http $status ${message.trim()}',
    );
  }
}
