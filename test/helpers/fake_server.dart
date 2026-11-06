import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The Commonplace server (`server/`), in memory, as the app sees it.
class FakeServer {
  final requests = <http.Request>[];

  /// Next answer for /v1/extract and /v1/write: work, or fail like the
  /// server does.
  String mode = 'ok';

  int notesToday = 0;
  int notesPerDay = 3;
  bool plus = false;
  bool sessionValid = true;
  String? lastPurchaseToken;

  static const accountRef =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Map<String, Object?> account() => {
    'email': 'tester@example.com',
    'name': 'Test Person',
    'plan': plus ? 'plus' : 'free',
    'plusUntil': plus ? DateTime(2026, 12, 6).millisecondsSinceEpoch : null,
    'notesToday': notesToday,
    'notesPerDay': plus ? 25 : notesPerDay,
    'freeNotesPerDay': 3,
    'plusNotesPerDay': 25,
    'resetsAt': DateTime.now()
        .add(const Duration(hours: 5))
        .millisecondsSinceEpoch,
    'accountRef': accountRef,
  };

  Iterable<http.Request> calls(String path) =>
      requests.where((r) => r.url.path == path);

  late final http.Client client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path == '/v1/session') {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      if (!(body['idToken'] as String).startsWith('dev:')) {
        return _error(401, 'signed_out', 'Sign in again.');
      }
      sessionValid = true;
      return _json({'session': 'session-1', 'account': account()});
    }
    if (!sessionValid ||
        request.headers['Authorization'] != 'Bearer session-1') {
      return _error(401, 'signed_out', 'Sign in with Google to continue.');
    }
    switch ((request.method, path)) {
      case ('GET', '/v1/me'):
        return _json({'account': account()});
      case ('DELETE', '/v1/me'):
        return _json({'deleted': true});
      case ('POST', '/v1/plus'):
        final body = jsonDecode(request.body) as Map<String, Object?>;
        lastPurchaseToken = body['purchaseToken'] as String?;
        plus = true;
        return _json({'account': account()});
      case ('POST', '/v1/files'):
        return _json({
          'file': {'name': 'files/f${calls('/v1/files').length}'},
        });
      case ('POST', '/v1/note' || '/v1/extract' || '/v1/write'):
        if (mode == 'daily_limit') {
          notesToday = notesPerDay;
          return _error(
            429,
            'daily_limit',
            "You've made today's 3 notes.",
            retry: 3600,
          );
        }
        if (mode == 'shared_limit') {
          return _error(
            429,
            'shared_limit',
            "Commonplace has used today's free AI time.",
            retry: 7200,
          );
        }
        if (mode == 'signed_out') {
          sessionValid = false;
          return _error(401, 'signed_out', 'Sign in again.');
        }
        if (mode == 'busy') {
          return _error(503, 'busy', 'Gemini is busy.', retry: 60);
        }
        if (path == '/v1/note') {
          notesToday++;
          return _json({
            'extraction': {
              'transcript':
                  'Salt the pasta water until it tastes like the sea.',
              'on_screen_text': ['Salt it hard'],
              'visual_notes': '',
              'language': 'en',
              'creator_handle': 'cook.with.ana',
            },
            'note': {
              'title': 'Salt pasta water like the sea',
              'summary': 'One habit for better pasta.',
              'key_points': [
                {
                  'text': 'Salt the water until it tastes like the sea.',
                  'highlight': 'tastes like the sea',
                },
              ],
              'actions': ['Taste the water'],
              'topic': 'Cooking',
              'tags': ['pasta'],
            },
          });
        }
        if (path == '/v1/extract') {
          notesToday++;
          return _json({
            'extraction': {
              'transcript':
                  'Salt the pasta water until it tastes like the sea.',
              'on_screen_text': ['Salt it hard'],
              'visual_notes': '',
              'language': 'en',
              'creator_handle': 'cook.with.ana',
            },
            'ticket': 'ticket-1',
          });
        }
        final body = jsonDecode(request.body) as Map<String, Object?>;
        if (body['ticket'] == null && body['rewrite'] != true) notesToday++;
        return _json({
          'note': {
            'title': 'Salt pasta water like the sea',
            'summary': 'One habit for better pasta.',
            'key_points': [
              {
                'text': 'Salt the water until it tastes like the sea.',
                'highlight': 'tastes like the sea',
              },
            ],
            'actions': ['Taste the water'],
            'topic': 'Cooking',
            'tags': ['pasta'],
          },
        });
    }
    return _error(404, 'not_found', 'No such endpoint.');
  });

  static http.Response _json(Map<String, Object?> body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );

  static http.Response _error(
    int status,
    String code,
    String message, {
    int? retry,
  }) => http.Response(
    jsonEncode({
      'error': {'code': code, 'message': message, 'retryAfter': ?retry},
    }),
    status,
    headers: {'content-type': 'application/json'},
  );
}
