import 'package:flutter/foundation.dart';

import '../../domain/models/ai.dart';
import '../services/gemini_client.dart';
import 'settings_repository.dart';

/// Answers "does my Gemini key work?" for real, without using any quota.
class KeyCheck extends ChangeNotifier {
  KeyCheck({required GeminiClient gemini, required SettingsRepository settings})
    : _gemini = gemini,
      _settings = settings;

  final GeminiClient _gemini;
  final SettingsRepository _settings;

  bool _running = false;
  bool get running => _running;

  /// Checks the saved key with the chosen model. Null means it works.
  Future<Problem?> run() async {
    if (_running) return _settings.keyProblem;
    _running = true;
    notifyListeners();
    Problem? problem;
    try {
      await _gemini.checkKey();
    } on AiException catch (e) {
      problem = Problem(
        DateTime.now(),
        e.message ?? e.failure.message,
        e.detail,
      );
    } finally {
      _running = false;
    }
    await _settings.recordKeyCheck(problem);
    notifyListeners();
    return problem;
  }
}
