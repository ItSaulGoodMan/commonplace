import 'package:commonplace/data/services/exchange_rates.dart';
import 'package:commonplace/data/services/gemini_client.dart';
import 'package:commonplace/domain/gemini_prices.dart';
import 'package:commonplace/domain/models/ai.dart';
import 'package:commonplace/ui/core/ai_cost.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const usage = AiUsage(
    model: 'gemini-3.8-flash',
    inputTokens: 6000,
    outputTokens: 1000,
  );

  group('prices', () {
    test('Flash, and its price rise on 1 January 2027', () {
      final now = GeminiPrice.of('gemini-3.8-flash', DateTime(2026, 11, 6))!;
      // 6000 x $0.75 + 1000 x $3.75 per million.
      expect(now.microUsd(usage), 8250);
      final later = GeminiPrice.of('gemini-3.8-flash', DateTime(2027, 1, 1))!;
      expect(later.microUsd(usage), 16500);
    });

    test('Flash-Lite, and the aliases the app asks for', () {
      final lite = GeminiPrice.of(
        'gemini-3.5-flash-lite',
        DateTime(2026, 11, 6),
      )!;
      expect(lite.microUsd(usage), 6000 * 0.30 + 1000 * 2.50);
      expect(
        GeminiPrice.of('gemini-flash-lite-latest', DateTime(2026)),
        isNotNull,
      );
      expect(
        GeminiPrice.of(
          'models/gemini-flash-latest',
          DateTime(2026),
        )!.inputPerMillion,
        0.75,
      );
    });

    test('an unknown model has no made-up price', () {
      expect(GeminiPrice.of('gemini-9-ultra', DateTime(2026)), isNull);
    });

    test('names people can read', () {
      expect(
        GeminiPrice.displayName('gemini-3.8-flash-001'),
        'Gemini 3.8 Flash',
      );
      expect(
        GeminiPrice.displayName('gemini-3.5-flash-lite'),
        'Gemini 3.5 Flash-Lite',
      );
      expect(GeminiPrice.displayName('gemini-flash-latest'), 'Gemini Flash');
    });
  });

  test("Gemini's own count: thinking is billed as output", () {
    final read = GeminiClient.usageOf({
      'modelVersion': 'gemini-3.8-flash',
      'usageMetadata': {
        'promptTokenCount': 4500,
        'candidatesTokenCount': 700,
        'thoughtsTokenCount': 120,
      },
    }, 'gemini-flash-latest')!;
    expect(read.model, 'gemini-3.8-flash');
    expect(read.inputTokens, 4500);
    expect(read.outputTokens, 820);
    expect(
      GeminiClient.usageOf({}, 'gemini-flash-latest'),
      isNull,
      reason: 'no usageMetadata, nothing recorded',
    );
  });

  test('euros at the ECB rate', () {
    expect(AiCostText.euros(8250, 1.1165), '€0.0074');
    expect(AiCostText.euros(250000, 1.1165), '€0.224');
    expect(AiCostText.euros(3000000, 1.1165), '€2.69');
    expect(AiCostText.euros(0, 1.1165), '€0');
    expect(AiCostText.tokens(16500), '16,500');
  });

  test("reads the ECB's daily file", () {
    const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<gesmes:Envelope xmlns:gesmes="http://www.gesmes.org/xml/2002-08-01">
  <Cube>
    <Cube time='2026-11-06'>
      <Cube currency='USD' rate='1.1165'/>
      <Cube currency='JPY' rate='171.42'/>
    </Cube>
  </Cube>
</gesmes:Envelope>''';
    final rate = EcbRates.parse(xml)!;
    expect(rate.usdPerEur, 1.1165);
    expect(rate.day, DateTime(2026, 11, 6));
    expect(EcbRates.parse('<html>maintenance</html>'), isNull);
  });
}
