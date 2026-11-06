import 'package:commonplace/data/repositories/key_check.dart';
import 'package:commonplace/data/repositories/settings_repository.dart';
import 'package:commonplace/data/services/gemini_client.dart';
import 'package:commonplace/ui/core/theme.dart';
import 'package:commonplace/ui/features/settings/gemini_key_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import '../helpers/fakes.dart';

// Made-up keys in the two formats AI Studio hands out.
const newKey = 'AQ.Ab8RN6LtestKey-made_up.0123456789abcdefXYZ';
const oldKey = 'AIzaSyTESTKEY-made_up_0123456789abcdef';

void main() {
  group('reading a pasted key', () {
    test('takes both formats AI Studio gives out', () {
      expect(parseGeminiKey(newKey), newKey);
      expect(parseGeminiKey(oldKey), oldKey);
    });

    test('drops what comes along with a copy', () {
      expect(parseGeminiKey('  $newKey\n'), newKey);
      expect(parseGeminiKey('"$newKey"'), newKey);
      expect(parseGeminiKey('GEMINI_API_KEY=$newKey'), newKey);
      expect(
        parseGeminiKey('AQ.Ab8RN6LtestKey-made_up\n.0123456789abcdefXYZ'),
        newKey,
      );
    });

    test('leaves an unknown long key for Gemini to judge', () {
      const future = 'XY_0123456789abcdefghijklmnopqrstuvwxyz';
      expect(parseGeminiKey(future), future);
    });

    test('says no to things that are not keys', () {
      expect(parseGeminiKey(''), isNull);
      expect(parseGeminiKey('640Q'), isNull);
      expect(parseGeminiKey('https://aistudio.google.com/api-keys'), isNull);
      expect(parseGeminiKey('CommonPlaceKey'), isNull);
    });
  });

  testWidgets('a new "AQ." key is saved and checked with Gemini', (
    tester,
  ) async {
    final settings = SettingsRepository(
      prefs: MemoryKeyValueStore(),
      secrets: memorySecretStore(),
    );
    await settings.load();
    final sent = <http.Request>[];
    final check = KeyCheck(
      settings: settings,
      gemini: GeminiClient(
        httpClient: MockClient((r) async {
          sent.add(r);
          return http.Response('{"name":"models/gemini-flash-latest"}', 200);
        }),
        readApiKey: settings.readGeminiKey,
        model: () => settings.geminiModel,
        baseUri: Uri.parse('https://example.test'),
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: check),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: GeminiKeyField()),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), ' $newKey\n');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.textContaining("doesn't look like"), findsNothing);
    expect(await settings.readGeminiKey(), newKey);
    expect(sent.single.method, 'GET');
    expect(sent.single.headers['x-goog-api-key'], newKey);
    expect(find.textContaining('The key works'), findsOneWidget);
  });
}
