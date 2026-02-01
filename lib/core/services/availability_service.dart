import 'package:travelci/core/models/api_response.dart';
import 'package:travelci/core/services/api_service.dart';
import 'package:travelci/core/utils/api_config.dart';

/// Service for property availability (owner-defined blocked dates)
class AvailabilityService extends ApiService {
  /// Get blocked dates for a property
  Future<List<String>> getBlockedDates(String propertyId) async {
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
  }

  /// Add blocked dates for a property
  Future<List<String>> addBlockedDates(String propertyId, List<String> dates) async {
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
  }

  /// Remove blocked dates for a property
  Future<void> removeBlockedDates(String propertyId, List<String> dates) async {
    await delete<Map<String, dynamic>>(
      ApiConfig.propertyBlockedDatesEndpoint(propertyId),
      data: {'dates': dates},
      parser: (data) => data as Map<String, dynamic>,
    );
  }
}
