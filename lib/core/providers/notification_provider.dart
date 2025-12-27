import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelci/core/models/notification.dart' as app;
import 'package:travelci/core/services/notification_service.dart';
import 'dart:convert';

class NotificationState {
  final List<app.AppNotification> notifications;
  final bool isLoading;
  final String? error;
  final int unreadCount;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
  });

  NotificationState copyWith({
    List<app.AppNotification>? notifications,
    bool? isLoading,
    String? error,
    int? unreadCount,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  NotificationState copyWithUnreadCount() {
    final count = notifications
        .where((n) => n.status == app.NotificationStatus.unread)
        .length;
    return copyWith(unreadCount: count);
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _notificationService;
  SharedPreferences? _prefs;
  bool _initialized = false;

  NotificationNotifier(this._notificationService) : super(NotificationState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      await _notificationService.initialize();
      await _loadNotifications();
      _initialized = true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Load notifications from local storage
  Future<void> loadNotifications() async {
    if (_prefs == null) {
      await _initialize();
      return;
    }

    try {
      final notificationsJson = _prefs!.getStringList('notifications') ?? [];
      final notifications = notificationsJson
          .map((json) => app.AppNotification.fromJson(jsonDecode(json)))
          .toList();

      // Sort by date (newest first)
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = NotificationState(notifications: notifications)
          .copyWithUnreadCount();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Save notifications to local storage
  Future<void> _saveNotifications() async {
    if (_prefs == null) {
      await _initialize();
    }
    
    if (_prefs == null) return;
    
    try {
      final notificationsJson = state.notifications
          .map((n) => jsonEncode(n.toJson()))
          .toList();
      await _prefs!.setStringList('notifications', notificationsJson);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Add a new notification
  Future<void> addNotification(app.AppNotification notification) async {
    if (!_initialized) await _initialize();
    
    // Add to state
    final updatedNotifications = [notification, ...state.notifications];
    state = NotificationState(notifications: updatedNotifications)
        .copyWithUnreadCount();

    // Save to local storage
    await _saveNotifications();

    // Show system notification
    await _notificationService.showNotification(notification);
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    if (!_initialized) await _initialize();
    
    final updatedNotifications = state.notifications.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(status: app.NotificationStatus.read);
      }
      return n;
    }).toList();

    state = NotificationState(notifications: updatedNotifications)
        .copyWithUnreadCount();
    await _saveNotifications();
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (!_initialized) await _initialize();
    
    final updatedNotifications = state.notifications
        .map((n) => n.copyWith(status: app.NotificationStatus.read))
        .toList();

    state = NotificationState(notifications: updatedNotifications)
        .copyWithUnreadCount();
    await _saveNotifications();
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    if (!_initialized) await _initialize();
    
    final updatedNotifications = state.notifications
        .where((n) => n.id != notificationId)
        .toList();

    state = NotificationState(notifications: updatedNotifications)
        .copyWithUnreadCount();
    await _saveNotifications();

    // Cancel system notification
    await _notificationService.cancelNotification(notificationId);
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    if (!_initialized) await _initialize();
    
    state = const NotificationState();
    await _saveNotifications();
    await _notificationService.cancelAllNotifications();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Create notification for booking request (owner)
  Future<void> notifyBookingRequest({
    required String bookingId,
    required String propertyTitle,
    required String clientName,
  }) async {
    final notification = app.AppNotification(
      id: 'booking_request_$bookingId',
      type: app.NotificationType.bookingRequest,
      title: 'Nouvelle demande de réservation',
      message: '$clientName a demandé une réservation pour "$propertyTitle"',
      createdAt: DateTime.now(),
      data: {
        'bookingId': bookingId,
        'type': 'booking_request',
      },
    );

    await addNotification(notification);
  }

  /// Create notification for booking accepted (client)
  Future<void> notifyBookingAccepted({
    required String bookingId,
    required String propertyTitle,
  }) async {
    final notification = app.AppNotification(
      id: 'booking_accepted_$bookingId',
      type: app.NotificationType.bookingAccepted,
      title: 'Réservation acceptée',
      message: 'Votre réservation pour "$propertyTitle" a été acceptée',
      createdAt: DateTime.now(),
      data: {
        'bookingId': bookingId,
        'type': 'booking_accepted',
      },
    );

    await addNotification(notification);
  }

  /// Create notification for booking declined (client)
  Future<void> notifyBookingDeclined({
    required String bookingId,
    required String propertyTitle,
    String? reason,
  }) async {
    final notification = app.AppNotification(
      id: 'booking_declined_$bookingId',
      type: app.NotificationType.bookingDeclined,
      title: 'Réservation refusée',
      message: reason != null
          ? 'Votre réservation pour "$propertyTitle" a été refusée: $reason'
          : 'Votre réservation pour "$propertyTitle" a été refusée',
      createdAt: DateTime.now(),
      data: {
        'bookingId': bookingId,
        'type': 'booking_declined',
        'reason': reason,
      },
    );

    await addNotification(notification);
  }

  /// Create notification for booking cancelled
  Future<void> notifyBookingCancelled({
    required String bookingId,
    required String propertyTitle,
    required bool isOwner,
  }) async {
    final notification = app.AppNotification(
      id: 'booking_cancelled_$bookingId',
      type: app.NotificationType.bookingCancelled,
      title: 'Réservation annulée',
      message: isOwner
          ? 'Une réservation pour "$propertyTitle" a été annulée'
          : 'Votre réservation pour "$propertyTitle" a été annulée',
      createdAt: DateTime.now(),
      data: {
        'bookingId': bookingId,
        'type': 'booking_cancelled',
      },
    );

    await addNotification(notification);
  }
}

// Providers
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return NotificationNotifier(service);
});
