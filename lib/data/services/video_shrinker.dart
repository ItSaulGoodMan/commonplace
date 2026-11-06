import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/models/ai.dart';

/// Makes a smaller copy of a video before it is sent: Android's Media3
/// Transformer, through `VideoShrinker.kt`. Gemini samples one frame a second
/// at low resolution, so a 480p, 5 fps copy reads the same and sends two or
/// three times faster.
class VideoShrinker {
  VideoShrinker({
    MethodChannel channel = const MethodChannel('commonplace/video'),
    this.minBytes = 3 * 1024 * 1024,
    this.pollInterval = const Duration(milliseconds: 500),
  }) : _channel = channel;

  final MethodChannel _channel;

  /// Videos smaller than this are sent as they are.
  final int minBytes;
  final Duration pollInterval;

  /// The path of a smaller copy of [path], or null to send the original
  /// (already small, not on Android, or making the copy didn't work).
  /// Throws [WorkStopped] when [cancel] completes first.
  Future<String?> shrink(
    String path, {
    void Function(double fraction)? onProgress,
    Future<void>? cancel,
  }) async {
    if (!Platform.isAndroid) return null;
    final before = await File(path).length();
    if (before < minBytes) return null;
    final out = '$path.small.mp4';
    var stopped = false;
    unawaited(
      cancel?.then((_) {
        stopped = true;
        _channel.invokeMethod<void>('cancel').ignore();
      }),
    );
    final poll = Timer.periodic(pollInterval, (_) {
      _channel.invokeMethod<int>('progress').then((p) {
        if (p != null && p >= 0) onProgress?.call(p / 100);
      }).ignore();
    });
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('shrink', {
        'input': path,
        'output': out,
      });
      final after = (result?['bytes'] as num?)?.toInt() ?? 0;
      if (after <= 0 || after >= before) {
        await _delete(out);
        return null;
      }
      debugPrint(
        'Video made smaller: $before -> $after bytes, ${result?['summary']}',
      );
      return out;
    } on PlatformException catch (e) {
      if (stopped) throw const WorkStopped();
      debugPrint('Video sent as it is: ${e.code} ${e.message} ${e.details}');
      return null;
    } on MissingPluginException {
      return null;
    } finally {
      poll.cancel();
    }
  }

  static Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}
