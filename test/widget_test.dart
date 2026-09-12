import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/app.dart';
import 'package:mizaan/data/repositories/auth_repository.dart';
import 'package:mizaan/features/auth/screens/login_screen.dart';

class TestAuthRepository extends AuthRepository {
  @override
  Stream<User?> get authStateChanges => Stream.value(null);

  @override
  User? get currentUser => null;
}

void main() {
  testWidgets('App renders login screen smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MizaanApp(
        prefs: prefs,
        authRepository: TestAuthRepository(),
        homeOverride: const LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsWidgets);
  });
}
