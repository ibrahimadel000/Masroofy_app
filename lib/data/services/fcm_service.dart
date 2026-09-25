import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mizaan/core/constants/sms_senders.dart';
import 'package:mizaan/data/services/notification_service.dart';

/// Top-level background message handler for FCM
/// Must be annotated with @pragma('vm:entry-point') so Flutter engine can call it
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase already initialized
  }

  debugPrint(
    '🔥 [FCM Background Message]: ID=${message.messageId}, data=${message.data}, notif=${message.notification?.title}',
  );

  // If this is a data-only message (or custom backend payload) and app is in background, show local notification
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title']?.toString() ?? 'تنبيه ميزان';
    final body =
        message.data['body']?.toString() ?? message.data['message']?.toString();
    if (body != null && body.isNotEmpty) {
      try {
        final notif = NotificationService();
        await notif.init();
        await notif.showRemoteNotification(
          title: title,
          body: body,
          payload: message.data.toString(),
        );
      } catch (e) {
        debugPrint('Error showing background data notification: $e');
      }
    }
  }

  // Handle background silent actions (e.g. dynamic SMS templates update)
  if (message.data.isNotEmpty) {
    final action = message.data['action'];
    if (action == 'reload_templates') {
      try {
        debugPrint('FCM background action: reloading custom SMS templates...');
        await SmsSenderRegistry.loadCustomTemplates();
      } catch (e) {
        debugPrint('Error reloading custom templates in background: $e');
      }
    }
  }
}

/// Central Service for Firebase Cloud Messaging (FCM)
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService({FirebaseMessaging? messaging}) {
    if (messaging != null) {
      _instance._messagingInstance = messaging;
    }
    return _instance;
  }
  FcmService._internal({FirebaseMessaging? messaging})
    : _messagingInstance = messaging;

  FirebaseMessaging? _messagingInstance;
  FirebaseMessaging get _messaging =>
      _messagingInstance ??= FirebaseMessaging.instance;
  bool _isInitialized = false;
  String? _cachedToken;

  /// Returns whether the FCM service has been initialized
  bool get isInitialized => _isInitialized;

  /// Returns the current device's FCM Token (if available)
  String? get token => _cachedToken;

  /// Initialize Firebase Cloud Messaging
  Future<void> init() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _isInitialized = true;
      return;
    }

    try {
      // 1. Register top-level background handler safely
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (e) {
        debugPrint('FcmService onBackgroundMessage registration note: $e');
      }

      // 2. Request / verify notification permission (Mandatory for Android 13+ and iOS)
      try {
        final settings = await requestPermission();
        debugPrint(
          'FCM Authorization Status: ${settings?.authorizationStatus}',
        );
      } catch (e) {
        debugPrint('FCM requestPermission note: $e');
      }

      // 3. Set foreground presentation options for Apple / heads-up
      try {
        await _messaging
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {}

      // 4. Load locally cached token first so token is immediately available
      try {
        final prefs = await SharedPreferences.getInstance();
        final local = prefs.getString('fcm_device_token');
        if (local != null && local.isNotEmpty) {
          _cachedToken = local;
        }
      } catch (_) {}

      // 5. Retrieve and store FCM Token with retry
      await _retrieveAndStoreToken();

      // 6. Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔥 [FCM Token Refreshed]: $newToken');
        _cachedToken = newToken;
        await _saveTokenLocally(newToken);
        await syncTokenToFirestore(newToken);
        _subscribeToDefaultTopics();
      });

      // 7. Subscribe to default broadcast topics
      _subscribeToDefaultTopics();

      // 8. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '🔥 [FCM Foreground message received]: id=${message.messageId}, data=${message.data}, notif=${message.notification?.title}',
        );
        _handleForegroundMessage(message);
      });

      // 9. Handle user interaction when tapping notification (from background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM Notification tapped from background: ${message.data}');
        _handleNotificationTap(message);
      });

      // 10. Check if the app was launched by tapping a notification (from terminated state)
      try {
        final initialMessage = await _messaging.getInitialMessage().timeout(
          const Duration(seconds: 3),
        );
        if (initialMessage != null) {
          debugPrint(
            'FCM App opened from terminated state via message: ${initialMessage.data}',
          );
          _handleNotificationTap(initialMessage);
        }
      } catch (_) {}

      _isInitialized = true;
      debugPrint('FcmService initialized successfully.');
    } catch (e) {
      debugPrint('FcmService initialization note: $e');
    }
  }

  /// Explicitly request notification permissions when user reaches onboarding or settings
  Future<NotificationSettings?> requestPermission() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return null;
    try {
      final settings = await _messaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          )
          .timeout(const Duration(seconds: 6));
      debugPrint(
        'FCM Explicit Authorization Status: ${settings.authorizationStatus}',
      );
      return settings;
    } catch (e) {
      debugPrint('FCM requestPermission error: $e');
      return null;
    }
  }

  /// Subscribe to standard topics for broadcast announcements
  void _subscribeToDefaultTopics() {
    subscribeToTopic('all_users');
    subscribeToTopic('announcements');
    subscribeToTopic('android_users');
    subscribeToTopic('currency_updates');
  }

  /// Retrieve FCM token and cache it locally with retry and backoff
  Future<void> _retrieveAndStoreToken() async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final fetched = await _messaging.getToken().timeout(
          const Duration(seconds: 10),
        );
        if (fetched != null && fetched.isNotEmpty) {
          _cachedToken = fetched;
          debugPrint('====================================================');
          debugPrint(
            '🔥 [Mizaan FCM Device Token (Success - Attempt $attempt)]:',
          );
          debugPrint(_cachedToken);
          debugPrint('====================================================');
          await _saveTokenLocally(_cachedToken!);
          await syncTokenToFirestore(_cachedToken!);
          return;
        }
      } catch (e) {
        debugPrint('FcmService: Attempt $attempt to fetch FCM token: $e');
        if (attempt < 3) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }

  /// Public helper to get or re-fetch FCM token (useful for Settings screen & testing)
  Future<String?> getOrFetchToken({bool force = false}) async {
    if (!force && _cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }
    await _retrieveAndStoreToken();
    return _cachedToken;
  }

  /// Save token to local SharedPreferences
  Future<void> _saveTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_device_token', token);
    } catch (e) {
      debugPrint('FcmService: Error saving token locally: $e');
    }
  }

  /// Synchronize FCM token to Firestore user profile if logged in
  Future<void> syncTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
              'platform': Platform.operatingSystem,
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
        debugPrint('FCM token synced to Firestore for user: ${user.uid}');
      }
    } catch (e) {
      debugPrint('FcmService: Error syncing token to Firestore: $e');
    }
  }

  /// Handle incoming message when app is in Foreground
  void _handleForegroundMessage(RemoteMessage message) {
    // Check for silent action payload
    if (message.data.isNotEmpty) {
      final action = message.data['action'];
      if (action == 'reload_templates') {
        debugPrint(
          'FCM: reloading custom SMS templates triggered by data payload...',
        );
        SmsSenderRegistry.loadCustomTemplates();
      }
    }

    // Determine title & body from notification OR data payload
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'تنبيه ميزان';
    final body =
        message.notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        '';

    if (body.isNotEmpty || message.notification != null) {
      NotificationService().showRemoteNotification(
        title: title,
        body: body.isNotEmpty ? body : 'وصلك إشعار جديد من ميزان',
        payload: message.data.isNotEmpty ? message.data.toString() : null,
      );
    }
  }

  /// Handle notification tap (deep link or navigation action)
  void _handleNotificationTap(RemoteMessage message) {
    final route = message.data['route'];
    if (route != null) {
      debugPrint('FCM target navigation route: $route');
      // Navigation can be wired here or via event bus/route observer
    }
  }

  /// Subscribe to a specific FCM topic with timeout
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging
          .subscribeToTopic(topic)
          .timeout(const Duration(seconds: 8));
      debugPrint('Subscribed to FCM topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to FCM topic ($topic): $e');
    }
  }

  /// Unsubscribe from a specific FCM topic with timeout
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging
          .unsubscribeFromTopic(topic)
          .timeout(const Duration(seconds: 8));
      debugPrint('Unsubscribed from FCM topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from FCM topic ($topic): $e');
    }
  }
}
