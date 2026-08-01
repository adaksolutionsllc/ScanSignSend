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

  /// The store-localized price string (e.g. "$14.99", "€14,99"), or null if
  /// the store is unavailable / the product can't be fetched. Never hardcode
  /// a price in the UI — App Store guidelines require the live store price.
  Future<String?> localizedPrice() async {
    try {
      if (!await isAvailable) return null;
      final response =
          await InAppPurchase.instance.queryProductDetails({kProductId});
      if (response.productDetails.isEmpty) return null;
      return response.productDetails.first.price;
    } catch (_) {
      return null;
    }
  }

  /// Fetch the product from the store and initiate a purchase.
  Future<void> buy() async {
    if (!await isAvailable) {
      throw Exception('In-app purchases are unavailable on this device.');
    }
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
  ///
  /// Restores are delivered asynchronously through [purchaseStream], so we
  /// arm a one-shot completer, kick off the restore, and wait (with a timeout)
  /// for a matching `restored`/`purchased` event. Returns true if full access
  /// was actually restored, false if nothing was found — so the UI can give
  /// honest feedback instead of always claiming success.
  Future<bool> restore() async {
    if (!await isAvailable) {
      throw Exception('In-app purchases are unavailable on this device.');
    }
    final completer = Completer<bool>();
    _restoreCompleter = completer;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      _restoreCompleter = null;
      rethrow;
    }
    // If no relevant event arrives, treat it as "nothing to restore".
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        _restoreCompleter = null;
        return false;
      },
    );
  }

  Completer<bool>? _restoreCompleter;

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.productID != kProductId) continue;
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        _profileRepo.update(
          const UserProfileCompanion(isPurchased: Value(true)),
        );
        if (!(_restoreCompleter?.isCompleted ?? true)) {
          _restoreCompleter!.complete(true);
          _restoreCompleter = null;
        }
      }
      if (p.status == PurchaseStatus.error &&
          !(_restoreCompleter?.isCompleted ?? true)) {
        _restoreCompleter!.completeError(
          Exception(p.error?.message ?? 'Purchase error'),
        );
        _restoreCompleter = null;
      }
      // Complete pending purchases for every terminal status the store asks us
      // to acknowledge — required on both stores to avoid stuck transactions.
      if (p.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(p);
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    if (!(_restoreCompleter?.isCompleted ?? true)) {
      _restoreCompleter!.complete(false);
    }
    _restoreCompleter = null;
  }
}
