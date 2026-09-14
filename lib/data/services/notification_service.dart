import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;

  static const int lowBalanceNotificationId = 1001;
  static const int dailyReminderNotificationId = 1002;

  static const String alertsChannelId = 'mizaan_alerts';
  static const String alertsChannelName = 'تنبيهات ميزان';
  static const String alertsChannelDesc = 'إشعارات تنبيه الرصيد المنخفض للمحافظ';

  static const String remindersChannelId = 'mizaan_reminders';
  static const String remindersChannelName = 'تذكيرات ميزان';
  static const String remindersChannelDesc = 'تذكير يومي لتسجيل المصروفات';

  static const String transactionsChannelId = 'mizaan_transactions';
  static const String transactionsChannelName = 'حركات المحافظ والرسائل';
  static const String transactionsChannelDesc = 'إشعارات فورية بالعمليات المالية والمشتريات والإيداعات المستلمة';

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Initialize notifications for Android and iOS
  Future<void> init() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(initSettings);

      // Create Android Notification Channels
      if (Platform.isAndroid) {
        final androidImpl =
            _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              alertsChannelId,
              alertsChannelName,
              description: alertsChannelDesc,
              importance: Importance.high,
            ),
          );

          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              remindersChannelId,
              remindersChannelName,
              description: remindersChannelDesc,
              importance: Importance.defaultImportance,
            ),
          );

          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              transactionsChannelId,
              transactionsChannelName,
              description: transactionsChannelDesc,
              importance: Importance.max,
            ),
          );
        }
      }
    } catch (_) {
      // Ignored if in test or non-supported platform
    }
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Check if notification permission is granted
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Show low balance alert notification
  Future<void> showLowBalanceAlert({
    required String walletName,
    required double currentBalance,
    required double threshold,
  }) async {
    try {
      final fmt = NumberFormat('#,##0.##', 'ar');
      final androidDetails = AndroidNotificationDetails(
        alertsChannelId,
        alertsChannelName,
        channelDescription: alertsChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        lowBalanceNotificationId,
        '⚠️ تنبيه: رصيد منخفض',
        'رصيد $walletName نزل عن ${fmt.format(threshold)} ر.ي (الرصيد الحالي: ${fmt.format(currentBalance)} ر.ي)',
        details,
      );
    } catch (_) {}
  }

  /// Schedule daily reminder at 21:00 (or daily repeat)
  Future<void> scheduleDailyReminder() async {
    try {
      final androidDetails = AndroidNotificationDetails(
        remindersChannelId,
        remindersChannelName,
        channelDescription: remindersChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.periodicallyShow(
        dailyReminderNotificationId,
        'سجّل صرفيات اليوم 📝',
        'لا تنسَ تسجيل حركاتك ومصروفاتك اليومية في ميزان للحفاظ على دقة حساباتك!',
        RepeatInterval.daily,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  /// Cancel daily reminder
  Future<void> cancelDailyReminder() async {
    try {
      await _plugin.cancel(dailyReminderNotificationId);
    } catch (_) {}
  }

  /// Show instant notification for transactions (purchase, deposit, transfer, etc.)
  Future<void> showTransactionAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        transactionsChannelId,
        transactionsChannelName,
        channelDescription: transactionsChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body),
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _plugin.show(
        notifId,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (_) {}
  }
}
