import 'package:intl/intl.dart';

import '../../domain/gemini_prices.dart';
import '../../domain/models/ai.dart';

/// Words for what Gemini used and what it would cost, shared by the note
/// and Settings.
class AiCostText {
  const AiCostText(this.spend, {required this.usdPerEur});

  final AiSpend spend;

  /// Dollars per euro (the ECB's rate).
  final double usdPerEur;

  static final _count = NumberFormat.decimalPattern('en');

  static String tokens(int n) => _count.format(n);

  /// "€0.0071": small amounts keep enough digits to mean something.
  static String euros(int microUsd, double usdPerEur) {
    final eur = microUsd / 1e6 / usdPerEur;
    if (eur == 0) return '€0';
    if (eur < 0.01) return '€${eur.toStringAsFixed(4)}';
    if (eur < 1) return '€${eur.toStringAsFixed(3)}';
    return '€${eur.toStringAsFixed(2)}';
  }

  String get models => spend.models.map(GeminiPrice.displayName).join(', ');

  /// "6,120 tokens in, 850 out"
  String get usage =>
      '${tokens(spend.inputTokens)} tokens in, '
      '${tokens(spend.outputTokens)} out';

  /// "€0.0071 at Google's paid price", or why there is no price.
  String get cost {
    if (spend.unpriced == spend.calls) {
      return "Commonplace doesn't know this model's price";
    }
    final partly = spend.unpriced > 0 ? ' (some answers left out)' : '';
    return "${euros(spend.microUsd, usdPerEur)} at Google's paid price$partly";
  }
}
