import 'models/ai.dart';

/// Gemini's paid-tier prices in US dollars per million tokens (standard,
/// not batch), from ai.google.dev/gemini-api/docs/pricing, November 2026.
/// Thinking is billed as output. Video, images, audio and text cost the
/// same per token on these models.
///
/// A free-tier key (no billing on its project) is charged nothing; these
/// are what the same note would cost on a paid key.
class GeminiPrice {
  const GeminiPrice(this.inputPerMillion, this.outputPerMillion);

  final double inputPerMillion;
  final double outputPerMillion;

  /// Dollars per million tokens is micro-dollars per token.
  int microUsd(AiUsage usage) =>
      (usage.inputTokens * inputPerMillion +
              usage.outputTokens * outputPerMillion)
          .round();

  /// The price for [model] on [day], or null for a model not listed here.
  /// [model] is what Gemini reports (`gemini-3.8-flash`) or the alias asked
  /// for (`gemini-flash-latest`).
  static GeminiPrice? of(String model, DateTime day) {
    final m = model.replaceFirst('models/', '');
    if (m.startsWith('gemini-3.5-flash-lite') ||
        m == 'gemini-flash-lite-latest') {
      return const GeminiPrice(0.30, 2.50);
    }
    if (m.startsWith('gemini-3.8-flash') || m == 'gemini-flash-latest') {
      // Doubles on 1 January 2027.
      return day.isBefore(DateTime(2027))
          ? const GeminiPrice(0.75, 3.75)
          : const GeminiPrice(1.50, 7.50);
    }
    return null;
  }

  /// "Gemini 3.8 Flash" for `gemini-3.8-flash-001`.
  static String displayName(String model) {
    final m = model.replaceFirst('models/', '');
    if (m == 'gemini-flash-latest') return 'Gemini Flash';
    if (m == 'gemini-flash-lite-latest') return 'Gemini Flash-Lite';
    final match = RegExp(r'^gemini-(\d+(?:\.\d+)?)-(flash-lite|flash|pro)')
        .firstMatch(m);
    if (match == null) return m;
    final family = switch (match[2]) {
      'flash-lite' => 'Flash-Lite',
      'flash' => 'Flash',
      _ => 'Pro',
    };
    return 'Gemini ${match[1]} $family';
  }
}
