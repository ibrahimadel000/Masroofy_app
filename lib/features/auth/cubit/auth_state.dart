import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class Unauthenticated extends AuthState {}

class Authenticating extends AuthState {}

class Authenticated extends AuthState {
  final User? user;
  final bool isFirstLogin;
  final bool isGuest;

  const Authenticated(this.user, {this.isFirstLogin = false, this.isGuest = false});

  @override
  List<Object?> get props => [user?.uid, isFirstLogin, isGuest];
}

class BiometricRequired extends AuthState {
  final User? user;

  const BiometricRequired(this.user);

  @override
  List<Object?> get props => [user?.uid];
}

class AuthError extends AuthState {
  final String arMessage;

  const AuthError(this.arMessage);

  @override
  List<Object?> get props => [arMessage];
}
