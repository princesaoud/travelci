import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:travelci/core/models/notification.dart' as app;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Abidjan')); // Côte d'Ivoire timezone

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialization settings
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize plugin
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions (iOS)
    await _requestPermissions();

    _initialized = true;
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    // Request Android permissions (Android 13+)
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    // iOS permissions are automatically requested via DarwinInitializationSettings
    // in the initialize() method, so no need to request them explicitly here
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // This will be handled by the notification provider
    // to navigate to the appropriate screen
  }

  /// Show a local notification
  Future<void> showNotification(
    app.AppNotification notification, {
    bool scheduled = false,
    DateTime? scheduledDate,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      'travelci_channel',
      'TravelCI Notifications',
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

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

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

  /// Cancel a notification
  Future<void> cancelNotification(String notificationId) async {
    await _localNotifications.cancel(notificationId.hashCode);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Get pending notifications count
  Future<int> getPendingNotificationsCount() async {
    final pending = await _localNotifications.pendingNotificationRequests();
    return pending.length;
  }
}

