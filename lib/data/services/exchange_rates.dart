import 'dart:async';

import 'package:http/http.dart' as http;

/// The euro's reference rate against the dollar, which the European Central
/// Bank publishes each working day around 16:00 CET. A free public file: no
/// key, no account, nothing about the owner is sent.
class EcbRates {
  EcbRates(this._http);

  final http.Client _http;

  static final url = Uri.parse(
    'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml',
  );

  /// Dollars per euro and the day the rate is for, or null when it can't
  /// be had (offline, say).
  Future<({double usdPerEur, DateTime day})?> usdPerEur() async {
    try {
      final response = await _http
          .get(url)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      return parse(response.body);
    } on Exception {
      return null;
    }
  }

  static ({double usdPerEur, DateTime day})? parse(String xml) {
    final time = RegExp(r'''time=['"](\d{4}-\d{2}-\d{2})['"]''')
        .firstMatch(xml);
    final usd = RegExp(r'''currency=['"]USD['"]\s+rate=['"]([0-9.]+)['"]''')
        .firstMatch(xml);
    final day = DateTime.tryParse(time?[1] ?? '');
    final rate = double.tryParse(usd?[1] ?? '');
    if (day == null || rate == null || rate <= 0) return null;
    return (usdPerEur: rate, day: day);
  }
}
