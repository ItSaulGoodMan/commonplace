import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/local_stores.dart';

/// A Gemini model the owner can choose, with a plain description.
class GeminiModelOption {
  const GeminiModelOption(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;
}

/// Something that went wrong, kept so Settings can say exactly what.
@immutable
class Problem {
  const Problem(this.at, this.message, this.detail);

  final DateTime at;

  /// For people: what happened and what to do.
  final String message;

  /// Technical: what the service answered (status, error text). Never a key.
  final String? detail;
}

/// App settings. Notifies listeners on every change.
class SettingsRepository extends ChangeNotifier {
  SettingsRepository({
    required KeyValueStore prefs,
    required SecretStore secrets,
  }) : _prefs = prefs,
       _secrets = secrets;

  final KeyValueStore _prefs;
  final SecretStore _secrets;

  static const models = [
    GeminiModelOption(
      'gemini-flash-latest',
      'Gemini Flash',
      'Best notes. Always the newest Flash model.',
    ),
    GeminiModelOption(
      'gemini-flash-lite-latest',
      'Gemini Flash-Lite',
      'Faster, with more room in the free daily limit.',
    ),
  ];

  /// Languages offered for notes. `null` means "same as the reel".
  static const noteLanguages = <String?>[
    null,
    'English',
    'Serbian',
    'German',
    'Italian',
    'Spanish',
    'French',
    'Portuguese',
  ];

  bool _hasGeminiKey = false;
  bool get hasGeminiKey => _hasGeminiKey;

  /// Loads values that need async work. Call once at startup.
  Future<void> load() async {
    _hasGeminiKey = ((await _secrets.readGeminiKey()) ?? '').isNotEmpty;
  }

  Future<String?> readGeminiKey() => _secrets.readGeminiKey();

  Future<void> setGeminiKey(String? key) async {
    await _secrets.writeGeminiKey(key);
    _hasGeminiKey = key != null && key.trim().isNotEmpty;
    await _prefs.setString('key_checked_at', null);
    await _prefs.setString('key_problem', null);
    notifyListeners();
  }

  String get geminiModel {
    final saved = _prefs.getString('gemini_model');
    return models.any((m) => m.id == saved) ? saved! : models.first.id;
  }

  Future<void> setGeminiModel(String id) async {
    await _prefs.setString('gemini_model', id);
    notifyListeners();
  }

  String? get noteLanguage => _prefs.getString('note_language');

  Future<void> setNoteLanguage(String? language) async {
    await _prefs.setString('note_language', language);
    notifyListeners();
  }

  ThemeMode get themeMode => switch (_prefs.getString('theme_mode')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  /// Keep the video file after the note is made (off by default to save space).
  bool get keepMedia => _prefs.getBool('keep_media') ?? false;

  Future<void> setKeepMedia(bool value) async {
    await _prefs.setBool('keep_media', value);
    notifyListeners();
  }

  // --- Status: what worked and what didn't, for Settings ---------------------

  Problem? _readProblem(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      return Problem(
        DateTime.parse(json['at']! as String),
        json['message']! as String,
        json['detail'] as String?,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _writeProblem(String key, Problem? p) => _prefs.setString(
    key,
    p == null
        ? null
        : jsonEncode({
            'at': p.at.toIso8601String(),
            'message': p.message,
            'detail': p.detail,
          }),
  );

  /// The last time making a note went wrong.
  Problem? get lastProblem => _readProblem('last_problem');

  /// When a note was last made.
  DateTime? get lastSuccessAt =>
      DateTime.tryParse(_prefs.getString('last_success_at') ?? '');

  Future<void> recordProblem(String message, String? detail) async {
    await _writeProblem(
      'last_problem',
      Problem(DateTime.now(), message, detail),
    );
    notifyListeners();
  }

  Future<void> recordSuccess() async {
    await _prefs.setString('last_success_at', DateTime.now().toIso8601String());
    notifyListeners();
  }

  /// The result of the last key check: a problem, or `ok` with no message.
  Problem? get keyProblem => _readProblem('key_problem');
  DateTime? get keyCheckedAt =>
      DateTime.tryParse(_prefs.getString('key_checked_at') ?? '');

  Future<void> recordKeyCheck(Problem? problem) async {
    await _writeProblem('key_problem', problem);
    await _prefs.setString('key_checked_at', DateTime.now().toIso8601String());
    notifyListeners();
  }

  /// Make a smaller copy of a video before sending it.
  bool get shrinkVideos => _prefs.getBool('shrink_videos') ?? true;

  Future<void> setShrinkVideos(bool on) async {
    await _prefs.setBool('shrink_videos', on);
    notifyListeners();
  }

  /// Whether every reel saved on Instagram becomes a note ("automatic by
  /// save"), or only the ones shared to Commonplace ("just share").
  bool get notesFromSaves => _prefs.getBool('notes_from_saves') ?? true;

  Future<void> setNotesFromSaves(bool on) async {
    await _prefs.setBool('notes_from_saves', on);
    notifyListeners();
  }

  /// The ECB's rate on 6 November 2026, until the app has fetched one.
  static const fallbackUsdPerEur = 1.1165;
  static final fallbackRateDay = DateTime(2026, 11, 6);

  /// Dollars per euro, for showing Gemini's dollar prices in euros.
  double get usdPerEur =>
      double.tryParse(_prefs.getString('usd_per_eur') ?? '') ??
      fallbackUsdPerEur;

  /// The day [usdPerEur] is the ECB's rate for.
  DateTime get usdPerEurDay =>
      DateTime.tryParse(_prefs.getString('usd_per_eur_day') ?? '') ??
      fallbackRateDay;

  Future<void> setUsdPerEur(double rate, DateTime day) async {
    await _prefs.setString('usd_per_eur', '$rate');
    await _prefs.setString('usd_per_eur_day', day.toIso8601String());
    notifyListeners();
  }

  /// Fetches today's rate at most once a day.
  Future<void> refreshUsdPerEur(
    Future<({double usdPerEur, DateTime day})?> Function() fetch,
  ) async {
    final checked = DateTime.tryParse(
      _prefs.getString('usd_per_eur_checked') ?? '',
    );
    final now = DateTime.now();
    if (checked != null &&
        now.difference(checked) < const Duration(hours: 12)) {
      return;
    }
    final rate = await fetch();
    if (rate == null) return;
    await _prefs.setString('usd_per_eur_checked', now.toIso8601String());
    await setUsdPerEur(rate.usdPerEur, rate.day);
  }

  bool get askedForNotifications =>
      _prefs.getBool('asked_notifications') ?? false;

  Future<void> setAskedForNotifications() =>
      _prefs.setBool('asked_notifications', true);

  bool get welcomeDone => _prefs.getBool('welcome_done') ?? false;

  Future<void> setWelcomeDone() async {
    await _prefs.setBool('welcome_done', true);
    notifyListeners();
  }
}
