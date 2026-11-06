import 'dart:convert';
import 'dart:io';

import 'package:commonplace/data/repositories/account_repository.dart';
import 'package:commonplace/data/services/billing.dart';
import 'package:commonplace/data/services/commonplace_api.dart';
import 'package:commonplace/data/services/google_auth.dart';
import 'package:commonplace/data/services/local_stores.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryKeyValueStore implements KeyValueStore {
  final values = <String, Object>{};

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  String? getString(String key) => values[key] as String?;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<void> setString(String key, String? value) async =>
      value == null ? values.remove(key) : values[key] = value;
}

/// A [SecretStore] backed by flutter_secure_storage's in-memory test mode.
SecretStore memorySecretStore([Map<String, String> initial = const {}]) {
  FlutterSecureStorage.setMockInitialValues(Map.of(initial));
  return SecretStore();
}

/// Builds a Gemini `generateContent` response carrying [json] as text.
http.Response geminiJson(Map<String, Object?> json) => http.Response(
  jsonEncode({
    'candidates': [
      {
        'content': {
          'role': 'model',
          'parts': [
            {'text': jsonEncode(json)},
          ],
        },
        'finishReason': 'STOP',
      },
    ],
    'modelVersion': 'gemini-3.8-flash',
    'usageMetadata': {
      'promptTokenCount': 6000,
      'candidatesTokenCount': 800,
      'thoughtsTokenCount': 200,
      'totalTokenCount': 7000,
    },
  }),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response geminiError(int code, String status, String message) =>
    http.Response(
      jsonEncode({
        'error': {'code': code, 'status': status, 'message': message},
      }),
      code,
      headers: {'content-type': 'application/json'},
    );

/// Answers extract and distill calls with fixed, realistic content.
MockClient fakeGemini({
  void Function(http.Request request)? onRequest,
  http.Response Function(http.Request request)? override,
}) => MockClient((request) async {
  onRequest?.call(request);
  if (override != null) return override(request);
  final body = request.body;
  final read = <String, Object?>{
    'transcript': 'Three SEO tips nobody tells you. Write your title like the exact question people type into Google.',
    'on_screen_text': [
      '3 SEO tips nobody tells you',
      '1. Title = the question people search',
    ],
    'visual_notes': '',
    'language': 'en',
    'creator_handle': '@seo.with.sam',
  };
  final note = <String, Object?>{
    'title': 'Write titles like the question people search',
    'summary': 'Three small SEO habits that help posts get found.',
    'key_points': [
      {
        'text':
            'Phrase the title as the exact question people type into Google.',
        'highlight': 'exact question people type',
      },
      {
        'text':
            'Answer in the first hundred words so it can become the snippet.',
        'highlight': 'not actually in the sentence',
      },
    ],
    'actions': ['Rewrite one old title as a question'],
    'topic': 'SEO',
    'tags': ['Titles', 'snippets'],
  };
  // One request asks for both: what was read and the note.
  if (body.contains('on_screen_text') && body.contains('key_points')) {
    return geminiJson({...read, ...note});
  }
  return geminiJson(body.contains('on_screen_text') ? read : note);
});

/// A temp file with [bytes] bytes, deleted after the test.
Future<File> tempFile(String name, int bytes) async {
  final dir = await Directory.systemTemp.createTemp('commonplace_test');
  final f = File('${dir.path}${Platform.pathSeparator}$name');
  await f.writeAsBytes(List<int>.generate(bytes, (i) => i % 256));
  return f;
}

/// The personal edition's account: no server, never signed in.
AccountRepository inertAccount() => AccountRepository(
  api: CommonplaceApi(
    httpClient: MockClient((_) async => http.Response('', 500)),
    baseUri: null,
    readSession: () async => null,
  ),
  secrets: SecretStore(),
  google: DevGoogleAuth(),
  billing: FakeBilling(),
);
