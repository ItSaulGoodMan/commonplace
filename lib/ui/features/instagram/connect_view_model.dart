import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/instagram_repository.dart';
import '../../../data/services/instagram_api.dart';
import '../../../domain/use_cases/saved_sync.dart';

enum ConnectStep {
  /// The Instagram sign-in page is showing.
  signIn,

  /// Signed in; reading the Saved list.
  loading,

  /// Asking whether recent saves should become notes too.
  choose,

  /// Signed in, but the Saved list couldn't be read.
  failed,

  /// All set; the screen can close.
  done,
}

class ConnectViewModel extends ChangeNotifier {
  ConnectViewModel({
    required InstagramRepository instagram,
    required SavedSync sync,
  }) : _instagram = instagram,
       _sync = sync;

  final InstagramRepository _instagram;
  final SavedSync _sync;

  ConnectStep _step = ConnectStep.signIn;
  ConnectStep get step => _step;

  List<InstagramPost> _latest = const [];
  InstagramFailure? _failure;
  InstagramFailure? get failure => _failure;

  bool _checking = false;
  bool _reconnected = false;

  /// True when this was a sign-in again, not the first connection.
  bool get reconnected => _reconnected;

  Uri get signInUri => _instagram.signInUri;
  Uri get baseUri => _instagram.baseUri;
  String? get username => _instagram.username;

  /// How many recent saves are offered as notes.
  int get offerCount => min(SavedSync.startCount, _latest.length);

  /// Paths where Instagram is still in the middle of signing someone in
  /// (two-step codes, "is this you?" checks). The owner finishes those.
  static final _midSignIn = RegExp(
    r'^/(accounts/login|challenge|auth_platform|accounts/suspended|accounts/disabled)',
  );

  /// Called whenever the web view moves. Picks up the session once the
  /// owner is through Instagram's sign-in.
  Future<void> pageChanged(
    String url,
    Future<String?> Function() userAgent,
  ) async {
    if (_step != ConnectStep.signIn || _checking) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
      return;
    }
    if (_midSignIn.hasMatch(uri.path)) return;
    _checking = true;
    try {
      final signedIn = await _instagram.completeSignIn(
        userAgent: await userAgent() ?? '',
      );
      if (!signedIn) return;
      if (_instagram.baselineDone) {
        // Signing in again: nothing to choose, just catch up.
        _reconnected = true;
        await _sync.afterSignIn();
        _step = ConnectStep.done;
        notifyListeners();
        return;
      }
      _step = ConnectStep.loading;
      notifyListeners();
      await loadLatest();
    } finally {
      _checking = false;
    }
  }

  Future<void> loadLatest() async {
    _step = ConnectStep.loading;
    _failure = null;
    notifyListeners();
    try {
      _latest = await _sync.latest();
      _step = ConnectStep.choose;
    } on InstagramException catch (e) {
      _failure = e.failure;
      _step = ConnectStep.failed;
    }
    notifyListeners();
  }

  /// Finishes: makes notes from the latest saves if [includeRecent].
  Future<void> choose({required bool includeRecent}) async {
    _step = ConnectStep.loading;
    notifyListeners();
    await _sync.startFrom(_latest, count: includeRecent ? offerCount : 0);
    _step = ConnectStep.done;
    notifyListeners();
  }

  /// Leaves without reading the Saved list now; the first check records
  /// where it starts, so old saves don't flood in.
  Future<void> skip() async {
    await _sync.afterSignIn();
    _step = ConnectStep.done;
    notifyListeners();
  }
}
