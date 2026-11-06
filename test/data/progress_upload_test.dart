import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:commonplace/data/services/gemini_client.dart';
import 'package:commonplace/data/services/progress_upload.dart';
import 'package:commonplace/domain/models/ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fakes.dart';

void main() {
  final url = Uri.parse('https://example.test/up');
  const fast = Duration(milliseconds: 20);

  group('sending with progress', () {
    test('reports what has gone out and returns the answer', () async {
      final bytes = Uint8List(200 * 1024);
      final seen = <int>[];
      late http.Request received;
      final response = await sendWithProgress(
        MockClient((r) async {
          received = r;
          return http.Response('ok', 200);
        }),
        method: 'POST',
        url: url,
        headers: {'X-Test': 'yes'},
        body: chunked(bytes),
        length: bytes.length,
        onSent: (sent, total) {
          expect(total, bytes.length);
          seen.add(sent);
        },
      );
      expect(response.body, 'ok');
      expect(received.bodyBytes, hasLength(bytes.length));
      expect(received.headers['X-Test'], 'yes');
      expect(seen, [65536, 131072, 196608, 204800]);
    });

    test('a slow but moving upload is not cut short', () async {
      Stream<List<int>> slowly() async* {
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          yield [1, 2, 3];
        }
      }

      final response = await sendWithProgress(
        MockClient((r) async => http.Response('ok', 200)),
        method: 'POST',
        url: url,
        headers: const {},
        body: slowly(),
        length: 30,
        // Longer than this in total, but never still for anywhere near it.
        stall: const Duration(milliseconds: 500),
        tick: fast,
      );
      expect(response.body, 'ok');
    });

    test('gives up when nothing goes out for a while', () async {
      final body = StreamController<List<int>>()..add(List.filled(1000, 1));
      addTearDown(body.close);
      await expectLater(
        sendWithProgress(
          MockClient((r) async => http.Response('ok', 200)),
          method: 'POST',
          url: url,
          headers: const {},
          body: body.stream,
          length: 5000,
          stall: const Duration(milliseconds: 150),
          tick: fast,
        ),
        throwsA(
          isA<SendTimeout>()
              .having((e) => e.answering, 'answering', false)
              .having((e) => e.sent, 'sent', 1000)
              .having((e) => '$e', 'says why', contains('nothing went out')),
        ),
      );
    });

    test('gives up when all is sent but no answer comes', () async {
      final never = Completer<http.Response>();
      await expectLater(
        sendWithProgress(
          MockClient((r) => never.future),
          method: 'POST',
          url: url,
          headers: const {},
          body: chunked(Uint8List(10)),
          length: 10,
          answer: const Duration(milliseconds: 150),
          tick: fast,
        ),
        throwsA(
          isA<SendTimeout>().having((e) => e.answering, 'answering', true),
        ),
      );
    });
  });

  group('Gemini', () {
    GeminiClient client(http.Client http) => GeminiClient(
      httpClient: http,
      readApiKey: () async => 'AQ.TESTKEY',
      model: () => 'gemini-flash-latest',
      baseUri: Uri.parse('https://example.test'),
      answerTimeout: const Duration(milliseconds: 150),
      stallTimeout: const Duration(milliseconds: 150),
    );

    test('says when it is sending and when Gemini has it all', () async {
      final updates = <ReadStep>[];
      await client(MockClient((r) async => geminiJson({'ok': true})))
          .generateJson(
            parts: [
              {
                'inlineData': {
                  'mimeType': 'video/mp4',
                  'data': base64Encode(Uint8List(300 * 1024)),
                },
              },
            ],
            schema: {'type': 'object'},
            onUpdate: (u) => updates.add(u.step),
          );
      expect(updates.first, ReadStep.sending);
      expect(updates.last, ReadStep.watching);
    });

    test(
      'no answer after sending is a timeout, not a dropped connection',
      () async {
        final never = Completer<http.Response>();
        await expectLater(
          client(MockClient((r) => never.future)).generateJson(
            parts: [
              {'text': 'hello'},
            ],
            schema: {'type': 'object'},
          ),
          throwsA(
            isA<AiException>()
                .having((e) => e.failure, 'failure', AiFailure.timedOut)
                .having((e) => e.detail, 'detail', contains('no answer')),
          ),
        );
      },
    );
  });
}
