import 'dart:async';
import 'dart:io' show Platform;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import 'profile_repository.dart';

const kProductId = 'com.adakventures.scansignsend.fullaccess';

/// The last iOS build sold at $9.99 upfront. From build 10 the app is free
/// with the Full Access unlock; anyone whose first download was build 9 or
/// earlier already paid and keeps full access.
const kLastPaidIosBuild = 9;

/// Whether an App Store `originalAppVersion` (the CFBundleVersion of the
/// user's first download) is from the paid-upfront era.
@visibleForTesting
bool isPaidUpfrontBuild(String? originalAppVersion) {
  final build = int.tryParse(originalAppVersion?.trim() ?? '');
  return build != null && build <= kLastPaidIosBuild;
}

/// Why a store call failed. The service has no BuildContext, so the UI maps
/// this to a translated message (see [IapException.message]).
enum IapFailure { unavailable, productNotFound, purchaseFailed }

class IapException implements Exception {
  const IapException(this.failure);
  final IapFailure failure;
  @override
  String toString() => 'IapException(${failure.name})';
}

final iapServiceProvider = Provider<IapService>((ref) {
  final svc = IapService(ref.watch(profileRepositoryProvider));
  ref.onDispose(svc.dispose);
  return svc;
});

/// True when the user has purchased full access.
final isPurchasedProvider = StreamProvider<bool>((ref) {
  return ref.watch(profileRepositoryProvider).watch().map((p) => p.isPurchased);
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
    if (Platform.isIOS) unawaited(_grantPaidUpfront());
  }

  static const _entitlement = MethodChannel('com.scansignsend/entitlement');
  static const _kInstallChecked = 'paid_upfront_checked';

  /// Gives full access to people who bought the app at $9.99 upfront.
  ///
  /// iOS 16+: Apple's signed AppTransaction says which build they first
  /// downloaded. iOS 15 has no AppTransaction, so the first launch of this
  /// build checks once whether the app was already set up (onboarding done),
  /// which means it was installed while the app was paid. Reinstalling on
  /// iOS 15 loses that; those few buyers can write to support.
  Future<void> _grantPaidUpfront() async {
    try {
      if ((await _profileRepo.getOrCreate()).isPurchased) return;
      final info = await _entitlement.invokeMapMethod<String, Object?>(
        'originalAppVersion',
      );
      var paid = false;
      if (info?['supported'] == true) {
        paid = isPaidUpfrontBuild(info?['version'] as String?);
      } else {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool(_kInstallChecked) ?? false)) {
          // Same key as onboarding_screen.dart.
          paid = prefs.getBool('onboarding_done') ?? false;
          await prefs.setBool(_kInstallChecked, true);
        }
      }
      if (paid) {
        await _profileRepo.update(
          const UserProfileCompanion(isPurchased: Value(true)),
        );
      }
    } catch (e) {
      debugPrint('Paid-upfront check failed: $e');
    }
  }

  Future<bool> get isAvailable => InAppPurchase.instance.isAvailable();

  /// The store-localized price string (e.g. "$14.99", "€14,99"), or null if
  /// the store is unavailable / the product can't be fetched. Never hardcode
  /// a price in the UI — App Store guidelines require the live store price.
  Future<String?> localizedPrice() async {
    try {
      if (!await isAvailable) return null;
      final response = await InAppPurchase.instance.queryProductDetails({
        kProductId,
      });
      if (response.productDetails.isEmpty) return null;
      return response.productDetails.first.price;
    } catch (_) {
      return null;
    }
  }

  /// Fetch the product from the store and initiate a purchase.
  Future<void> buy() async {
    if (!await isAvailable) {
      throw const IapException(IapFailure.unavailable);
    }
    final response = await InAppPurchase.instance.queryProductDetails({
      kProductId,
    });
    if (response.productDetails.isEmpty) {
      throw const IapException(IapFailure.productNotFound);
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
      throw const IapException(IapFailure.unavailable);
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
          const IapException(IapFailure.purchaseFailed),
        );
        _restoreCompleter = null;
      }
      // A cancelled restore is a definite "nothing happened" — resolve it now
      // instead of making the user watch a spinner until the 12s timeout.
      if (p.status == PurchaseStatus.canceled &&
          !(_restoreCompleter?.isCompleted ?? true)) {
        _restoreCompleter!.complete(false);
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
