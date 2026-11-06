import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the app running while notes are made (Android `NoteWorkService`):
/// without it, Android freezes the app as soon as you go back to Instagram,
/// halfway through sending a video to the AI.
class BackgroundWork {
  static const _channel = MethodChannel('commonplace/background');

  Future<void> start(String text) => _call('start', {'text': text});

  Future<void> stop() => _call('stop');

  /// Android 13+ asks before an app may show notifications. Without it the
  /// work still runs; only the "Making your note" notice is hidden.
  Future<void> askForNotifications() => _call('askForNotifications');

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on Object catch (e) {
      // Not on Android, or in tests: notes still get made while open.
      debugPrint('Background work ($method): $e');
    }
  }
}
