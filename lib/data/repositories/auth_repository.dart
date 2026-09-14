import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth? _customAuth;

  AuthRepository({FirebaseAuth? firebaseAuth}) : _customAuth = firebaseAuth;

  FirebaseAuth get _firebaseAuth => _customAuth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null && name.trim().isNotEmpty) {
        await credential.user!.updateDisplayName(name.trim());
        await credential.user!.reload();
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw mapFirebaseError(e);
    } catch (e) {
      throw 'حدث خطأ غير متوقع أثناء إنشاء الحساب';
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw mapFirebaseError(e);
    } catch (e) {
      throw 'حدث خطأ غير متوقع أثناء تسجيل الدخول';
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw mapFirebaseError(e);
    } catch (e) {
      throw 'فشل إرسال بريد استعادة كلمة المرور';
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _firebaseAuth.signInAnonymously();
    } catch (_) {
      return null;
    }
  }

  static String mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'البريد الإلكتروني المدخل غير مسجل لدينا';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة، يرجى المحاولة مجدداً';
      case 'invalid-credential':
        return 'بيانات تسجيل الدخول غير صحيحة';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجل بالفعل بحساب آخر';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً، اختر 6 خانات على الأقل';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صالحة';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب، تواصل مع الدعم';
      case 'too-many-requests':
        return 'محاولات كثيرة خاطئة، يرجى الانتظار قليلاً ثم المحاولة';
      case 'network-request-failed':
        return 'تعذر الاتصال بالشبكة، يرجى التأكد من اتصال الإنترنت';
      case 'operation-not-allowed':
        return 'تسجيل الدخول بالبريد غير مفعّل في لوحة تحكم Firebase Console (Authentication > Sign-in method)';
      case 'channel-error':
        return 'يرجى ملء جميع الحقول المطلوبة بشكل صحيح';
      default:
        return e.message ?? 'حدث خطأ في عملية المصادقة';
    }
  }
}
