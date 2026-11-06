import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../domain/use_cases/capture.dart';

/// Everything shared into the app from other apps' share sheets.
///
/// Covers both cold starts (the share launched the app) and shares that
/// arrive while it's already open.
class ShareInbox {
  ShareInbox({ReceiveSharingIntent? plugin})
    : _plugin = plugin ?? ReceiveSharingIntent.instance;

  final ReceiveSharingIntent _plugin;
  final _controller = StreamController<Incoming>.broadcast();
  StreamSubscription<List<SharedMediaFile>>? _sub;
  Incoming? _initial;

  Stream<Incoming> get stream => _controller.stream;

  /// Starts listening. Returns the share that launched the app, if any.
  Future<Incoming?> start() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    _sub = _plugin.getMediaStream().listen((files) {
      final incoming = _convert(files);
      if (!incoming.isEmpty) _controller.add(incoming);
    }, onError: (Object e) => debugPrint('Share stream error: $e'));
    try {
      final files = await _plugin.getInitialMedia();
      await _plugin.reset();
      final incoming = _convert(files);
      _initial = incoming.isEmpty ? null : incoming;
    } catch (e) {
      debugPrint('Could not read the initial share: $e');
    }
    return _initial;
  }

  /// Returns the launch share once, then null.
  Incoming? takeInitial() {
    final i = _initial;
    _initial = null;
    return i;
  }

  static Incoming _convert(List<SharedMediaFile> files) {
    final texts = <String>[];
    final paths = <String>[];
    for (final f in files) {
      switch (f.type) {
        case SharedMediaType.text || SharedMediaType.url:
          texts.add(f.path);
        case SharedMediaType.image ||
            SharedMediaType.video ||
            SharedMediaType.file:
          paths.add(f.path);
      }
      final message = f.message;
      if (message != null && message.trim().isNotEmpty) texts.add(message);
    }
    return Incoming(texts: texts, filePaths: paths);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
