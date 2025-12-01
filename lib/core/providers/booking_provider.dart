import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelci/core/models/booking.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/services/mock_data_service.dart';
import 'package:uuid/uuid.dart';

class BookingNotifier extends StateNotifier<List<Booking>> {
  BookingNotifier() : super([]);

  void loadBookings(String userId, UserRole role) {
    state = MockDataService.getMockBookings(userId, role);
  }

  void createBooking({
    required String propertyId,
    required String clientId,
    required DateTime startDate,
    required DateTime endDate,
    required int guests,
    String? message,
    required int totalPrice,
  }) {
    final booking = Booking(
      id: const Uuid().v4(),
      propertyId: propertyId,
      clientId: clientId,
      startDate: startDate,
      endDate: endDate,
      nights: endDate.difference(startDate).inDays,
      guests: guests,
      message: message,
      totalPrice: totalPrice,
      status: BookingStatus.pending,
      createdAt: DateTime.now(),
    );

    state = [...state, booking];
  }

  void updateBookingStatus(String bookingId, BookingStatus status) {
    state = state.map((b) => b.id == bookingId ? Booking(
      id: b.id,
      propertyId: b.propertyId,
      clientId: b.clientId,
      startDate: b.startDate,
      endDate: b.endDate,
      nights: b.nights,
      guests: b.guests,
      message: b.message,
      totalPrice: b.totalPrice,
      status: status,
      createdAt: b.createdAt,
    ) : b).toList();
  }

  Booking? getBookingById(String id) {
    try {
      return state.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }
}

final bookingProvider = StateNotifierProvider<BookingNotifier, List<Booking>>((ref) {
  return BookingNotifier();
});

