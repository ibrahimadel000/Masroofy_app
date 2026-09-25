import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/data/repositories/auth_repository.dart';
import 'package:mizaan/data/services/biometric_service.dart';
import 'package:mizaan/data/services/database_service.dart';
import 'package:mizaan/features/auth/cubit/auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;
  final BiometricService biometricService;
  final SharedPreferences prefs;

  static const String keyBiometricEnabled = 'biometricEnabled';
  static const String keyGuestLoggedIn = 'guestLoggedIn';

  AuthCubit({
    required this.authRepository,
    required this.biometricService,
    required this.prefs,
  }) : super(AuthInitial());

  String get _biometricKey {
    final uid = authRepository.currentUser?.uid;
    if (uid != null) {
      return '${uid}_$keyBiometricEnabled';
    }
    if (isGuestLoggedIn) {
      return 'guest_$keyBiometricEnabled';
    }
    return keyBiometricEnabled;
  }

  bool get isBiometricEnabled => prefs.getBool(_biometricKey) ?? false;

  bool get canQuickLoginWithBiometrics {
    final user = authRepository.currentUser;
    if (user == null) return false;
    return prefs.getBool('${user.uid}_$keyBiometricEnabled') ?? false;
  }

  bool get isGuestLoggedIn => prefs.getBool(keyGuestLoggedIn) ?? false;

  Future<void> setBiometricEnabled(bool enabled) async {
    await prefs.setBool(_biometricKey, enabled);
  }

  Future<void> checkAuthStatus() async {
    final user = authRepository.currentUser;
    if (user != null) {
      final biometricEnabledForUser = isBiometricEnabled;
      if (biometricEnabledForUser) {
        await DatabaseService.switchUser(user.uid);
        emit(BiometricRequired(user, isGuest: false));
      } else {
        // Firebase persists sessions by default. Without an app lock, a cold
        // start must require the password instead of silently reopening data.
        await authRepository.signOut();
        await DatabaseService.switchUser('guest');
        emit(Unauthenticated());
      }
    } else if (isGuestLoggedIn) {
      if (isBiometricEnabled) {
        await DatabaseService.switchUser('guest');
        emit(const BiometricRequired(null, isGuest: true));
      } else {
        // An unprotected local session must not survive an app restart.
        await prefs.setBool(keyGuestLoggedIn, false);
        await DatabaseService.switchUser('guest');
        emit(Unauthenticated());
      }
    } else {
      await DatabaseService.switchUser('guest');
      emit(Unauthenticated());
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    emit(Authenticating());
    try {
      final credential = await authRepository.signIn(
        email: email,
        password: password,
      );
      final wasGuest = isGuestLoggedIn;
      await prefs.setBool(keyGuestLoggedIn, false);
      if (credential.user != null) {
        if (wasGuest) {
          await DatabaseService.migrateGuestDataToUser(credential.user!.uid);
        }
        await DatabaseService.switchUser(credential.user!.uid);
      }
      emit(Authenticated(credential.user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    emit(Authenticating());
    try {
      final credential = await authRepository.signUp(
        name: name,
        email: email,
        password: password,
      );
      final wasGuest = isGuestLoggedIn;
      await prefs.setBool(keyGuestLoggedIn, false);
      if (credential.user != null) {
        if (wasGuest) {
          await DatabaseService.migrateGuestDataToUser(credential.user!.uid);
        }
        await DatabaseService.switchUser(credential.user!.uid);
      }
      emit(Authenticated(credential.user, isFirstLogin: true));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> continueAsGuest() async {
    emit(Authenticating());
    await prefs.setBool(keyGuestLoggedIn, true);
    await DatabaseService.switchUser('guest');
    emit(const Authenticated(null, isGuest: true));
  }

  Future<void> lockSession() async {
    if (state is BiometricRequired || state is Unauthenticated) return;

    final user = authRepository.currentUser;
    final guest = isGuestLoggedIn;
    if (isBiometricEnabled) {
      if (user != null) {
        emit(BiometricRequired(user, isGuest: false));
      } else if (guest) {
        emit(const BiometricRequired(null, isGuest: true));
      }
      return;
    }

    // No biometric lock means no persistent session after leaving the app.
    await fullSignOut();
  }

  Future<BiometricAuthResult> authenticateWithBiometrics() async {
    final result = await biometricService.authenticateWithDetails(
      localizedReason: 'يرجى تأكيد بصمتك لفتح تطبيق ميزان',
    );

    if (result == BiometricAuthResult.success) {
      final user = authRepository.currentUser;
      final guest = isGuestLoggedIn;
      if (user != null) {
        await DatabaseService.switchUser(user.uid);
        emit(Authenticated(user, isGuest: false));
      } else if (guest) {
        await DatabaseService.switchUser('guest');
        emit(const Authenticated(null, isGuest: true));
      } else {
        // There is no active session to unlock. Biometrics are not a
        // replacement for Firebase credentials after a real sign-out.
        emit(Unauthenticated());
      }
    }

    return result;
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      await authRepository.sendPasswordResetEmail(email.trim().toLowerCase());
      return true;
    } catch (e) {
      emit(AuthError(e.toString()));
      return false;
    }
  }

  /// Locks the UI while retaining the Firebase session for biometric quick login.
  /// If biometrics are disabled, this becomes a full sign-out.
  Future<void> signOut() async {
    if (canQuickLoginWithBiometrics) {
      emit(Unauthenticated());
      return;
    }
    await fullSignOut();
  }

  Future<void> fullSignOut() async {
    emit(Authenticating());
    await prefs.setBool(keyGuestLoggedIn, false);
    await authRepository.signOut();
    await DatabaseService.switchUser('guest');
    emit(Unauthenticated());
  }

  Future<void> resetLocalData() async {
    emit(Authenticating());
    await DatabaseService.resetGuestData();
    await prefs.setBool(keyGuestLoggedIn, false);
    await DatabaseService.switchUser('guest');
    emit(Unauthenticated());
  }
}
