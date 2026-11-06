import 'dart:convert';

import 'package:commonplace/data/services/instagram_api.dart';
import 'package:commonplace/data/services/web_cookies.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A signed-in session as the web view would hand it over.
const testCookieHeader =
    'csrftoken=CSRF123; ds_user_id=4242; sessionid=4242%3Aabc%3A1; mid=Zm1';
const testUserAgent =
    'Mozilla/5.0 (Linux; Android 16; sdk_gphone64_x86_64 Build/BP2A; wv) AppleWebKit/537.36';

String testSessionJson() => jsonEncode(
  InstagramSession.fromCookieHeader(
    testCookieHeader,
    userAgent: testUserAgent,
  ).toJson(),
);

/// Web view cookies without a platform channel.
class FakeWebCookies implements WebCookies {
  FakeWebCookies([this.header]);

  String? header;
  bool cleared = false;

  @override
  Future<String?> read(Uri url) async => header;

  @override
  Future<void> clear() async {
    cleared = true;
    header = null;
  }
}

/// A tiny instagram.com: a Saved list, post lookups and a CDN.
class FakeInstagram {
  /// Saved posts, newest save first.
  final saved = <Map<String, Object?>>[];

  /// Every post that exists, saved or not.
  final posts = <String, Map<String, Object?>>{};

  final requests = <http.Request>[];

  /// Saved list page size (Instagram's web client asks for about a dozen).
  int pageSize = 12;

  bool signedOut = false;

  /// The phone has no connection.
  bool offline = false;

  /// Runs before each request; may throw to drop the connection.
  void Function()? beforeRequest;
  bool rateLimited = false;
  bool challenge = false;

  int get savedListCalls =>
      requests.where((r) => r.url.path == '/api/v1/feed/saved/posts/').length;

  int get cdnCalls => requests.where((r) => r.url.host == 'cdn.test').length;

  /// Creates a post (a reel by default) without saving it.
  Map<String, Object?> post(
    String pk, {
    String kind = 'reel',
    String? caption,
    String user = 'cook.with.ana',
  }) {
    final code = InstagramApi.shortcodeFromPk(pk);
    Map<String, Object?> video(String name) => {
      'media_type': 2,
      'video_versions': [
        {
          'url': 'https://cdn.test/$name-1080.mp4',
          'width': 1080,
          'height': 1920,
        },
        {'url': 'https://cdn.test/$name-720.mp4', 'width': 720, 'height': 1280},
        {'url': 'https://cdn.test/$name-360.mp4', 'width': 360, 'height': 640},
      ],
      'image_versions2': {
        'candidates': [
          {
            'url': 'https://cdn.test/$name-cover.jpg',
            'width': 1080,
            'height': 1920,
          },
        ],
      },
    };
    Map<String, Object?> image(String name) => {
      'media_type': 1,
      'image_versions2': {
        'candidates': [
          {
            'url': 'https://cdn.test/$name-2160.jpg',
            'width': 2160,
            'height': 2700,
          },
          {
            'url': 'https://cdn.test/$name-1080.jpg',
            'width': 1080,
            'height': 1350,
          },
          {
            'url': 'https://cdn.test/$name-320.jpg',
            'width': 320,
            'height': 400,
          },
        ],
      },
    };
    final media = <String, Object?>{
      'pk': pk,
      'id': '${pk}_99',
      'code': code,
      'taken_at': 1760000000,
      'user': {'pk': '99', 'username': user, 'full_name': 'Ana'},
      'caption': caption == null ? null : {'text': caption},
      ...switch (kind) {
        'reel' => {...video('v$pk'), 'product_type': 'clips'},
        'photo' => {...image('i$pk'), 'product_type': 'feed'},
        'carousel' => {
          'media_type': 8,
          'product_type': 'carousel_container',
          'carousel_media': [
            {...image('c${pk}a'), 'pk': '${pk}1'},
            {...video('c${pk}b'), 'pk': '${pk}2'},
          ],
        },
        _ => throw ArgumentError(kind),
      },
    };
    posts[pk] = media;
    return media;
  }

  /// The owner taps Save on a post.
  Map<String, Object?> save(
    String pk, {
    String kind = 'reel',
    String? caption,
    String user = 'cook.with.ana',
  }) {
    final media =
        posts[pk] ?? post(pk, kind: kind, caption: caption, user: user);
    saved.insert(0, media);
    return media;
  }

  String codeOf(String pk) => InstagramApi.shortcodeFromPk(pk);

  late final http.Client client = MockClient((request) async {
    if (offline) throw http.ClientException('Connection refused', request.url);
    beforeRequest?.call();
    requests.add(request);
    final url = request.url;
    if (url.host == 'cdn.test') {
      return http.Response.bytes(List<int>.filled(1024, 7), 200);
    }
    if (signedOut) {
      return _json({'message': 'login_required', 'status': 'fail'}, 401);
    }
    if (challenge) {
      return _json({
        'message': 'checkpoint_required',
        'checkpoint_url': '/challenge/',
        'status': 'fail',
      }, 400);
    }
    if (rateLimited) {
      return _json({
        'message': 'Please wait a few minutes before you try again.',
        'status': 'fail',
      }, 429);
    }
    if (request.headers['X-IG-App-ID'] != InstagramApi.webAppId ||
        !(request.headers['Cookie'] ?? '').contains('sessionid=')) {
      return http.Response('<!DOCTYPE html><html>Login</html>', 200);
    }

    if (url.path == '/api/v1/feed/saved/posts/') {
      final start = int.tryParse(url.queryParameters['max_id'] ?? '') ?? 0;
      final page = saved.skip(start).take(pageSize).toList();
      final more = start + pageSize < saved.length;
      return _json({
        'items': [
          for (final m in page) {'media': m},
        ],
        'num_results': page.length,
        'more_available': more,
        'next_max_id': more ? '${start + pageSize}' : null,
        'status': 'ok',
      });
    }
    final info = RegExp(r'^/api/v1/media/(\d+)/info/$').firstMatch(url.path);
    if (info != null) {
      final media = posts[info.group(1)];
      if (media == null) {
        return _json({
          'message': 'Media not found or unavailable',
          'status': 'fail',
        }, 400);
      }
      return _json({
        'items': [media],
        'num_results': 1,
        'status': 'ok',
      });
    }
    if (RegExp(r'^/api/v1/users/\d+/info/$').hasMatch(url.path)) {
      return _json({
        'user': {'pk': '4242', 'username': 'nemanja.saves'},
        'status': 'ok',
      });
    }
    return _json({'message': 'not found', 'status': 'fail'}, 404);
  });

  static http.Response _json(Map<String, Object?> body, [int status = 200]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
}
