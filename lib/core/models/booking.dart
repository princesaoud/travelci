import 'package:equatable/equatable.dart';

enum BookingStatus { pending, accepted, declined, cancelled }

class Booking extends Equatable {
  final String id;
  final String propertyId;
  final String clientId;
  final DateTime startDate;
  final DateTime endDate;
  final int nights;
  final int guests;
  final String? message;
  final int totalPrice; // XOF
  final BookingStatus status;
  final DateTime createdAt;

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
  });

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
      ];
}

