import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:travelci/core/models/notification.dart' as app;

/// Callback invoked when the user taps a notification (local or FCM).
/// Receives the notification payload (e.g. route string).
typedef NotificationTapCallback = void Function(String? payload);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  bool _initialized = false;

  /// Registered callback invoked when user taps a notification.
  NotificationTapCallback? onNotificationTap;

  /// Returns the FCM device token (null if not yet available).
  Future<String?> getFCMToken() => _fcm.getToken();

  /// Stream of token refreshes — callers should re-register on each new token.
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Abidjan'));

    await _initLocalNotifications();
    await _initFCM();

    _initialized = true;
  }

  // ─── Local notifications ───────────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  // ─── Firebase Cloud Messaging ──────────────────────────────────────────────

  Future<void> _initFCM() async {
    // Request permission (iOS / Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground: show a local notification (FCM only shows data payload in foreground)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background tap: app was in background and user tapped the notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onNotificationTap?.call(_payloadFromFCM(message));
    });

    // Terminated tap: app was closed and user tapped the notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      // Slight delay so the router is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        onNotificationTap?.call(_payloadFromFCM(initialMessage));
      });
    }

    // On Android, show heads-up notifications in foreground via local notifications
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Shows a local notification when a FCM message arrives in the foreground.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      'travelci_channel',
      'SOMO Notifications',
      channelDescription: 'Notifications pour les réservations et messages',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: _payloadFromFCM(message),
    );
  }

  /// Extracts a routing payload from a FCM message data map.
  String? _payloadFromFCM(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'message' && data['conversationId'] != null) {
      return 'chat/${data['conversationId']}';
    }
    if (data['bookingId'] != null) {
      return 'booking/${data['bookingId']}';
    }
    return data['route'] as String?;
  }

  // ─── Local notification helpers ────────────────────────────────────────────

  Future<void> showNotification(
    app.AppNotification notification, {
    bool scheduled = false,
    DateTime? scheduledDate,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'travelci_channel',
      'SOMO Notifications',
      channelDescription: 'Notifications pour les réservations et messages',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    if (scheduled && scheduledDate != null) {
      await _localNotifications.zonedSchedule(
        notification.id.hashCode,
        notification.title,
        notification.message,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: notification.id,
      );
    } else {
      await _localNotifications.show(
        notification.id.hashCode,
        notification.title,
        notification.message,
        details,
        payload: notification.id,
      );
    }
  }

  Future<void> cancelNotification(String notificationId) async {
    await _localNotifications.cancel(notificationId.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  Future<int> getPendingNotificationsCount() async {
    final pending = await _localNotifications.pendingNotificationRequests();
    return pending.length;
  }
}
