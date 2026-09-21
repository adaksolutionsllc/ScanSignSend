import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

class BiometricService {
  final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck && isSupported;
  }

  /// [reason] is shown by the OS in its own biometric sheet, so it must be
  /// localized by the caller — this service has no BuildContext.
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
