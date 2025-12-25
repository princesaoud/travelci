import 'package:equatable/equatable.dart';

enum BookingStatus { pending, accepted, declined, cancelled }

extension BookingStatusExtension on BookingStatus {
  String get value {
    switch (this) {
      case BookingStatus.pending:
        return 'pending';
      case BookingStatus.accepted:
        return 'accepted';
      case BookingStatus.declined:
        return 'declined';
      case BookingStatus.cancelled:
        return 'cancelled';
    }
  }

  static BookingStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return BookingStatus.pending;
      case 'accepted':
        return BookingStatus.accepted;
      case 'declined':
        return BookingStatus.declined;
      case 'cancelled':
      case 'canceled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }
}

class Booking extends Equatable {
  final String id;
  final String propertyId;
  final String clientId;
  final DateTime startDate;
  final DateTime endDate;
  final int nights;
  final int guests;
  final String? message;
  final int totalPrice; // XOF - stored as int for precision
  final BookingStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Booking({
    required this.id,
    required this.propertyId,
    required this.clientId,
    required this.startDate,
    required this.endDate,
    required this.nights,
    required this.guests,
    this.message,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Handle both single booking object and nested booking object
    final data = json.containsKey('booking') ? json['booking'] as Map<String, dynamic> : json;

    return Booking(
      id: data['id'] as String,
      propertyId: data['property_id'] as String? ?? data['propertyId'] as String,
      clientId: data['client_id'] as String? ?? data['clientId'] as String,
      startDate: DateTime.parse(data['start_date'] as String? ?? data['startDate'] as String),
      endDate: DateTime.parse(data['end_date'] as String? ?? data['endDate'] as String),
      nights: data['nights'] as int? ?? 0,
      guests: data['guests'] as int,
      message: data['message'] as String?,
      totalPrice: (data['total_price'] as num? ?? data['totalPrice'] as num? ?? 0).toInt(),
      status: BookingStatusExtension.fromString(
        data['status'] as String? ?? 'pending',
      ),
      createdAt: DateTime.parse(data['created_at'] as String? ?? data['createdAt'] as String),
      updatedAt: data['updated_at'] != null || data['updatedAt'] != null
          ? DateTime.parse(data['updated_at'] as String? ?? data['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'property_id': propertyId,
      'start_date': startDate.toIso8601String().split('T')[0], // YYYY-MM-DD format
      'end_date': endDate.toIso8601String().split('T')[0], // YYYY-MM-DD format
      'guests': guests,
      if (message != null) 'message': message,
    };
  }

  @override
  List<Object?> get props => [
        id,
        propertyId,
        clientId,
        startDate,
        endDate,
        nights,
        guests,
        message,
        totalPrice,
        status,
        createdAt,
        updatedAt,
      ];
}

