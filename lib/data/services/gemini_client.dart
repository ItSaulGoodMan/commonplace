import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;

import '../../domain/models/ai.dart';
import 'progress_upload.dart';

// Background-isolate work. These are top-level functions on purpose: a
// closure created inside a GeminiClient method would capture the client (and
// through it the app's settings and UI listeners), which can't be sent to
// another isolate.
String _base64File(String path) => base64Encode(File(path).readAsBytesSync());
String _encodeJson(Map<String, Object?> value) => jsonEncode(value);

/// Thin REST client for the Gemini API (`generateContent` + Files API).
///
/// Only does what the app needs: send media and a prompt, get JSON back.
class GeminiClient {
  GeminiClient({
    required http.Client httpClient,
    required Future<String?> Function() readApiKey,
    required String Function() model,
    Uri? baseUri,
    this.inlineLimitBytes = 14 * 1024 * 1024,
    this.pollInterval = const Duration(seconds: 2),
    this.answerTimeout = const Duration(minutes: 3),
    this.stallTimeout = const Duration(seconds: 60),
  }) : _http = httpClient,
       _readApiKey = readApiKey,
       _model = model,
       _base = baseUri ?? Uri.parse(defaultBaseUrl);

  static const defaultBaseUrl = 'https://generativelanguage.googleapis.com';

  final http.Client _http;
  final Future<String?> Function() _readApiKey;
  final String Function() _model;
  final Uri _base;

  /// Files at or below this size are sent inline; larger ones are uploaded.
  final int inlineLimitBytes;
  final Duration pollInterval;

  /// How long Gemini gets to answer once everything has been sent.
  final Duration answerTimeout;

  /// A send gives up when nothing has gone out for this long.
  final Duration stallTimeout;

  /// Builds a request part for a local media file.
  ///
  /// Small files are base64-encoded inline (on a background isolate);
  /// larger ones go through the resumable Files API.
  Future<Map<String, Object?>> mediaPart(
    File file,
    String mimeType, {
    void Function(ReadUpdate update)? onUpdate,
    Future<void>? cancel,
    void Function(String fileName)? onUploaded,
  }) async {
    final length = await file.length();
    if (length <= inlineLimitBytes) {
      final data = await compute(_base64File, file.path);
      return {
        'inlineData': {'mimeType': mimeType, 'data': data},
      };
    }
    final (uri, name) = await _upload(file, mimeType, length, onUpdate, cancel);
    onUploaded?.call(name);
    return {
      'fileData': {'fileUri': uri, 'mimeType': mimeType},
    };
  }

  /// Checks the key without using any of its quota: asks Gemini about the
  /// chosen model, which needs a valid key but sends no content and is free.
  /// Throws [AiException] saying what's wrong (bad key, model not available
  /// to this key, not offered in this country, no connection).
  Future<void> checkKey() async {
    final key = await _key();
    final uri = _base.replace(path: '/v1beta/models/${_model()}');
    await _send(
      () => _http
          .get(uri, headers: {'x-goog-api-key': key})
          .timeout(const Duration(seconds: 20)),
    );
  }

  /// Sends [parts] and returns the model's JSON answer, constrained to [schema].
  ///
  /// [thinkingLevel] (`MINIMAL`, `LOW`, ...) keeps the model from thinking
  /// longer than a note needs; thinking is billed as output. A model that
  /// refuses the level is asked again without it.
  Future<Map<String, Object?>> generateJson({
    required List<Map<String, Object?>> parts,
    required Map<String, Object?> schema,
    String? thinkingLevel,
    int? maxOutputTokens,
    void Function(ReadUpdate update)? onUpdate,
    void Function(AiUsage usage)? onUsage,
    Future<void>? cancel,
  }) async {
    final key = await _key();
    Map<String, Object?> body({required bool thinking}) => {
      'contents': [
        {'role': 'user', 'parts': parts},
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseJsonSchema': schema,
        'maxOutputTokens': ?maxOutputTokens,
        if (thinking && thinkingLevel != null)
          'thinkingConfig': {'thinkingLevel': thinkingLevel},
      },
    };
    final uri = _base.replace(
      path: '/v1beta/models/${_model()}:generateContent',
    );
    // Streamed, so the screen can show the video going up, and so the
    // time Gemini gets to answer starts only once it has all of it.
    Future<http.Response> post(String encoded) {
      final bytes = utf8.encode(encoded);
      return sendWithProgress(
        _http,
        method: 'POST',
        url: uri,
        headers: {
          'x-goog-api-key': key,
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: chunked(bytes),
        length: bytes.length,
        stall: stallTimeout,
        answer: answerTimeout,
        cancel: cancel,
        onSent: (sent, total) => onUpdate?.call(
          sent < total
              ? ReadUpdate.sending(sent, total)
              : const ReadUpdate.watching(),
        ),
      );
    }

    // Bodies can carry megabytes of base64; encode off the UI isolate.
    final encoded = await compute(_encodeJson, body(thinking: true));
    http.Response response;
    try {
      response = await _send(() => post(encoded));
    } on AiException catch (e) {
      final refusedThinking =
          thinkingLevel != null &&
          (e.detail ?? '').startsWith('400') &&
          (e.detail ?? '').toLowerCase().contains('thinking');
      if (!refusedThinking) rethrow;
      final plain = await compute(_encodeJson, body(thinking: false));
      response = await _send(() => post(plain));
    }

    final decoded = _decodeObject(response.body);
    if (onUsage != null) {
      if (usageOf(decoded, _model()) case final usage?) onUsage(usage);
    }
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      final feedback = decoded['promptFeedback'];
      if (feedback is Map && feedback['blockReason'] != null) {
        throw AiException(
          AiFailure.blocked,
          'blockReason=${feedback['blockReason']}',
        );
      }
      throw AiException(AiFailure.badResponse, 'no candidates');
    }
    final candidate = candidates.first as Map<String, Object?>;
    final finish = candidate['finishReason'];
    if (finish == 'SAFETY' ||
        finish == 'RECITATION' ||
        finish == 'PROHIBITED_CONTENT' ||
        finish == 'BLOCKLIST') {
      throw AiException(AiFailure.blocked, 'finishReason=$finish');
    }
    final content = candidate['content'];
    final rawParts = content is Map ? content['parts'] : null;
    final text = rawParts is List
        ? rawParts
              .whereType<Map<String, Object?>>()
              .where((p) => p['thought'] != true)
              .map((p) => p['text'])
              .whereType<String>()
              .join()
        : '';
    if (text.trim().isEmpty) {
      throw AiException(
        AiFailure.badResponse,
        'empty text, finishReason=$finish',
      );
    }
    return parseJsonObject(text);
  }

  /// Gemini's own token count from a generateContent answer.
  static AiUsage? usageOf(Map<String, Object?> answer, String asked) {
    final meta = answer['usageMetadata'];
    if (meta is! Map) return null;
    int count(String key) => (meta[key] as num?)?.toInt() ?? 0;
    return AiUsage(
      model: (answer['modelVersion'] as String?) ?? asked,
      inputTokens: count('promptTokenCount'),
      outputTokens: count('candidatesTokenCount') + count('thoughtsTokenCount'),
    );
  }

  /// Parses a JSON object out of model text, tolerating code fences.
  static Map<String, Object?> parseJsonObject(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      t = t.replaceFirst(RegExp(r'```\s*$'), '');
    }
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw AiException(AiFailure.badResponse, 'no JSON object');
    }
    try {
      final value = jsonDecode(t.substring(start, end + 1));
      if (value is Map<String, Object?>) return value;
    } on FormatException catch (e) {
      throw AiException(AiFailure.badResponse, e.message);
    }
    throw AiException(AiFailure.badResponse, 'not an object');
  }

  /// Deletes an uploaded file from Google as soon as its note is made,
  /// instead of leaving it there for the 48 hours Google would keep it.
  /// Best effort: a failure here doesn't matter to the note.
  Future<void> deleteFile(String name) async {
    try {
      final key = await _key();
      await _http
          .delete(
            _base.replace(path: '/v1beta/$name'),
            headers: {'x-goog-api-key': key},
          )
          .timeout(const Duration(seconds: 20));
    } on Exception {
      // Google deletes it on its own within 48 hours.
    }
  }

  Future<(String, String)> _upload(
    File file,
    String mimeType,
    int length,
    void Function(ReadUpdate update)? onUpdate,
    Future<void>? cancel,
  ) async {
    final key = await _key();
    final start = await _send(
      () => _http
          .post(
            _base.replace(path: '/upload/v1beta/files'),
            headers: {
              'x-goog-api-key': key,
              'X-Goog-Upload-Protocol': 'resumable',
              'X-Goog-Upload-Command': 'start',
              'X-Goog-Upload-Header-Content-Length': '$length',
              'X-Goog-Upload-Header-Content-Type': mimeType,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'file': {'display_name': 'commonplace-media'},
            }),
          )
          .timeout(const Duration(seconds: 30)),
    );
    final uploadUrl = start.headers['x-goog-upload-url'];
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw AiException(AiFailure.badResponse, 'no upload url');
    }

    onUpdate?.call(ReadUpdate.sending(0, length));
    final uploaded = await _send(
      () => sendWithProgress(
        _http,
        method: 'POST',
        url: Uri.parse(uploadUrl),
        headers: {
          'X-Goog-Upload-Offset': '0',
          'X-Goog-Upload-Command': 'upload, finalize',
        },
        body: file.openRead(),
        length: length,
        stall: stallTimeout,
        answer: const Duration(minutes: 2),
        cancel: cancel,
        onSent: (sent, total) =>
            onUpdate?.call(ReadUpdate.sending(sent, total)),
      ),
    );
    onUpdate?.call(const ReadUpdate.preparing());

    final info = _decodeObject(uploaded.body)['file'];
    if (info is! Map<String, Object?>) {
      throw AiException(AiFailure.badResponse, 'no file in upload');
    }
    var state = info['state'] as String?;
    final name = info['name'] as String?;
    final fileUri = info['uri'] as String?;
    if (name == null || fileUri == null) {
      throw AiException(AiFailure.badResponse, 'upload missing name');
    }

    // Videos need server-side processing before they can be used.
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (state == 'PROCESSING') {
      if (DateTime.now().isAfter(deadline)) {
        throw AiException(AiFailure.overloaded, 'file stuck processing');
      }
      await Future<void>.delayed(pollInterval);
      final poll = await _send(
        () => _http
            .get(
              _base.replace(path: '/v1beta/$name'),
              headers: {'x-goog-api-key': key},
            )
            .timeout(const Duration(seconds: 30)),
      );
      state = _decodeObject(poll.body)['state'] as String?;
    }
    if (state == 'FAILED') {
      unawaited(deleteFile(name));
      throw AiException(AiFailure.badResponse, 'file processing failed');
    }
    return (fileUri, name);
  }

  Future<String> _key() async {
    final key = (await _readApiKey())?.trim();
    if (key == null || key.isEmpty) {
      throw AiException(AiFailure.missingKey);
    }
    return key;
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    final http.Response response;
    try {
      response = await call();
    } on SendTimeout catch (e) {
      throw AiException(
        e.answering ? AiFailure.timedOut : AiFailure.network,
        e.toString(),
      );
    } on TimeoutException {
      throw AiException(AiFailure.network, 'timeout');
    } on SocketException catch (e) {
      throw AiException(AiFailure.network, e.message);
    } on http.ClientException catch (e) {
      throw AiException(AiFailure.network, e.message);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw _errorFor(response);
  }

  static AiException _errorFor(http.Response response) {
    String? status;
    String? message;
    try {
      final error = (jsonDecode(response.body) as Map)['error'];
      if (error is Map) {
        status = error['status'] as String?;
        message = error['message'] as String?;
      }
    } catch (_) {
      // Not JSON; fall back to the status code.
    }
    final detail = '${response.statusCode} ${status ?? ''} ${message ?? ''}'
        .trim();
    final lower = (message ?? '').toLowerCase();

    final failure = switch (response.statusCode) {
      401 || 403 => AiFailure.invalidKey,
      400 when lower.contains('api key') => AiFailure.invalidKey,
      400 when status == 'FAILED_PRECONDITION' => AiFailure.unavailableHere,
      404 => AiFailure.modelUnavailable,
      413 => AiFailure.tooLarge,
      400 when lower.contains('too large') || lower.contains('exceeds') =>
        AiFailure.tooLarge,
      429 => AiFailure.rateLimited,
      500 || 502 || 503 || 504 => AiFailure.overloaded,
      _ => AiFailure.badResponse,
    };
    return AiException(failure, detail);
  }

  static Map<String, Object?> _decodeObject(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map<String, Object?>) return value;
    } on FormatException {
      // Handled below.
    }
    throw AiException(AiFailure.badResponse, 'response was not JSON');
  }
}
