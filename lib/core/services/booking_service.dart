import 'package:travelci/core/models/api_response.dart';
import 'package:travelci/core/models/booking.dart';
import 'package:travelci/core/services/api_service.dart';
import 'package:travelci/core/utils/api_config.dart';

/// Booking Service
/// 
/// Handles booking-related API calls
class BookingService extends ApiService {
  /// Get all bookings (for current user)
  /// 
  /// [role] can be 'client' or 'owner' to filter bookings
  Future<List<Booking>> getBookings({String? role}) async {
    final queryParams = <String, dynamic>{};
    if (role != null) {
      queryParams['role'] = role;
    }

    final response = await get<Map<String, dynamic>>(
      ApiConfig.bookingsEndpoint,
      queryParameters: queryParams.isEmpty ? null : queryParams,
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      final bookingsData = apiResponse.data!['bookings'] as List<dynamic>?;
      if (bookingsData != null) {
        return bookingsData
            .map((item) => Booking.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    throw Exception(apiResponse.error?.message ?? 'Impossible de récupérer les réservations');
  }

  /// Get booking by ID
  Future<Booking> getBookingById(String id) async {
    final response = await get<Map<String, dynamic>>(
      ApiConfig.bookingEndpoint(id),
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      return Booking.fromJson(apiResponse.data!);
    }

    throw Exception(apiResponse.error?.message ?? 'Réservation non trouvée');
  }

  /// Create a new booking
  Future<Booking> createBooking({
    required String propertyId,
    required DateTime startDate,
    required DateTime endDate,
    required int guests,
    String? message,
  }) async {
    final response = await post<Map<String, dynamic>>(
      ApiConfig.bookingsEndpoint,
      data: {
        'property_id': propertyId,
        'start_date': startDate.toIso8601String().split('T')[0], // YYYY-MM-DD format
        'end_date': endDate.toIso8601String().split('T')[0], // YYYY-MM-DD format
        'guests': guests,
        if (message != null) 'message': message,
      },
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      return Booking.fromJson(apiResponse.data!);
    }

    throw Exception(apiResponse.error?.message ?? 'Erreur lors de la création de la réservation');
  }

  /// Update booking status (owner/admin only)
  /// 
  /// [status] should be 'accepted' or 'declined'
  Future<Booking> updateBookingStatus({
    required String id,
    required BookingStatus status,
  }) async {
    final response = await put<Map<String, dynamic>>(
      ApiConfig.bookingStatusEndpoint(id),
      data: {
        'status': status.value,
      },
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      return Booking.fromJson(apiResponse.data!);
    }

    throw Exception(apiResponse.error?.message ?? 'Erreur lors de la mise à jour du statut');
  }

  /// Cancel booking
  Future<Booking> cancelBooking(String id) async {
    final response = await put<Map<String, dynamic>>(
      ApiConfig.bookingCancelEndpoint(id),
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      return Booking.fromJson(apiResponse.data!);
    }

    throw Exception(apiResponse.error?.message ?? 'Erreur lors de l\'annulation de la réservation');
  }
}

