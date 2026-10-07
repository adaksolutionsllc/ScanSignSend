// Android 15 draws apps edge to edge, under the gesture / 3-button navigation
// bar. A bottom button that ignores the inset ends up behind the bar and can't
// be tapped — it happened on the signature screen's "Use This Signature".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/utils/l10n_ext.dart';
import 'package:scan_sign_send/features/signature/presentation/signature_capture_screen.dart';
import 'package:scan_sign_send/shared/widgets/paywall_screen.dart';

const _navBar = 48.0;

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(bottom: _navBar * 3);
  tester.view.viewPadding = const FakeViewPadding(bottom: _navBar * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: kLocalizationsDelegates,
        supportedLocales: kSupportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pump();
}

void _expectAboveNavBar(WidgetTester tester, Finder button) {
  final screenHeight = tester.view.physicalSize.height / 3;
  final r = tester.getRect(button);
  expect(
    r.bottom,
    lessThanOrEqualTo(screenHeight - _navBar),
    reason: 'button bottom ${r.bottom} is under the navigation bar',
  );
}

void main() {
  testWidgets('signature screen keeps its button above the nav bar', (
    tester,
  ) async {
    await _pump(tester, const SignatureCaptureScreen(docId: 1, fieldId: 1));
    _expectAboveNavBar(tester, find.byType(FilledButton));
  });

  testWidgets('paywall keeps its buy button above the nav bar', (tester) async {
    await _pump(tester, const PaywallScreen());
    final scroll = find.byType(Scrollable).first;
    await tester.drag(scroll, const Offset(0, -3000));
    await tester.pump();
    _expectAboveNavBar(tester, find.byType(FilledButton).last);
  });
}
