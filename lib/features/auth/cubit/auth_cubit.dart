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

  bool get isBiometricEnabled =>
      prefs.getBool(_biometricKey) ?? prefs.getBool(keyBiometricEnabled) ?? false;
  bool get isGuestLoggedIn => prefs.getBool(keyGuestLoggedIn) ?? false;

  Future<void> setBiometricEnabled(bool enabled) async {
    await prefs.setBool(_biometricKey, enabled);
    await prefs.setBool(keyBiometricEnabled, enabled);
  }

  Future<void> checkAuthStatus() async {
    final user = authRepository.currentUser;
    if (user != null) {
      await DatabaseService.switchUser(user.uid);
      if (isBiometricEnabled) {
        emit(BiometricRequired(user));
      } else {
        emit(Authenticated(user));
      }
    } else if (isGuestLoggedIn) {
      await DatabaseService.switchUser('guest');
      if (isBiometricEnabled) {
        emit(const BiometricRequired(null));
      } else {
        emit(const Authenticated(null, isGuest: true));
      }
    } else {
      await DatabaseService.switchUser('guest');
      emit(Unauthenticated());
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(Authenticating());
    try {
      final credential = await authRepository.signIn(
        email: email,
        password: password,
      );
      await prefs.setBool(keyGuestLoggedIn, false);
      if (credential.user != null) {
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
      await prefs.setBool(keyGuestLoggedIn, false);
      if (credential.user != null) {
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

  Future<BiometricAuthResult> authenticateWithBiometrics() async {
    final result = await biometricService.authenticateWithDetails(
      localizedReason: 'يرجى تأكيد بصمتك لفتح تطبيق ميزان',
    );

    if (result == BiometricAuthResult.success) {
      await setBiometricEnabled(true);
      final user = authRepository.currentUser;
      if (user == null) {
        await prefs.setBool(keyGuestLoggedIn, true);
      }
      emit(Authenticated(user, isGuest: user == null));
    }

    return result;
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await authRepository.sendPasswordResetEmail(email);
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signOut() async {
    emit(Authenticating());
    await prefs.setBool(keyGuestLoggedIn, false);
    await authRepository.signOut();
    await DatabaseService.switchUser('guest');
    emit(Unauthenticated());
  }
}
