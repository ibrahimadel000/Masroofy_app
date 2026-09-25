import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricAuthResult {
  success,
  failed,
  notEnrolled,
  notAvailable,
  lockedOut,
  error,
}

class BiometricService {
  static bool isAuthenticating = false;
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  Future<bool> isBiometricsAvailable() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final biometrics = await _auth.getAvailableBiometrics();
      return isSupported || canCheck || biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasEnrolledBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final biometrics = await _auth.getAvailableBiometrics();
      return canCheck || biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    String localizedReason = 'يرجى تأكيد هويتك بالبصمة للمتابعة',
  }) async {
    final result = await authenticateWithDetails(
      localizedReason: localizedReason,
    );
    return result == BiometricAuthResult.success;
  }

  Future<BiometricAuthResult> authenticateWithDetails({
    String localizedReason = 'يرجى تأكيد هويتك بالبصمة للمتابعة',
  }) async {
    isAuthenticating = true;
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      return authenticated
          ? BiometricAuthResult.success
          : BiometricAuthResult.failed;
    } on PlatformException catch (e) {
      debugPrint(
        'Biometric PlatformException: code=${e.code}, message=${e.message}',
      );
      if (e.code == 'NotEnrolled' || e.code == 'PasscodeNotSet') {
        return BiometricAuthResult.notEnrolled;
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        return BiometricAuthResult.lockedOut;
      } else if (e.code == 'NotAvailable') {
        return BiometricAuthResult.notAvailable;
      }
      return BiometricAuthResult.error;
    } catch (e) {
      debugPrint('Biometric unexpected error: $e');
      return BiometricAuthResult.error;
    } finally {
      isAuthenticating = false;
    }
  }
}
