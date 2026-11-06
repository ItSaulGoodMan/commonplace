import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Commonplace Plus as Google Play sells it.
@immutable
class PlusOffer {
  const PlusOffer({required this.productId, required this.price, this.raw});

  final String productId;

  /// Formatted by Play in the buyer's currency, e.g. "€2.99".
  final String price;

  /// The plugin's own product object, needed to buy.
  final Object? raw;
}

/// A purchase that has to be checked by the server, then completed.
@immutable
class PlusPurchase {
  const PlusPurchase({
    required this.productId,
    required this.token,
    required this.complete,
  });

  final String productId;
  final String token;

  /// Acknowledges the purchase with Play. Call only after the server
  /// accepted it; unacknowledged purchases are refunded after three days.
  final Future<void> Function() complete;
}

abstract interface class Billing {
  /// Purchases to check: new ones, restored ones, and ones that were
  /// interrupted last time.
  Stream<PlusPurchase> get purchases;

  /// Failures and cancellations Play reported, phrased for people.
  Stream<String> get problems;

  /// Null when Play billing isn't available on this device.
  Future<PlusOffer?> offer(String productId);

  /// [accountRef] ties the purchase to the Commonplace account.
  Future<void> buy(PlusOffer offer, {required String accountRef});

  Future<void> restore();
}

/// Google Play Billing through the official in_app_purchase plugin.
class PlayBilling implements Billing {
  PlayBilling([InAppPurchase? iap]) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final _problems = StreamController<String>.broadcast();

  @override
  Stream<String> get problems => _problems.stream;

  @override
  late final Stream<PlusPurchase> purchases = _iap.purchaseStream
      .expand((list) => list)
      .where((p) {
        if (p.status == PurchaseStatus.error) {
          _problems.add(
            p.error?.message ?? "Google Play couldn't complete the purchase.",
          );
        }
        return p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored;
      })
      .map(
        (p) => PlusPurchase(
          productId: p.productID,
          token: p.verificationData.serverVerificationData,
          complete: () async {
            if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          },
        ),
      )
      .asBroadcastStream();

  @override
  Future<PlusOffer?> offer(String productId) async {
    if (!await _iap.isAvailable()) return null;
    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isEmpty) return null;
    final details = response.productDetails.first;
    return PlusOffer(productId: details.id, price: details.price, raw: details);
  }

  @override
  Future<void> buy(PlusOffer offer, {required String accountRef}) async {
    final details = offer.raw;
    if (details is! ProductDetails) return;
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: details,
        applicationUserName: accountRef,
      ),
    );
  }

  @override
  Future<void> restore() => _iap.restorePurchases();
}

/// Debug builds against the local server only (DEV_FAKES): buying succeeds
/// at once with a token the local server's fake Play check accepts.
class FakeBilling implements Billing {
  final _purchases = StreamController<PlusPurchase>.broadcast();
  final _problems = StreamController<String>.broadcast();
  String? _lastToken;

  @override
  Stream<PlusPurchase> get purchases => _purchases.stream;

  @override
  Stream<String> get problems => _problems.stream;

  @override
  Future<PlusOffer?> offer(String productId) async =>
      PlusOffer(productId: productId, price: r'$2.99');

  @override
  Future<void> buy(PlusOffer offer, {required String accountRef}) async {
    final token = 'fake-$accountRef-${Random().nextInt(1 << 31)}';
    _lastToken = token;
    _purchases.add(
      PlusPurchase(
        productId: offer.productId,
        token: token,
        complete: () async {},
      ),
    );
  }

  @override
  Future<void> restore() async {
    final token = _lastToken;
    if (token == null) {
      _problems.add('There is no purchase to restore.');
      return;
    }
    _purchases.add(
      PlusPurchase(
        productId: 'commonplace_plus',
        token: token,
        complete: () async {},
      ),
    );
  }
}
