import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelci/core/models/booking.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/services/booking_service.dart';

/// Minimum time between booking list API calls (throttle to reduce rate limits).
const Duration _bookingLoadThrottle = Duration(seconds: 30);

class BookingState {
  final List<Booking> bookings;
  final bool isLoading;
  final String? error;
  final DateTime? lastLoadedAt;

  const BookingState({
    this.bookings = const [],
    this.isLoading = false,
    this.error,
    this.lastLoadedAt,
  });

  BookingState copyWith({
    List<Booking>? bookings,
    bool? isLoading,
    String? error,
    DateTime? lastLoadedAt,
  }) {
    return BookingState(
      bookings: bookings ?? this.bookings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastLoadedAt: lastLoadedAt ?? this.lastLoadedAt,
    );
  }
}

class BookingNotifier extends StateNotifier<BookingState> {
  final BookingService _bookingService;

  BookingNotifier(this._bookingService) : super(BookingState());

  /// Load bookings for current user.
  /// [role] can be 'client' or 'owner' to filter bookings.
  /// [forceRefresh] bypasses throttle (e.g. for pull-to-refresh).
  Future<void> loadBookings({String? role, bool forceRefresh = false}) async {
    if (!forceRefresh &&
        state.lastLoadedAt != null &&
        DateTime.now().difference(state.lastLoadedAt!) < _bookingLoadThrottle) {
      return;
    }
    state = state.copyWith(isLoading: true, error: null);

    try {
      final bookings = await _bookingService.getBookings(role: role);
      state = state.copyWith(
        bookings: bookings,
        isLoading: false,
        error: null,
        lastLoadedAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Get booking by ID
  Booking? getBookingById(String id) {
    try {
      return state.bookings.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Create a new booking
  Future<Booking> createBooking({
    required String propertyId,
    required DateTime startDate,
    required DateTime endDate,
    required int guests,
    String? message,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final booking = await _bookingService.createBooking(
        propertyId: propertyId,
        startDate: startDate,
        endDate: endDate,
        guests: guests,
        message: message,
      );

      // Add to state
      final updatedBookings = [booking, ...state.bookings];
      state = state.copyWith(
        bookings: updatedBookings,
        isLoading: false,
        error: null,
      );

      return booking;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Update booking status (owner/admin only)
  Future<Booking> updateBookingStatus({
    required String id,
    required BookingStatus status,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final booking = await _bookingService.updateBookingStatus(
        id: id,
        status: status,
      );

      // Update in state
      final updatedBookings = state.bookings
          .map((b) => b.id == id ? booking : b)
          .toList();

      state = state.copyWith(
        bookings: updatedBookings,
        isLoading: false,
        error: null,
      );

      return booking;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Cancel booking
  Future<Booking> cancelBooking(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final booking = await _bookingService.cancelBooking(id);

      // Update in state
      final updatedBookings = state.bookings
          .map((b) => b.id == id ? booking : b)
          .toList();

      state = state.copyWith(
        bookings: updatedBookings,
        isLoading: false,
        error: null,
      );

      return booking;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Refresh bookings (always fetches from API)
  Future<void> refresh({String? role}) async {
    await loadBookings(role: role, forceRefresh: true);
  }
}

// Provider for BookingService
final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService();
});

// Provider for BookingNotifier
final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>((ref) {
  final bookingService = ref.watch(bookingServiceProvider);
  return BookingNotifier(bookingService);
});
