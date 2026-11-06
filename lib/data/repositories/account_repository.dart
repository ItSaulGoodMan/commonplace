import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config.dart';
import '../../domain/models/ai.dart';
import '../services/billing.dart';
import '../services/commonplace_api.dart';
import '../services/google_auth.dart';
import '../services/local_stores.dart';

/// The Commonplace account (Play edition): Google sign-in, today's notes,
/// and Commonplace Plus.
class AccountRepository extends ChangeNotifier {
  AccountRepository({
    required CommonplaceApi api,
    required SecretStore secrets,
    required GoogleAuth google,
    required Billing billing,
    DateTime Function()? clock,
  }) : _api = api,
       _secrets = secrets,
       _google = google,
       _billing = billing,
       _now = clock ?? DateTime.now;

  final CommonplaceApi _api;
  final SecretStore _secrets;
  final GoogleAuth _google;
  final Billing _billing;
  final DateTime Function() _now;

  String? _session;
  AccountInfo? _account;
  DateTime? _sharedUntil;
  StreamSubscription<PlusPurchase>? _purchaseSub;
  StreamSubscription<String>? _problemSub;

  bool get isConfigured => _api.isConfigured;
  bool get signedIn => _session != null;
  AccountInfo? get account => _account;

  /// Set while a purchase is being checked with the server.
  bool _verifying = false;
  bool get verifyingPurchase => _verifying;

  /// The last purchase problem, for the Plus screen to show.
  String? _purchaseProblem;
  String? get purchaseProblem => _purchaseProblem;

  /// Why notes can't be made right now, or null.
  AiFailure? get blocked {
    if (!isConfigured) return AiFailure.notConfigured;
    if (!signedIn) return AiFailure.signedOut;
    final now = _now();
    final shared = _sharedUntil;
    if (shared != null && now.isBefore(shared)) return AiFailure.sharedLimit;
    final a = _account;
    if (a != null && a.notesLeft == 0 && now.isBefore(a.resetsAt)) {
      return AiFailure.dailyLimit;
    }
    return null;
  }

  /// When the shared free AI time comes back, if it ran out.
  DateTime? get sharedLimitUntil {
    final s = _sharedUntil;
    return s != null && _now().isBefore(s) ? s : null;
  }

  Future<void> load() async {
    _session = await _secrets.readSession();
    _purchaseSub = _billing.purchases.listen(_onPurchase);
    _problemSub = _billing.problems.listen((message) {
      _purchaseProblem = message;
      notifyListeners();
    });
    if (_session != null) unawaited(refresh());
  }

  Future<String?> readSession() async => _session;

  /// Shows Google's account picker and signs in. False if they backed out.
  Future<bool> signIn() async {
    final token = await _google.idToken();
    if (token == null) return false;
    final (session, account) = await _api.signIn(token);
    await _secrets.writeSession(session);
    _session = session;
    _account = account;
    notifyListeners();
    return true;
  }

  Future<void> signOut() async {
    await _secrets.writeSession(null);
    _session = null;
    _account = null;
    notifyListeners();
    try {
      await _google.signOut();
    } on Object catch (e) {
      debugPrint('Google sign-out: $e');
    }
  }

  /// Deletes the account and everything the server keeps. Notes on this
  /// phone stay. A Play subscription has to be cancelled in Play.
  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    await signOut();
  }

  /// Reloads today's count and the plan from the server.
  Future<void> refresh() async {
    if (_session == null) return;
    try {
      _account = await _api.me();
      notifyListeners();
    } on ApiException catch (e) {
      if (e.code == 'signed_out') await _expired();
      debugPrint('Account refresh: $e');
    }
  }

  /// Called by [CloudNoteAi] when the server says the session is over.
  Future<void> _expired() async {
    await _secrets.writeSession(null);
    _session = null;
    _account = null;
    notifyListeners();
  }

  void _sharedLimitHit(Duration? retryAfter) {
    _sharedUntil = _now().add(retryAfter ?? const Duration(hours: 1));
    notifyListeners();
  }

  void _dailyLimitHit() {
    unawaited(refresh());
  }

  // --- Commonplace Plus ----------------------------------------------------

  Future<PlusOffer?> plusOffer() => _billing.offer(PlayConfig.plusProductId);

  Future<void> buyPlus(PlusOffer offer) async {
    final ref = _account?.accountRef;
    if (ref == null || ref.isEmpty) return;
    _purchaseProblem = null;
    notifyListeners();
    await _billing.buy(offer, accountRef: ref);
  }

  Future<void> restorePlus() async {
    _purchaseProblem = null;
    notifyListeners();
    await _billing.restore();
  }

  Future<void> _onPurchase(PlusPurchase purchase) async {
    if (_session == null) {
      // Bought while signed out (another account on the phone); it's
      // checked after signing in, via "Restore purchase".
      return;
    }
    _verifying = true;
    notifyListeners();
    try {
      _account = await _api.verifyPlus(
        productId: purchase.productId,
        purchaseToken: purchase.token,
      );
      _purchaseProblem = null;
      await purchase.complete();
    } on ApiException catch (e) {
      _purchaseProblem = e.code == 'network'
          ? "Couldn't reach Commonplace to confirm the purchase. It's checked again next time."
          : e.message;
    } finally {
      _verifying = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_purchaseSub?.cancel());
    unawaited(_problemSub?.cancel());
    super.dispose();
  }
}

/// Play edition: notes are made by the Commonplace server.
class CloudNoteAi implements NoteAi {
  CloudNoteAi({
    required CommonplaceApi api,
    required AccountRepository account,
    required String Function(String path) mimeTypeFor,
  }) : _api = api,
       _account = account,
       _mimeTypeFor = mimeTypeFor;

  final CommonplaceApi _api;
  final AccountRepository _account;
  final String Function(String path) _mimeTypeFor;

  @override
  AiFailure? get blocked => _account.blocked;

  @override
  Future<(Extraction, Map<String, Object?>)> read(
    List<String> mediaPaths, {
    String? caption,
    String? language,
    void Function(ReadUpdate update)? onUpdate,
    void Function(AiUsage usage)? onUsage,
    Future<void>? cancel,
  }) => _guard(() async {
    final names = <String>[
      for (final path in mediaPaths)
        await _api.upload(
          path,
          _mimeTypeFor(path),
          onSent: (sent, total) =>
              onUpdate?.call(ReadUpdate.sending(sent, total)),
          cancel: cancel,
        ),
    ];
    onUpdate?.call(const ReadUpdate.watching());
    final (fields, note) = await _api.note(
      names,
      caption: (caption?.trim().isNotEmpty ?? false) ? caption!.trim() : null,
      language: language,
    );
    unawaited(_account.refresh());
    return (Extraction(fields), note);
  });

  @override
  Future<Extraction> extract(
    List<String> mediaPaths, {
    void Function(AiUsage usage)? onUsage,
  }) => _guard(() async {
    final names = <String>[
      for (final path in mediaPaths)
        await _api.upload(path, _mimeTypeFor(path)),
    ];
    final (fields, ticket) = await _api.extract(names);
    return Extraction(fields, ticket: ticket);
  });

  @override
  Future<Map<String, Object?>> write({
    required String material,
    String? language,
    Extraction? from,
    bool rewrite = false,
    void Function(AiUsage usage)? onUsage,
  }) => _guard(() async {
    final note = await _api.write(
      material: material,
      language: language,
      ticket: from?.ticket,
      rewrite: rewrite,
    );
    unawaited(_account.refresh());
    return note;
  });

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      final failure = switch (e.code) {
        'signed_out' => AiFailure.signedOut,
        'daily_limit' => AiFailure.dailyLimit,
        'shared_limit' => AiFailure.sharedLimit,
        'busy' => AiFailure.overloaded,
        'blocked' => AiFailure.blocked,
        'too_large' => AiFailure.tooLarge,
        'network' => AiFailure.network,
        _ => AiFailure.badResponse,
      };
      switch (failure) {
        case AiFailure.signedOut:
          await _account._expired();
        case AiFailure.sharedLimit:
          _account._sharedLimitHit(e.retryAfter);
        case AiFailure.dailyLimit:
          _account._dailyLimitHit();
        default:
          break;
      }
      throw AiException(failure, '${e.code} ${e.status ?? ''}', e.message);
    }
  }
}
