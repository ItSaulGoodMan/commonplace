import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'progress_upload.dart';

/// An error the Commonplace server answered with, or a network failure
/// (`code == 'network'`).
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.status, this.retryAfter});

  /// `signed_out`, `daily_limit`, `shared_limit`, `busy`, `blocked`,
  /// `too_large`, `bad_request`, `not_found`, `purchase_invalid`, `server`,
  /// or `network`.
  final String code;
  final String message;
  final int? status;
  final Duration? retryAfter;

  @override
  String toString() => 'ApiException($code, $status: $message)';
}

/// The signed-in account as the server sees it.
@immutable
class AccountInfo {
  const AccountInfo({
    required this.email,
    required this.name,
    required this.isPlus,
    required this.plusUntil,
    required this.notesToday,
    required this.notesPerDay,
    required this.freeNotesPerDay,
    required this.plusNotesPerDay,
    required this.resetsAt,
    required this.accountRef,
  });

  factory AccountInfo.fromJson(Map<String, Object?> json) {
    DateTime? time(Object? ms) =>
        ms is num ? DateTime.fromMillisecondsSinceEpoch(ms.toInt()) : null;
    int n(Object? v) => v is num ? v.toInt() : 0;
    return AccountInfo(
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      isPlus: json['plan'] == 'plus',
      plusUntil: time(json['plusUntil']),
      notesToday: n(json['notesToday']),
      notesPerDay: n(json['notesPerDay']),
      freeNotesPerDay: n(json['freeNotesPerDay']),
      plusNotesPerDay: n(json['plusNotesPerDay']),
      resetsAt: time(json['resetsAt']) ?? DateTime.now(),
      accountRef: json['accountRef'] as String? ?? '',
    );
  }

  final String email;
  final String? name;
  final bool isPlus;
  final DateTime? plusUntil;
  final int notesToday;
  final int notesPerDay;
  final int freeNotesPerDay;
  final int plusNotesPerDay;

  /// When today's count starts again (midnight UTC).
  final DateTime resetsAt;

  /// Opaque id attached to Play purchases so they belong to this account.
  final String accountRef;

  int get notesLeft =>
      notesPerDay - notesToday < 0 ? 0 : notesPerDay - notesToday;
}

/// REST client for the Commonplace server (`server/` in this repo).
class CommonplaceApi {
  CommonplaceApi({
    required http.Client httpClient,
    required Uri? baseUri,
    required Future<String?> Function() readSession,
  }) : _http = httpClient,
       _base = baseUri,
       _readSession = readSession;

  final http.Client _http;
  final Uri? _base;
  final Future<String?> Function() _readSession;

  bool get isConfigured => _base != null;

  /// Trades a Google ID token for a Commonplace session.
  Future<(String, AccountInfo)> signIn(String idToken) async {
    final json = await _json('POST', '/v1/session', body: {'idToken': idToken});
    return (
      json['session']! as String,
      AccountInfo.fromJson(json['account']! as Map<String, Object?>),
    );
  }

  Future<AccountInfo> me() async => AccountInfo.fromJson(
    (await _json('GET', '/v1/me'))['account']! as Map<String, Object?>,
  );

  /// Streams a video or image to the server; returns its file name there.
  Future<String> upload(
    String path,
    String mimeType, {
    void Function(int sent, int total)? onSent,
    Future<void>? cancel,
  }) async {
    final file = File(path);
    final length = await file.length();
    final headers = {
      ...await _auth(),
      'Content-Type': mimeType,
      'X-File-Name': path.split(Platform.pathSeparator).last,
    };
    final http.Response response;
    try {
      // No overall deadline: it gives up when the upload stops moving.
      response = await _send(
        () => sendWithProgress(
          _http,
          method: 'POST',
          url: _uri('/v1/files'),
          headers: headers,
          body: file.openRead(),
          length: length,
          answer: const Duration(minutes: 3),
          onSent: onSent,
          cancel: cancel,
        ),
        const Duration(hours: 1),
      );
    } on SendTimeout catch (e) {
      throw ApiException('network', e.toString());
    }
    final json = _decode(response);
    return ((json['file']! as Map<String, Object?>)['name'])! as String;
  }

  /// One request: the server has Gemini watch the uploaded files once and
  /// returns what it read and the note.
  Future<(Map<String, Object?>, Map<String, Object?>)> note(
    List<String> fileNames, {
    String? caption,
    String? language,
  }) async {
    final json = await _json(
      'POST',
      '/v1/note',
      body: {'files': fileNames, 'caption': ?caption, 'language': ?language},
      timeout: const Duration(minutes: 5),
    );
    return (
      json['extraction']! as Map<String, Object?>,
      json['note']! as Map<String, Object?>,
    );
  }

  /// The first AI step on uploaded files. The ticket makes [write] free.
  Future<(Map<String, Object?>, String)> extract(List<String> fileNames) async {
    final json = await _json(
      'POST',
      '/v1/extract',
      body: {'files': fileNames},
      timeout: const Duration(minutes: 5),
    );
    return (
      json['extraction']! as Map<String, Object?>,
      json['ticket']! as String,
    );
  }

  Future<Map<String, Object?>> write({
    required String material,
    String? language,
    String? ticket,
    bool rewrite = false,
  }) async {
    final json = await _json(
      'POST',
      '/v1/write',
      body: {
        'material': material,
        'language': ?language,
        'ticket': ?ticket,
        if (rewrite) 'rewrite': true,
      },
      timeout: const Duration(minutes: 3),
    );
    return json['note']! as Map<String, Object?>;
  }

  /// Hands a Google Play purchase to the server to check and unlock Plus.
  Future<AccountInfo> verifyPlus({
    required String productId,
    required String purchaseToken,
  }) async {
    final json = await _json(
      'POST',
      '/v1/plus',
      body: {'productId': productId, 'purchaseToken': purchaseToken},
    );
    return AccountInfo.fromJson(json['account']! as Map<String, Object?>);
  }

  Future<void> deleteAccount() async {
    await _json('DELETE', '/v1/me');
  }

  Uri _uri(String path) {
    final base = _base;
    if (base == null) {
      throw const ApiException(
        'server',
        "This build isn't connected to its server.",
      );
    }
    return base.replace(
      path: '${base.path.replaceAll(RegExp(r'/$'), '')}$path',
    );
  }

  Future<Map<String, String>> _auth() async {
    final session = await _readSession();
    return session == null ? {} : {'Authorization': 'Bearer $session'};
  }

  Future<Map<String, Object?>> _json(
    String method,
    String path, {
    Map<String, Object?>? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = _uri(path);
    final headers = {
      ...await _auth(),
      if (body != null) 'Content-Type': 'application/json; charset=utf-8',
    };
    final response = await _send(() {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      return _http.send(request).then(http.Response.fromStream);
    }, timeout);
    return _decode(response);
  }

  Future<http.Response> _send(
    Future<http.Response> Function() send,
    Duration timeout,
  ) async {
    try {
      return await send().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'network',
        'The server took too long to answer.',
      );
    } on SocketException catch (e) {
      throw ApiException('network', e.message);
    } on http.ClientException catch (e) {
      throw ApiException('network', e.message);
    }
  }

  static Map<String, Object?> _decode(http.Response response) {
    Map<String, Object?>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, Object?>) json = decoded;
    } on FormatException {
      json = null;
    }
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        json != null) {
      return json;
    }
    final error = json?['error'];
    if (error is Map<String, Object?>) {
      final retry = error['retryAfter'];
      throw ApiException(
        error['code'] as String? ?? 'server',
        error['message'] as String? ?? 'Something went wrong.',
        status: response.statusCode,
        retryAfter: retry is num
            ? Duration(milliseconds: (retry * 1000).round())
            : null,
      );
    }
    throw ApiException(
      response.statusCode >= 500 ? 'busy' : 'server',
      'The server answered ${response.statusCode}.',
      status: response.statusCode,
    );
  }
}
