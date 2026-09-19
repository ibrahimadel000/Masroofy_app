import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/features/home/widgets/new_user_hints_card.dart';
import 'package:mizaan/features/home/widgets/app_hints_modal.dart';
import 'package:mizaan/features/onboarding/widgets/permission_education_sheet.dart';
import 'package:mizaan/features/onboarding/screens/intro_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NewUserHintsCard Widget Tests', () {
    testWidgets('Renders quick start guide header, progress, and steps', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewUserHintsCard(
                walletCount: 2,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('دليل البداية السريعة'), findsOneWidget);
      expect(find.text('تفعيل القراءة الذكية للرسائل'), findsOneWidget);
      expect(find.text('السماح بالعمل في الخلفية'), findsOneWidget);
      expect(find.text('ضبط محافظك الإلكترونية'), findsOneWidget);
      expect(find.text('استيراد الرسائل السابقة من هاتفك'), findsOneWidget);
      expect(find.text('تصفح دليل ميزان الكامل 💡'), findsOneWidget);

      // Tap on dismiss
      final dismissButton = find.text('إخفاء الدليل');
      expect(dismissButton, findsOneWidget);
      await tester.tap(dismissButton);
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('dismissed_new_user_guide'), isTrue);
    });

    testWidgets('Card can be collapsed and expanded', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewUserHintsCard(
                walletCount: 0,
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially expanded
      expect(find.text('تفعيل القراءة الذكية للرسائل'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('دليل البداية السريعة'));
      await tester.pumpAndSettle();

      // Steps are now hidden
      expect(find.text('تفعيل القراءة الذكية للرسائل'), findsNothing);

      // Tap header again to expand
      await tester.tap(find.text('دليل البداية السريعة'));
      await tester.pumpAndSettle();

      expect(find.text('تفعيل القراءة الذكية للرسائل'), findsOneWidget);
    });
  });

  group('PermissionEducationSheet Widget Tests', () {
    testWidgets('Renders SMS education sheet with privacy assurances', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PermissionEducationSheet(
              type: PermissionEducationType.sms,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تفعيل القراءة الذكية للرسائل'), findsOneWidget);
      expect(find.text('خصوصية وأمان 100%'), findsOneWidget);
      expect(find.text('بنوك ومحافظ فقط'), findsOneWidget);
      expect(find.text('راحة وتتبع فوري'), findsOneWidget);
      expect(find.text('تفعيل الآن'), findsOneWidget);
      expect(find.text('لاحقاً'), findsOneWidget);
    });

    testWidgets('Renders Battery education sheet with efficiency assurances', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PermissionEducationSheet(
              type: PermissionEducationType.battery,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('السماح بالعمل في الخلفية'), findsOneWidget);
      expect(find.text('استهلاك طاقة شبه معدوم (0.1%)'), findsOneWidget);
      expect(find.text('منع النظام من إيقاف المزامنة'), findsOneWidget);
      expect(find.text('السماح بالخلفية'), findsOneWidget);
      expect(find.text('لاحقاً'), findsOneWidget);
    });
  });

  group('AppHintsModal Widget Tests', () {
    testWidgets('Renders comprehensive guide modal with sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppHintsModal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('دليل وتلميحات ميزان'), findsOneWidget);
      expect(find.text('كيف يعمل ميزان مع الرسائل البنكية؟'), findsOneWidget);
      expect(find.text('الخصوصية والأمان أولاً 🔒'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('العمل في الخلفية وإعدادات الهواتف ⚡'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('العمل في الخلفية وإعدادات الهواتف ⚡'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('فهمت، حسناً 👍'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('فهمت، حسناً 👍'), findsOneWidget);
    });
  });

  group('IntroScreen Privacy Slide Tests', () {
    testWidgets('IntroScreen contains 4 slides including Privacy & Security slide', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: IntroScreen(prefs: prefs),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محافظك مشتتة؟'), findsOneWidget);

      // Slide to next (Slide 2)
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('اجمعها في مكان واحد'), findsOneWidget);

      // Slide to next (Slide 3)
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('وراقب كل ريال تلقائياً'), findsOneWidget);

      // Slide to next (Slide 4 - Privacy)
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('أمانك وخصوصيتك أولويتنا 🔒'), findsOneWidget);
      expect(find.text('خصوصية محلية 100%'), findsOneWidget);
      expect(find.text('بدون رفع لسيرفرات'), findsOneWidget);
      expect(find.text('خفيف على البطارية'), findsOneWidget);
      expect(find.text('ابدأ الآن'), findsOneWidget);
    });
  });
}
