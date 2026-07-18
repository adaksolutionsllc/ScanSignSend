import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../db/app_database.dart';
import 'profile_repository.dart';

const kProductId = 'com.scansignsend.fullaccess';

final iapServiceProvider = Provider<IapService>((ref) {
  final svc = IapService(ref.watch(profileRepositoryProvider));
  ref.onDispose(svc.dispose);
  return svc;
});

/// True when the user has purchased full access.
final isPurchasedProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(profileRepositoryProvider)
      .watch()
      .map((p) => p.isPurchased);
});

class IapService {
  IapService(this._profileRepo) {
    _init();
  }

  final ProfileRepository _profileRepo;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  void _init() {
    _sub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _sub?.cancel(),
    );
  }

  Future<bool> get isAvailable => InAppPurchase.instance.isAvailable();

  /// Fetch the product from the store and initiate a purchase.
  Future<void> buy() async {
    final response = await InAppPurchase.instance
        .queryProductDetails({kProductId});
    if (response.productDetails.isEmpty) {
      throw Exception('Product not found in store');
    }
    final product = response.productDetails.first;
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  /// Restore previous purchases (required by App Store guidelines).
  Future<void> restore() async {
    await InAppPurchase.instance.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.productID != kProductId) continue;
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        _profileRepo.update(
          const UserProfileCompanion(isPurchased: Value(true)),
        );
        if (p.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(p);
        }
      }
    }
  }

  void dispose() => _sub?.cancel();
}
