import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models/ai.dart';

/// Why [sendWithProgress] gave up before an answer came.
class SendTimeout implements Exception {
  SendTimeout.stalled(this.sent, this.total, this.after) : answering = false;
  SendTimeout.noAnswer(this.sent, this.total, this.after) : answering = true;

  final int sent;
  final int total;
  final Duration after;

  /// Everything had gone out; the other side just didn't answer.
  final bool answering;

  @override
  String toString() => answering
      ? 'sent ${megabytes(total)} MB, then no answer for ${after.inSeconds} s'
      : 'sending stopped at ${megabytes(sent)} of ${megabytes(total)} MB: '
            'nothing went out for ${after.inSeconds} s';
}

/// "7.8" for 7.8 MB.
String megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

/// [bytes] as a stream of 64 KB chunks, produced only as fast as they are
/// sent.
Stream<List<int>> chunked(Uint8List bytes, {int size = 64 * 1024}) async* {
  for (var i = 0; i < bytes.length; i += size) {
    yield Uint8List.sublistView(
      bytes,
      i,
      i + size < bytes.length ? i + size : bytes.length,
    );
  }
}

/// Sends [body] and reports how much of it has gone out.
///
/// One deadline for the whole request ran out on slow phone connections
/// while the video was still going up, and then looked like Gemini not
/// answering. This gives up only when nothing has gone out for [stall], or
/// when everything is out and no answer has come for [answer].
Future<http.Response> sendWithProgress(
  http.Client client, {
  required String method,
  required Uri url,
  required Map<String, String> headers,
  required Stream<List<int>> body,
  required int length,
  void Function(int sent, int total)? onSent,
  Duration stall = const Duration(seconds: 60),
  Duration answer = const Duration(minutes: 3),
  Duration tick = const Duration(seconds: 1),
  Future<void>? cancel,
}) async {
  final abort = Completer<void>();
  final gaveUp = Completer<http.Response>();
  var sent = 0;
  var lastMove = DateTime.now();
  DateTime? allSentAt;

  final counted = body.map((chunk) {
    sent += chunk.length;
    lastMove = DateTime.now();
    if (sent >= length) allSentAt ??= lastMove;
    onSent?.call(sent, length);
    return chunk;
  });
  final request = _BodyRequest(method, url, counted, abort.future)
    ..headers.addAll(headers)
    ..contentLength = length;

  void giveUp(Exception reason) {
    if (abort.isCompleted) return;
    abort.complete();
    gaveUp.completeError(reason);
  }

  // The owner tapped Stop: drop the connection, send no more.
  unawaited(cancel?.then((_) => giveUp(const WorkStopped())));

  final watchdog = Timer.periodic(tick, (_) {
    final now = DateTime.now();
    final done = allSentAt;
    if (done == null && now.difference(lastMove) > stall) {
      giveUp(SendTimeout.stalled(sent, length, stall));
    } else if (done != null && now.difference(done) > answer) {
      giveUp(SendTimeout.noAnswer(sent, length, answer));
    }
  });
  try {
    // Not every client can abort (the test one can't), so don't wait on it.
    return await Future.any([
      client.send(request).then(http.Response.fromStream),
      gaveUp.future,
    ]);
  } finally {
    watchdog.cancel();
    if (!abort.isCompleted) abort.complete();
  }
}

/// A request whose body is read only as the client sends it, so counting
/// what has been read counts what has gone out.
class _BodyRequest extends http.BaseRequest with http.Abortable {
  _BodyRequest(super.method, super.url, this._body, this.abortTrigger);

  final Stream<List<int>> _body;

  @override
  final Future<void> abortTrigger;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_body);
  }
}
