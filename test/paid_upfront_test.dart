import 'package:flutter_test/flutter_test.dart';
import 'package:scan_sign_send/core/services/iap_service.dart';

void main() {
  test('builds sold at \$9.99 upfront keep full access', () {
    for (final v in ['1', '7', '8', '9', ' 9 ']) {
      expect(isPaidUpfrontBuild(v), isTrue, reason: v);
    }
  });

  test('free-era builds, sandbox and missing versions do not', () {
    for (final v in ['10', '11', '1.0', '1.0.1', '', null]) {
      expect(isPaidUpfrontBuild(v), isFalse, reason: '$v');
    }
  });
}
