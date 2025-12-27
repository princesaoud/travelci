import 'package:equatable/equatable.dart';

enum NotificationType {
  bookingRequest,      // Nouvelle demande de réservation (owner)
  bookingAccepted,     // Réservation acceptée (client)
  bookingDeclined,      // Réservation refusée (client)
  bookingCancelled,     // Réservation annulée (owner/client)
  message,             // Nouveau message
  system,              // Notification système
}

enum NotificationStatus {
  unread,
  read,
}

class AppNotification extends Equatable {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final NotificationStatus status;
  final DateTime createdAt;
  final Map<String, dynamic>? data; // Données supplémentaires (bookingId, propertyId, etc.)

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.status = NotificationStatus.unread,
    required this.createdAt,
    this.data,
  });

  bool get isRead => status == NotificationStatus.read;

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    NotificationStatus? status,
    DateTime? createdAt,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'message': message,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'data': data,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      status: NotificationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => NotificationStatus.unread,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [id, type, title, message, status, createdAt, data];
}

