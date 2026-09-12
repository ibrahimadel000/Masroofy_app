import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/app.dart';
import 'package:mizaan/core/theme/theme_cubit.dart';
import 'package:mizaan/data/repositories/auth_repository.dart';
import 'package:mizaan/features/onboarding/screens/intro_screen.dart';
import 'package:mizaan/features/splash/screens/splash_screen.dart';

class FakeThemeAuthRepository extends AuthRepository {
  @override
  Stream<User?> get authStateChanges => Stream.value(null);

  @override
  User? get currentUser => null;
}

void main() {
  group('ThemeCubit tests', () {
    test('Defaults to system and switches/persists correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final cubit = ThemeCubit(prefs: prefs);
      expect(cubit.state, ThemeMode.system);

      await cubit.setThemeMode(ThemeMode.dark);
      expect(cubit.state, ThemeMode.dark);
      expect(prefs.getString(ThemeCubit.keyThemeMode), 'dark');

      await cubit.setThemeMode(ThemeMode.light);
      expect(cubit.state, ThemeMode.light);
      expect(prefs.getString(ThemeCubit.keyThemeMode), 'light');
    });

    test('Loads existing saved theme mode from preferences', () async {
      SharedPreferences.setMockInitialValues({ThemeCubit.keyThemeMode: 'dark'});
      final prefs = await SharedPreferences.getInstance();

      final cubit = ThemeCubit(prefs: prefs);
      expect(cubit.state, ThemeMode.dark);
    });
  });

  group('Splash Screen tests', () {
    testWidgets('Renders splash screen and shows app title', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'introSeen': true});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(prefs: prefs),
        ),
      );

      expect(find.text('ميزان'), findsOneWidget);
      expect(find.text('مجمع المحافظ وتتبع المصاريف'), findsOneWidget);

      // Advance animation
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));
    });
  });

  group('Intro Screen tests', () {
    testWidgets('Renders onboarding slides and handles skip', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'introSeen': false});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MizaanApp(
          prefs: prefs,
          authRepository: FakeThemeAuthRepository(),
          homeOverride: IntroScreen(prefs: prefs),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محافظك مشتتة؟'), findsOneWidget);
      expect(find.text('تخطي'), findsOneWidget);
      expect(find.text('التالي'), findsOneWidget);

      // Tap skip
      await tester.tap(find.text('تخطي'));
      await tester.pumpAndSettle();

      expect(prefs.getBool('introSeen'), true);
    });
  });
}
