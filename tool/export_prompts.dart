// Writes the app's prompts to server/src/prompts.json so the server (which
// makes notes for signed-in users) uses exactly the same words.
//
//   dart run tool/export_prompts.dart
//
// test/domain/prompts_sync_test.dart fails if the two drift apart.
import 'dart:convert';
import 'dart:io';

import 'package:commonplace/domain/prompts.dart';

Map<String, Object?> promptsJson() => {
  'extract': Prompts.extract,
  'extractSchema': Prompts.extractSchema,
  'distill': Prompts.distill(material: '{material}', language: '{language}'),
  'distillSameLanguage': 'the same language as the material',
  'distillSchema': Prompts.distillSchema,
  'read': Prompts.read(language: '{language}'),
  'readSameLanguage': 'the same language as the video',
  'readCaption': Prompts.readCaption('{caption}'),
  'readSchema': Prompts.readSchema,
};

void main() {
  File('server/src/prompts.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(promptsJson())}\n',
  );
  stdout.writeln('Wrote server/src/prompts.json');
}
