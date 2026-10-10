import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for an App Store / Play rating after a real success: a finished
/// document that was then shared or saved from the Send screen.
///
/// Rules: never on the first send; first ask from the [firstAskAtSend]th
/// send on; at least [minGap] between asks; at most [maxAsks] asks ever.
/// Purchased and free users are treated the same. There is no "Are you
/// enjoying the app?" pre-prompt — the store's own sheet is shown directly
/// (review gating isn't allowed), and the OS may still decide not to show it.
///
/// State is three numbers in SharedPreferences; nothing leaves the device.
/// Never throws: a failed prompt must not interrupt sending.
class ReviewPromptService {
  ReviewPromptService({InAppReview? review, DateTime Function()? now})
    : _review = review ?? InAppReview.instance,
      _now = now ?? DateTime.now;

  static const firstAskAtSend = 2;
  static const minGap = Duration(days: 60);
  static const maxAsks = 3;

  /// Numeric App Store ID (App Store Connect → App Information → Apple ID).
  /// Android opens the listing for the app's own package name.
  static const appStoreId = '6799269558';

  static const _kSends = 'review_send_count';
  static const _kLastAsked = 'review_last_asked_ms';
  static const _kAsks = 'review_ask_count';

  final InAppReview _review;
  final DateTime Function() _now;

  /// Records one successful send and returns whether this is a moment to ask.
  /// The caller decides whether the screen is fit to show the prompt (not
  /// locked, nothing covering it) and then calls [requestReview].
  Future<bool> recordSend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sends = (prefs.getInt(_kSends) ?? 0) + 1;
      await prefs.setInt(_kSends, sends);
      return _due(prefs, sends);
    } catch (e) {
      debugPrint('Review prompt: send not recorded: $e');
      return false;
    }
  }

  bool _due(SharedPreferences prefs, int sends) {
    if (sends < firstAskAtSend) return false;
    if ((prefs.getInt(_kAsks) ?? 0) >= maxAsks) return false;
    final last = prefs.getInt(_kLastAsked);
    if (last == null) return true;
    final since = _now().difference(DateTime.fromMillisecondsSinceEpoch(last));
    return since >= minGap;
  }

  /// Shows the native rating sheet if the store supports it here, and
  /// records the ask. Returns whether the sheet was requested.
  Future<bool> requestReview() async {
    try {
      if (!await _review.isAvailable()) return false;
      await _review.requestReview();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastAsked, _now().millisecondsSinceEpoch);
      await prefs.setInt(_kAsks, (prefs.getInt(_kAsks) ?? 0) + 1);
      return true;
    } catch (e) {
      debugPrint('Review prompt not shown: $e');
      return false;
    }
  }

  /// Opens the app's store listing (Settings → Rate). Never uses
  /// [InAppReview.requestReview], which the OS may silently ignore.
  /// Returns false if the store couldn't be opened.
  Future<bool> openStoreListing() async {
    try {
      await _review.openStoreListing(appStoreId: appStoreId);
      return true;
    } catch (e) {
      debugPrint('Store listing not opened: $e');
      return false;
    }
  }
}

final reviewPromptServiceProvider = Provider<ReviewPromptService>(
  (ref) => ReviewPromptService(),
);
