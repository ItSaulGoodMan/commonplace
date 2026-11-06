import 'dart:convert';
import 'dart:isolate';

import 'package:commonplace/data/repositories/gemini_note_ai.dart';
import 'package:commonplace/data/repositories/settings_repository.dart';
import 'package:commonplace/data/services/gemini_client.dart';
import 'package:commonplace/domain/models/ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fakes.dart';

GeminiClient _client(
  http.Client http, {
  String? key = 'AIzaTESTKEY',
  int inlineLimit = 1024,
}) => GeminiClient(
  httpClient: http,
  readApiKey: () async => key,
  model: () => 'gemini-flash-latest',
  baseUri: Uri.parse('https://example.test'),
  inlineLimitBytes: inlineLimit,
  pollInterval: Duration.zero,
);

void main() {
  group('generateJson', () {
    test(
      'sends the documented generateContent shape and parses the answer',
      () async {
        late http.Request sent;
        final client = _client(
          MockClient((request) async {
            sent = request;
            return geminiJson({'ok': true});
          }),
        );

        final result = await client.generateJson(
          parts: [
            {'text': 'hello'},
          ],
          schema: {'type': 'object'},
        );

        expect(result, {'ok': true});
        expect(sent.method, 'POST');
        expect(
          sent.url.toString(),
          'https://example.test/v1beta/models/gemini-flash-latest:generateContent',
        );
        expect(sent.headers['x-goog-api-key'], 'AIzaTESTKEY');
        final body = jsonDecode(sent.body) as Map<String, Object?>;
        expect(body['contents'], [
          {
            'role': 'user',
            'parts': [
              {'text': 'hello'},
            ],
          },
        ]);
        expect(body['generationConfig'], {
          'responseMimeType': 'application/json',
          'responseJsonSchema': {'type': 'object'},
        });
      },
    );

    test('never calls the API without a key', () async {
      var calls = 0;
      final client = _client(
        MockClient((_) async {
          calls++;
          return geminiJson({});
        }),
        key: null,
      );
      await expectLater(
        client.generateJson(parts: const [], schema: const {}),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.missingKey,
          ),
        ),
      );
      expect(calls, 0);
    });

    test('maps HTTP errors to messages people can act on', () async {
      Future<AiFailure> failureFor(http.Response response) async {
        final client = _client(MockClient((_) async => response));
        try {
          await client.generateJson(parts: const [], schema: const {});
        } on AiException catch (e) {
          return e.failure;
        }
        fail('expected an exception');
      }

      expect(
        await failureFor(
          geminiError(429, 'RESOURCE_EXHAUSTED', 'Quota exceeded'),
        ),
        AiFailure.rateLimited,
      );
      expect(
        await failureFor(
          geminiError(
            400,
            'INVALID_ARGUMENT',
            'API key not valid. Please pass a valid API key.',
          ),
        ),
        AiFailure.invalidKey,
      );
      expect(
        await failureFor(
          geminiError(
            400,
            'FAILED_PRECONDITION',
            'User location is not supported',
          ),
        ),
        AiFailure.unavailableHere,
      );
      expect(
        await failureFor(geminiError(503, 'UNAVAILABLE', 'overloaded')),
        AiFailure.overloaded,
      );
      expect(
        await failureFor(geminiError(404, 'NOT_FOUND', 'model not found')),
        AiFailure.modelUnavailable,
      );
      expect(
        await failureFor(http.Response('<html>oops</html>', 502)),
        AiFailure.overloaded,
      );
    });

    test('treats a safety stop as blocked', () async {
      final client = _client(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'candidates': [
                {'finishReason': 'SAFETY'},
              ],
            }),
            200,
          ),
        ),
      );
      await expectLater(
        client.generateJson(parts: const [], schema: const {}),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.blocked,
          ),
        ),
      );
    });

    test('network failures are transient', () async {
      final client = _client(
        MockClient((_) async => throw http.ClientException('offline')),
      );
      try {
        await client.generateJson(parts: const [], schema: const {});
        fail('expected an exception');
      } on AiException catch (e) {
        expect(e.failure, AiFailure.network);
        expect(e.failure.isTransient, isTrue);
      }
    });
  });

  test(
    'background encoding works when the client holds unsendable objects',
    () async {
      // In the app, the key reader reaches the settings repository, which holds
      // UI listeners and stream subscriptions. None of that may leak into the
      // isolate message.
      final unsendable = ReceivePort();
      addTearDown(unsendable.close);
      final file = await tempFile('clip.mp4', 300);
      final client = GeminiClient(
        httpClient: MockClient((_) async => geminiJson({'ok': true})),
        readApiKey: () async => unsendable.hashCode == 0 ? null : 'AIzaTESTKEY',
        model: () => unsendable.hashCode == 0 ? 'x' : 'gemini-flash-latest',
        baseUri: Uri.parse('https://example.test'),
      );
      final part = await client.mediaPart(file, 'video/mp4');
      final result = await client.generateJson(parts: [part], schema: const {});
      expect(result, {'ok': true});
    },
  );

  group('parseJsonObject', () {
    test('tolerates code fences and stray text', () {
      expect(GeminiClient.parseJsonObject('```json\n{"a": 1}\n```'), {'a': 1});
      expect(GeminiClient.parseJsonObject('Sure! {"a": [1]} done'), {
        'a': [1],
      });
    });
  });

  group('mediaPart', () {
    test('sends small files inline as base64', () async {
      final file = await tempFile('small.mp4', 600);
      final client = _client(
        MockClient((_) async => fail('no network call expected')),
      );
      final part = await client.mediaPart(file, 'video/mp4');
      final inline = part['inlineData'] as Map<String, Object?>;
      expect(inline['mimeType'], 'video/mp4');
      expect(base64Decode(inline['data'] as String).length, 600);
    });

    test(
      'uploads large files with the resumable Files API and waits until ACTIVE',
      () async {
        final file = await tempFile('big.mp4', 4096);
        final steps = <String>[];
        final client = _client(
          MockClient((request) async {
            final url = request.url.toString();
            if (url == 'https://example.test/upload/v1beta/files') {
              steps.add('start');
              expect(request.headers['X-Goog-Upload-Protocol'], 'resumable');
              expect(
                request.headers['X-Goog-Upload-Header-Content-Length'],
                '4096',
              );
              expect(
                request.headers['X-Goog-Upload-Header-Content-Type'],
                'video/mp4',
              );
              return http.Response(
                '{}',
                200,
                headers: {
                  'x-goog-upload-url': 'https://example.test/upload-session/1',
                },
              );
            }
            if (url == 'https://example.test/upload-session/1') {
              steps.add('upload');
              expect(
                request.headers['X-Goog-Upload-Command'],
                'upload, finalize',
              );
              expect(request.bodyBytes.length, 4096);
              return http.Response(
                jsonEncode({
                  'file': {
                    'name': 'files/abc',
                    'uri': 'https://example.test/v1beta/files/abc',
                    'state': 'PROCESSING',
                  },
                }),
                200,
              );
            }
            if (url == 'https://example.test/v1beta/files/abc') {
              steps.add('poll');
              return http.Response(
                jsonEncode({'name': 'files/abc', 'state': 'ACTIVE'}),
                200,
              );
            }
            fail('unexpected request to $url');
          }),
        );

        final part = await client.mediaPart(file, 'video/mp4');
        expect(steps, ['start', 'upload', 'poll']);
        expect(part, {
          'fileData': {
            'fileUri': 'https://example.test/v1beta/files/abc',
            'mimeType': 'video/mp4',
          },
        });
      },
    );
  });

  test(
    'a model that refuses the thinking level is asked again without it',
    () async {
      final bodies = <String>[];
      final client = GeminiClient(
        httpClient: MockClient((r) async {
          bodies.add(r.body);
          if (r.body.contains('thinkingConfig')) {
            return geminiError(
              400,
              'INVALID_ARGUMENT',
              'Thinking level MINIMAL is not supported for this model.',
            );
          }
          return geminiJson({'ok': true});
        }),
        readApiKey: () async => 'AIzaTESTKEY0123456789012345678901234',
        model: () => 'gemini-flash-latest',
        baseUri: Uri.parse('https://example.test'),
      );
      final json = await client.generateJson(
        parts: [
          {'text': 'hi'},
        ],
        schema: {'type': 'object'},
        thinkingLevel: 'MINIMAL',
        maxOutputTokens: 2048,
      );
      expect(json, {'ok': true});
      expect(bodies, hasLength(2));
      expect(bodies.first, contains('"thinkingLevel":"MINIMAL"'));
      expect(bodies.last, isNot(contains('thinkingConfig')));
      expect(bodies.last, contains('"maxOutputTokens":2048'));
    },
  );

  group('checking the key (free: no content is sent)', () {
    GeminiClient client(http.Response Function(http.Request) answer) =>
        GeminiClient(
          httpClient: MockClient((r) async => answer(r)),
          readApiKey: () async => 'AIzaTESTKEY0123456789012345678901234',
          model: () => 'gemini-flash-lite-latest',
          baseUri: Uri.parse('https://example.test'),
        );

    test('a working key', () async {
      late http.Request sent;
      await client((r) {
        sent = r;
        return http.Response('{"name":"models/gemini-flash-lite-latest"}', 200);
      }).checkKey();
      expect(sent.method, 'GET');
      expect(sent.url.path, '/v1beta/models/gemini-flash-lite-latest');
      expect(sent.headers['x-goog-api-key'], startsWith('AIza'));
      expect(sent.body, isEmpty);
    });

    Future<AiFailure?> failureFor(http.Response response) async {
      try {
        await client((_) => response).checkKey();
        return null;
      } on AiException catch (e) {
        return e.failure;
      }
    }

    test('says what is wrong', () async {
      expect(
        await failureFor(
          geminiError(
            400,
            'INVALID_ARGUMENT',
            'API key not valid. Please pass a valid API key.',
          ),
        ),
        AiFailure.invalidKey,
      );
      expect(
        await failureFor(
          geminiError(404, 'NOT_FOUND', 'models/x is not found'),
        ),
        AiFailure.modelUnavailable,
      );
      expect(
        await failureFor(
          geminiError(
            400,
            'FAILED_PRECONDITION',
            'User location is not supported for the API use.',
          ),
        ),
        AiFailure.unavailableHere,
      );
    });

    test('no key, no request', () async {
      var calls = 0;
      final noKey = GeminiClient(
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
        readApiKey: () async => null,
        model: () => 'gemini-flash-lite-latest',
        baseUri: Uri.parse('https://example.test'),
      );
      await expectLater(
        noKey.checkKey(),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.missingKey,
          ),
        ),
      );
      expect(calls, 0);
    });
  });

  test('a video sent as a file is deleted from Google once read', () async {
    final file = await tempFile('big.mp4', 4096);
    final calls = <String>[];
    final gemini = _client(
      MockClient((request) async {
        final url = request.url.toString();
        calls.add('${request.method} ${request.url.path}');
        if (url == 'https://example.test/upload/v1beta/files') {
          return http.Response(
            '{}',
            200,
            headers: {
              'x-goog-upload-url': 'https://example.test/upload-session/1',
            },
          );
        }
        if (url == 'https://example.test/upload-session/1') {
          return http.Response(
            jsonEncode({
              'file': {
                'name': 'files/abc',
                'uri': 'https://example.test/v1beta/files/abc',
                'state': 'ACTIVE',
              },
            }),
            200,
          );
        }
        if (request.method == 'DELETE') return http.Response('{}', 200);
        return geminiJson({'transcript': 'hi', 'title': 'A note'});
      }),
    );
    final settings = SettingsRepository(
      prefs: MemoryKeyValueStore(),
      secrets: memorySecretStore({'gemini_api_key': 'AQ.TESTKEY'}),
    );
    await settings.load();
    await GeminiNoteAi(gemini: gemini, settings: settings).read([file.path]);
    await Future<void>.delayed(Duration.zero);
    expect(calls.last, 'DELETE /v1beta/files/abc');
    expect(
      calls.indexWhere((c) => c.contains('generateContent')),
      lessThan(calls.length - 1),
      reason: 'deleted after the answer',
    );
  });
}
