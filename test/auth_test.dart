import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/app.dart';
import 'package:mizaan/core/utils/validators.dart';
import 'package:mizaan/data/repositories/auth_repository.dart';
import 'package:mizaan/data/services/biometric_service.dart';
import 'package:mizaan/features/auth/cubit/auth_cubit.dart';
import 'package:mizaan/features/auth/cubit/auth_state.dart';
import 'package:mizaan/features/auth/screens/biometric_gate_screen.dart';
import 'package:mizaan/features/auth/screens/login_screen.dart';

class FakeAuthRepository extends AuthRepository {
  User? _user;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> get authStateChanges => Stream.value(_user);

  @override
  Future<UserCredential> signIn({required String email, required String password}) async {
    throw 'wrong-password';
  }

  @override
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    throw 'email-already-in-use';
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

class FakeBiometricService extends BiometricService {
  final BiometricAuthResult resultToReturn;
  final bool available;

  FakeBiometricService({
    this.resultToReturn = BiometricAuthResult.success,
    this.available = true,
  });

  @override
  Future<bool> isBiometricsAvailable() async => available;

  @override
  Future<bool> hasEnrolledBiometrics() async => available;

  @override
  Future<BiometricAuthResult> authenticateWithDetails({
    String localizedReason = 'يرجى تأكيد هويتك بالبصمة للمتابعة',
  }) async => resultToReturn;
}

void main() {
  group('Validators tests', () {
    test('validateName checks empty and length', () {
      expect(Validators.validateName(''), isNotNull);
      expect(Validators.validateName(' '), isNotNull);
      expect(Validators.validateName('أ'), isNotNull);
      expect(Validators.validateName('أحمد'), isNull);
    });

    test('validateEmail checks email formatting', () {
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail('test@test'), isNotNull);
      expect(Validators.validateEmail('test@example.com'), isNull);
    });

    test('validatePassword checks length', () {
      expect(Validators.validatePassword(''), isNotNull);
      expect(Validators.validatePassword('12345'), isNotNull);
      expect(Validators.validatePassword('123456'), isNull);
    });

    test('validateConfirmPassword checks match', () {
      expect(Validators.validateConfirmPassword('', '123456'), isNotNull);
      expect(Validators.validateConfirmPassword('123457', '123456'), isNotNull);
      expect(Validators.validateConfirmPassword('123456', '123456'), isNull);
    });
  });

  group('AuthRepository Arabic error mapping tests', () {
    test('maps firebase error codes to user-friendly Arabic messages', () {
      expect(
        AuthRepository.mapFirebaseError(
          FirebaseAuthException(code: 'user-not-found'),
        ),
        'البريد الإلكتروني المدخل غير مسجل لدينا',
      );
      expect(
        AuthRepository.mapFirebaseError(
          FirebaseAuthException(code: 'wrong-password'),
        ),
        'كلمة المرور غير صحيحة، يرجى المحاولة مجدداً',
      );
      expect(
        AuthRepository.mapFirebaseError(
          FirebaseAuthException(code: 'email-already-in-use'),
        ),
        'هذا البريد الإلكتروني مسجل بالفعل بحساب آخر',
      );
      expect(
        AuthRepository.mapFirebaseError(
          FirebaseAuthException(code: 'weak-password'),
        ),
        'كلمة المرور ضعيفة جداً، اختر 6 خانات على الأقل',
      );
      expect(
        AuthRepository.mapFirebaseError(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        'تعذر الاتصال بالشبكة، يرجى التأكد من اتصال الإنترنت',
      );
      expect(
        AuthRepository.mapFirebaseError(
          FirebaseAuthException(code: 'operation-not-allowed'),
        ),
        contains('تسجيل الدخول بالبريد غير مفعّل'),
      );
    });
  });

  group('Authentication UI smoke tests', () {
    testWidgets('Renders Login Screen with Arabic labels', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();

      await tester.pumpWidget(
        MizaanApp(prefs: prefs, authRepository: fakeAuth, homeOverride: const LoginScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
      expect(find.text('إنشاء حساب جديد'), findsOneWidget);
    });

    testWidgets('Navigates from Login to Register Screen', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();

      await tester.pumpWidget(
        MizaanApp(prefs: prefs, authRepository: fakeAuth, homeOverride: const LoginScreen()),
      );
      await tester.pumpAndSettle();

      final registerLink = find.text('إنشاء حساب جديد');
      expect(registerLink, findsOneWidget);

      await tester.tap(registerLink);
      await tester.pumpAndSettle();

      expect(find.text('ابدأ مع ميزان 🚀'), findsOneWidget);
      expect(find.text('الاسم الكامل'), findsOneWidget);
      expect(find.text('تأكيد كلمة المرور'), findsOneWidget);
      expect(find.text('إنشاء الحساب'), findsOneWidget);
    });

    testWidgets('Guest login button enters app', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();

      await tester.pumpWidget(
        MizaanApp(prefs: prefs, authRepository: fakeAuth, homeOverride: const LoginScreen()),
      );
      await tester.pumpAndSettle();

      final guestBtn = find.text('دخول تجريبي (وضع أوفلاين) 🚀');
      expect(guestBtn, findsOneWidget);

      await tester.ensureVisible(guestBtn);
      await tester.pumpAndSettle();
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));

      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('Biometric button appears on LoginScreen and triggers auth', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'biometricEnabled': true});
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();
      final fakeBio = FakeBiometricService(resultToReturn: BiometricAuthResult.success);

      await tester.pumpWidget(
        MizaanApp(
          prefs: prefs,
          authRepository: fakeAuth,
          biometricService: fakeBio,
          homeOverride: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final bioBtn = find.text('الدخول بالبصمة');
      expect(bioBtn, findsOneWidget);

      await tester.tap(bioBtn);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));

      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('BiometricGateScreen renders skip button and title', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();
      final fakeBio = FakeBiometricService(resultToReturn: BiometricAuthResult.notEnrolled);

      await tester.pumpWidget(
        MizaanApp(
          prefs: prefs,
          authRepository: fakeAuth,
          biometricService: fakeBio,
          homeOverride: const BiometricGateScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ميزان مقفل للأمان'), findsOneWidget);
      expect(find.text('تأكيد البصمة'), findsOneWidget);
      expect(find.text('تخطي البصمة ومتابعة الدخول 🚀'), findsOneWidget);
    });
  });

  group('AuthCubit Biometric Tests', () {
    test('authenticateWithBiometrics enables biometrics on success', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = AuthCubit(
        authRepository: FakeAuthRepository(),
        biometricService: FakeBiometricService(resultToReturn: BiometricAuthResult.success),
        prefs: prefs,
      );

      final result = await cubit.authenticateWithBiometrics();
      expect(result, BiometricAuthResult.success);
      expect(cubit.isBiometricEnabled, isTrue);
      expect(cubit.state, isA<Authenticated>());
    });

    test('authenticateWithBiometrics handles notEnrolled gracefully', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = AuthCubit(
        authRepository: FakeAuthRepository(),
        biometricService: FakeBiometricService(resultToReturn: BiometricAuthResult.notEnrolled),
        prefs: prefs,
      );

      final result = await cubit.authenticateWithBiometrics();
      expect(result, BiometricAuthResult.notEnrolled);
      expect(cubit.isBiometricEnabled, isFalse);
      expect(cubit.state, isA<AuthInitial>());
    });
  });
}
