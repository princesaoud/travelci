import 'package:travelci/core/models/api_response.dart';
import 'package:travelci/core/services/api_service.dart';
import 'package:travelci/core/utils/api_config.dart';

/// Service for property availability (owner-defined blocked dates)
class AvailabilityService extends ApiService {
  /// Get blocked dates for a property.
  /// Returns [] if the backend route is not available (404 / route non trouvée).
  Future<List<String>> getBlockedDates(String propertyId) async {
    try {
      final response = await get<Map<String, dynamic>>(
        ApiConfig.propertyBlockedDatesEndpoint(propertyId),
        parser: (data) => data as Map<String, dynamic>,
      );

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response as Map<String, dynamic>,
        (data) => data as Map<String, dynamic>,
      );

      if (apiResponse.data != null && apiResponse.data!['dates'] != null) {
        final dates = apiResponse.data!['dates'] as List<dynamic>;
        return dates.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      if (_isRouteNotFound(e)) return [];
      rethrow;
    }
  }

  static bool _isRouteNotFound(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('404') ||
        msg.contains('not found') ||
        msg.contains('non trouvée') ||
        msg.contains('route non trouvée');
  }

  /// Add blocked dates for a property
  Future<List<String>> addBlockedDates(String propertyId, List<String> dates) async {
    try {
      final response = await post<Map<String, dynamic>>(
        ApiConfig.propertyBlockedDatesEndpoint(propertyId),
        data: {'dates': dates},
        parser: (data) => data as Map<String, dynamic>,
      );

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response as Map<String, dynamic>,
        (data) => data as Map<String, dynamic>,
      );

      if (apiResponse.data != null && apiResponse.data!['dates'] != null) {
        final added = apiResponse.data!['dates'] as List<dynamic>;
        return added.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      if (_isRouteNotFound(e)) {
        throw Exception(
          'Le serveur ne prend pas en charge les dates bloquées pour l\'instant.',
        );
      }
      rethrow;
    }
  }

  /// Remove blocked dates for a property
  Future<void> removeBlockedDates(String propertyId, List<String> dates) async {
    try {
      await delete<Map<String, dynamic>>(
        ApiConfig.propertyBlockedDatesEndpoint(propertyId),
        data: {'dates': dates},
        parser: (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      if (_isRouteNotFound(e)) {
        throw Exception(
          'Le serveur ne prend pas en charge les dates bloquées pour l\'instant.',
        );
      }
      rethrow;
    }
  }
}
