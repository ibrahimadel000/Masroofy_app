import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/data/repositories/auth_repository.dart';
import 'package:mizaan/data/services/biometric_service.dart';
import 'package:mizaan/features/auth/cubit/auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;
  final BiometricService biometricService;
  final SharedPreferences prefs;

  static const String keyBiometricEnabled = 'biometricEnabled';

  AuthCubit({
    required this.authRepository,
    required this.biometricService,
    required this.prefs,
  }) : super(AuthInitial());

  bool get isBiometricEnabled => prefs.getBool(keyBiometricEnabled) ?? false;

  Future<void> setBiometricEnabled(bool enabled) async {
    await prefs.setBool(keyBiometricEnabled, enabled);
  }

  Future<void> checkAuthStatus() async {
    final user = authRepository.currentUser;
    if (user != null) {
      if (isBiometricEnabled) {
        emit(BiometricRequired(user));
      } else {
        emit(Authenticated(user));
      }
    } else {
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
      final user = credential.user!;
      emit(Authenticated(user));
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
      final user = credential.user!;
      emit(Authenticated(user, isFirstLogin: true));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    final user = authRepository.currentUser;
    if (user == null) {
      emit(Unauthenticated());
      return false;
    }

    final success = await biometricService.authenticate(
      localizedReason: 'يرجى تأكيد بصمتك لفتح تطبيق ميزان',
    );

    if (success) {
      emit(Authenticated(user));
      return true;
    }
    return false;
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
    await authRepository.signOut();
    emit(Unauthenticated());
  }
}
