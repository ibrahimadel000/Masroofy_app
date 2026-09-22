import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/app.dart';
import 'package:mizaan/firebase_options.dart';
import 'package:mizaan/data/services/database_service.dart';
import 'package:mizaan/data/services/notification_service.dart';
import 'package:mizaan/data/services/fcm_service.dart';
import 'package:mizaan/core/constants/sms_senders.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }
  await DatabaseService.init();
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('NotificationService init in main error: $e');
  }
  try {
    await initializeDateFormatting('ar', null);
  } catch (e) {
    debugPrint('Date formatting initialization error: $e');
  }
  await SmsSenderRegistry.loadCustomTemplates();
  final prefs = await SharedPreferences.getInstance();
  runApp(MizaanApp(prefs: prefs));

  // Initialize FCM safely after Firebase
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('FCM background handler registration note: $e');
  }

  FcmService().init().catchError((e) {
    debugPrint('FcmService async init note: $e');
  });
}
