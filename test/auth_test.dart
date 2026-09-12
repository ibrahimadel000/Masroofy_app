import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/app.dart';
import 'package:mizaan/core/utils/validators.dart';
import 'package:mizaan/data/repositories/auth_repository.dart';
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
  });
}
