import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/export_prompts.dart' as exporter;

void main() {
  test('the server makes notes with exactly the app\'s prompts', () {
    final onServer = jsonDecode(
      File('server/src/prompts.json').readAsStringSync(),
    );
    expect(
      onServer,
      jsonDecode(jsonEncode(exporter.promptsJson())),
      reason: 'Prompts changed in lib/domain/prompts.dart. Run `dart run tool/export_prompts.dart`.',
    );
  });
}
