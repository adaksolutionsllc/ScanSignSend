import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:scan_sign_send/core/services/review_prompt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReview implements InAppReview {
  bool available = true;
  bool throwOnRequest = false;
  int requests = 0;
  String? listingOpenedFor;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    if (throwOnRequest) throw Exception('store unavailable');
    requests++;
  }

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async => listingOpenedFor = appStoreId;
}

void main() {
  late _FakeReview review;
  late DateTime now;
  late ReviewPromptService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    review = _FakeReview();
    now = DateTime(2026, 1, 1);
    service = ReviewPromptService(review: review, now: () => now);
  });

  /// One send, asking whenever the service says it's due.
  Future<bool> send() async {
    if (!await service.recordSend()) return false;
    return service.requestReview();
  }

  test('the first send never asks', () async {
    expect(await send(), isFalse);
    expect(review.requests, 0);
  });

  test('the second send asks', () async {
    await send();
    expect(await send(), isTrue);
    expect(review.requests, 1);
  });

  test('waits at least 60 days between asks', () async {
    await send();
    await send(); // first ask
    now = now.add(const Duration(days: 59, hours: 23));
    expect(await send(), isFalse);
    now = now.add(const Duration(hours: 1)); // exactly 60 days
    expect(await send(), isTrue);
    expect(review.requests, 2);
  });

  test('asks at most 3 times', () async {
    await send();
    for (var i = 0; i < 3; i++) {
      expect(await send(), isTrue);
      now = now.add(ReviewPromptService.minGap);
    }
    for (var i = 0; i < 3; i++) {
      expect(await send(), isFalse);
      now = now.add(const Duration(days: 365));
    }
    expect(review.requests, 3);
  });

  test('an unavailable store is not counted as an ask', () async {
    review.available = false;
    await send();
    expect(await send(), isFalse);
    review.available = true;
    expect(await send(), isTrue); // next send, no 60-day wait
  });

  test('a store error never throws and is not counted', () async {
    review.throwOnRequest = true;
    await send();
    expect(await send(), isFalse);
    review.throwOnRequest = false;
    expect(await send(), isTrue);
  });

  test('the Rate row opens the listing with the App Store ID', () async {
    expect(await service.openStoreListing(), isTrue);
    expect(review.listingOpenedFor, '6799269558');
    expect(review.requests, 0);
  });
}
