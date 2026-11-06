import 'dart:convert';
import 'dart:io';

import 'package:commonplace/data/services/instagram_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fake_instagram.dart';

void main() {
  InstagramSession signedIn() => InstagramSession.fromCookieHeader(
    testCookieHeader,
    userAgent: testUserAgent,
  );

  InstagramApi api(
    http.Client client, {
    InstagramSession? session,
    List<InstagramSession>? written,
  }) {
    var current = session ?? signedIn();
    return InstagramApi(
      httpClient: client,
      readSession: () async => current,
      writeSession: (s) async {
        current = s;
        written?.add(s);
      },
    );
  }

  test('sends what instagram.com sends, with the owner\'s session', () async {
    final ig = FakeInstagram()..save('3300000000000000001');
    await api(ig.client).savedPosts();

    final r = ig.requests.single;
    expect(
      r.url.toString(),
      'https://www.instagram.com/api/v1/feed/saved/posts/',
    );
    expect(r.method, 'GET');
    expect(r.headers['X-IG-App-ID'], '936619743392459');
    expect(r.headers['X-CSRFToken'], 'CSRF123');
    expect(r.headers['Cookie'], contains('sessionid=4242%3Aabc%3A1'));
    expect(r.headers['User-Agent'], testUserAgent);
    expect(r.headers['Referer'], 'https://www.instagram.com/');
  });

  test('reads reels, photos and carousels from the Saved list', () async {
    final ig = FakeInstagram()
      ..save('3300000000000000003', kind: 'carousel')
      ..save('3300000000000000002', kind: 'photo')
      ..save('3300000000000000001', caption: 'Pasta water: salt it hard.');
    final page = await api(ig.client).savedPosts();

    expect(page.posts.map((p) => p.pk), [
      '3300000000000000001',
      '3300000000000000002',
      '3300000000000000003',
    ]);
    final reel = page.posts[0];
    expect(reel.isReel, isTrue);
    expect(reel.code, InstagramApi.shortcodeFromPk('3300000000000000001'));
    expect(reel.url, 'https://www.instagram.com/reel/${reel.code}/');
    expect(reel.caption, 'Pasta water: salt it hard.');
    expect(reel.username, 'cook.with.ana');
    expect(
      reel.assets.single.url,
      endsWith('-720.mp4'),
      reason: 'the smallest version that is still 480 px or wider',
    );

    final photo = page.posts[1];
    expect(photo.isReel, isFalse);
    expect(photo.url, startsWith('https://www.instagram.com/p/'));
    expect(photo.hasVideo, isFalse);
    expect(photo.assets.single.url, endsWith('-1080.jpg'));

    final carousel = page.posts[2];
    expect(carousel.assets.map((a) => a.kind), [
      InstagramAssetKind.image,
      InstagramAssetKind.video,
    ]);
    expect(carousel.hasVideo, isTrue);
  });

  test('carousels are capped at ten items', () {
    final post = InstagramPost.fromJson({
      'pk': '1',
      'code': 'B',
      'carousel_media': [
        for (var i = 0; i < 20; i++)
          {
            'image_versions2': {
              'candidates': [
                {'url': 'https://cdn.test/$i.jpg', 'width': 1080},
              ],
            },
          },
      ],
    });
    expect(post.assets, hasLength(InstagramPost.maxAssets));
  });

  test('large ids survive as text', () {
    final post = InstagramPost.fromJson({
      'pk': 3412345678901234567,
      'code': 'C9xYz12AbCd',
      'video_versions': [
        {'url': 'https://cdn.test/a.mp4', 'width': 720},
      ],
    });
    expect(post.pk, '3412345678901234567');
  });

  group('failures', () {
    InstagramFailure? failureOf(int status, String body) {
      try {
        InstagramApi.parseResponse(status, body);
        return null;
      } on InstagramException catch (e) {
        return e.failure;
      }
    }

    test('a signed-out session', () {
      expect(
        failureOf(200, '<!DOCTYPE html><html lang="en">Log in</html>'),
        InstagramFailure.signedOut,
      );
      expect(
        failureOf(
          401,
          jsonEncode({'message': 'login_required', 'status': 'fail'}),
        ),
        InstagramFailure.signedOut,
      );
      expect(
        failureOf(
          400,
          jsonEncode({'message': 'checkpoint_required', 'status': 'fail'}),
        ),
        InstagramFailure.signedOut,
        reason: 'challenges are for the owner to answer on Instagram',
      );
    });

    test('slow down', () {
      expect(failureOf(429, '{}'), InstagramFailure.rateLimited);
      expect(
        failureOf(
          400,
          jsonEncode({
            'message': 'Please wait a few minutes before you try again.',
            'status': 'fail',
          }),
        ),
        InstagramFailure.rateLimited,
      );
    });

    test('missing posts and broken servers', () {
      expect(
        failureOf(
          400,
          jsonEncode({
            'message': 'Media not found or unavailable',
            'status': 'fail',
          }),
        ),
        InstagramFailure.notFound,
      );
      expect(failureOf(502, 'Bad gateway'), InstagramFailure.network);
      expect(
        failureOf(200, '{"status": "weird"}'),
        InstagramFailure.badResponse,
      );
    });

    test('post content never looks like an error', () {
      expect(
        failureOf(
          200,
          jsonEncode({
            'items': [
              {
                'caption': {'text': 'login_required? spam? please wait!'},
              },
            ],
            'status': 'ok',
          }),
        ),
        isNull,
      );
    });

    test('no session means no request', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      final noSession = InstagramApi(
        httpClient: client,
        readSession: () async => null,
        writeSession: (_) async {},
      );
      await expectLater(
        noSession.savedPosts(),
        throwsA(
          isA<InstagramException>().having(
            (e) => e.failure,
            'failure',
            InstagramFailure.signedOut,
          ),
        ),
      );
      expect(calls, 0);
    });
  });

  test('keeps the session up to date from Set-Cookie', () async {
    final written = <InstagramSession>[];
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'items': [], 'more_available': false, 'status': 'ok'}),
        200,
        headers: {
          // package:http joins repeated headers with commas.
          'set-cookie':
              'csrftoken=NEWCSRF; Domain=.instagram.com; expires=Fri, 05-Nov-2027 10:00:00 GMT; Path=/; Secure,'
              'mid=""; Domain=.instagram.com; expires=Thu, 01-Jan-1970 00:00:00 GMT; Max-Age=0; Path=/',
          'x-ig-set-www-claim': 'hmac.AR3abc',
        },
      ),
    );
    await api(client, written: written).savedPosts();

    final s = written.single;
    expect(s.csrfToken, 'NEWCSRF');
    expect(s.cookies.containsKey('mid'), isFalse);
    expect(s.cookies['sessionid'], '4242%3Aabc%3A1');
    expect(s.wwwClaim, 'hmac.AR3abc');
  });

  test('shortcodes and ids convert both ways', () {
    const pk = '3412345678901234567';
    final code = InstagramApi.shortcodeFromPk(pk);
    expect(code, hasLength(11));
    expect(InstagramApi.pkFromShortcode(code), pk);
    // Private posts have longer codes that start with the public one.
    expect(InstagramApi.pkFromShortcode('${code}XyZ_extra-private-part'), pk);
    expect(InstagramApi.pkFromShortcode('not!valid'), isNull);
  });

  test(
    'downloads a file, and leaves nothing behind when the link is dead',
    () async {
      final dir = await Directory.systemTemp.createTemp('ig_download');
      addTearDown(() => dir.delete(recursive: true));
      final ok = File('${dir.path}/a.mp4');
      final ig = FakeInstagram();
      await api(ig.client).download('https://cdn.test/a.mp4', ok);
      expect(await ok.length(), 1024);
      expect(
        ig.requests.single.headers.containsKey('Cookie'),
        isFalse,
        reason: 'the CDN gets no sign-in cookies',
      );

      final dead = File('${dir.path}/b.mp4');
      final gone = MockClient((_) async => http.Response('', 403));
      await expectLater(
        api(gone).download('https://cdn.test/b.mp4', dead),
        throwsA(
          isA<InstagramException>().having(
            (e) => e.failure,
            'failure',
            InstagramFailure.notFound,
          ),
        ),
      );
      expect(await dead.exists(), isFalse);
    },
  );
}
