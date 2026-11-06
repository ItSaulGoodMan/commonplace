import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:commonplace/data/services/progress_upload.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Over a real socket, "sent" has to follow what the other side has taken,
/// not what went into a buffer, or the screen would say 100% at once and
/// the answer clock would start while the video is still going up.
void main() {
  test('progress follows a slow reader over a real socket', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var received = 0;
    server.listen((request) {
      final done = Completer<void>();
      // ignore: cancel_subscriptions, it ends with the request.
      final sub = request.listen(null, onDone: done.complete);
      sub.onData((chunk) {
        received += chunk.length;
        // A slow reader: a short pause after every chunk.
        sub.pause(Future<void>.delayed(const Duration(milliseconds: 5)));
      });
      unawaited(
        done.future.then((_) {
          request.response
            ..statusCode = 200
            ..write('ok');
          return request.response.close();
        }),
      );
    });

    final client = http.Client();
    addTearDown(client.close);
    final bytes = Uint8List(24 * 1024 * 1024);
    var mostAhead = 0;
    final response = await sendWithProgress(
      client,
      method: 'POST',
      url: Uri.parse('http://127.0.0.1:${server.port}/up'),
      headers: const {},
      body: chunked(bytes),
      length: bytes.length,
      onSent: (sent, _) {
        if (sent - received > mostAhead) mostAhead = sent - received;
      },
    );
    expect(response.body, 'ok');
    expect(received, bytes.length);
    expect(mostAhead, lessThan(4 * 1024 * 1024), reason: 'of 24 MB');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
