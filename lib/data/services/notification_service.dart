import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService({FlutterLocalNotificationsPlugin? plugin}) {
    if (plugin != null) {
      _instance._plugin = plugin;
    }
    return _instance;
  }

  NotificationService._internal({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

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

  Future<void> init() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _isInitialized = true;
      return;
    }
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification tapped with payload: ${details.payload}');
        },
      );

      // Create Android Notification Channels (Mandatory for Android 8.0+)
      if (Platform.isAndroid) {
        final androidImpl =
            _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          // Channel 1: Instant transactions & alerts (Max priority, Heads-up)
          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              transactionsChannelId,
              transactionsChannelName,
              description: transactionsChannelDesc,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              enableLights: true,
            ),
          );

          // Channel 2: Low balance alerts
          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              alertsChannelId,
              alertsChannelName,
              description: alertsChannelDesc,
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
              enableLights: true,
            ),
          );

          // Channel 3: Daily reminders
          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              remindersChannelId,
              remindersChannelName,
              description: remindersChannelDesc,
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );
        }
      }
      _isInitialized = true;
      debugPrint('NotificationService initialized successfully with channels.');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Check if notification permission is granted or enabled on the phone
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      if (Platform.isAndroid) {
        final androidImpl =
            _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final areEnabled = await androidImpl?.areNotificationsEnabled();
        if (areEnabled != null) return areEnabled;
      }
      return await Permission.notification.isGranted;
    } catch (e) {
      debugPrint('hasPermission check error: $e');
      return true;
    }
  }

  /// Request notification permission (compatible with Android 13+ and older Android)
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      if (Platform.isAndroid) {
        final androidImpl =
            _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        // On Android 13+, this triggers the system runtime permission dialog
        final granted = await androidImpl?.requestNotificationsPermission();
        if (granted != null) {
          return granted;
        }

        // On older Android (< 13), notifications are enabled by default unless user toggled off
        final areEnabled = await androidImpl?.areNotificationsEnabled();
        if (areEnabled != null) {
          return areEnabled;
        }
      }

      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('requestPermission error: $e');
      return false;
    }
  }

  /// Open system app settings if user disabled notifications in phone settings
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
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
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      if (!_isInitialized) await init();
      final fmt = NumberFormat('#,##0.##', 'ar');
      final body = 'رصيد $walletName نزل عن ${fmt.format(threshold)} ر.ي (الرصيد الحالي: ${fmt.format(currentBalance)} ر.ي)';
      const title = '⚠️ تنبيه: رصيد منخفض';

      final androidDetails = AndroidNotificationDetails(
        alertsChannelId,
        alertsChannelName,
        channelDescription: alertsChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ticker: title,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'ميزان',
        ),
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
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('showLowBalanceAlert error: $e');
    }
  }

  /// Schedule daily reminder at 21:00 (or daily repeat)
  Future<void> scheduleDailyReminder() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      if (!_isInitialized) await init();
      const androidDetails = AndroidNotificationDetails(
        remindersChannelId,
        remindersChannelName,
        channelDescription: remindersChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        playSound: true,
        enableVibration: true,
        ticker: 'سجّل صرفيات اليوم 📝',
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
    } catch (e) {
      debugPrint('scheduleDailyReminder error: $e');
    }
  }

  /// Cancel daily reminder
  Future<void> cancelDailyReminder() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      await _plugin.cancel(dailyReminderNotificationId);
    } catch (e) {
      debugPrint('cancelDailyReminder error: $e');
    }
  }

  /// Show instant notification for transactions (purchase, deposit, transfer, etc.)
  Future<void> showTransactionAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      if (!_isInitialized) await init();

      final androidDetails = AndroidNotificationDetails(
        transactionsChannelId,
        transactionsChannelName,
        channelDescription: transactionsChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        playSound: true,
        enableVibration: true,
        enableLights: true,
        channelShowBadge: true,
        ticker: title,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'ميزان',
        ),
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
    } catch (e) {
      debugPrint('showTransactionAlert error: $e');
    }
  }

  /// Show instant notification for a manually recorded transaction
  Future<void> showManualTransactionNotification({
    required String walletName,
    required String type,
    required double amount,
    required String currencyCode,
    double? currentBalance,
  }) async {
    final formattedAmount = NumberFormat('#,##0.##', 'ar').format(amount);
    final isExpense = type == 'expense';
    final title = isExpense
        ? '💸 تسجيل مصروف جديد - $walletName'
        : '💰 تسجيل إيداع جديد - $walletName';

    final balanceText = currentBalance != null
        ? ' (الرصيد الحالي: ${NumberFormat('#,##0.##', 'ar').format(currentBalance)} $currencyCode)'
        : '';
    final body = 'تم تسجيل ${isExpense ? "مصروف" : "إيداع"} بمبلغ $formattedAmount $currencyCode في $walletName$balanceText';

    await showTransactionAlert(title: title, body: body);
  }
}

