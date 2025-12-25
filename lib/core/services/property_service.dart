import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:travelci/core/models/api_response.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/services/api_service.dart';
import 'package:travelci/core/utils/api_config.dart';
import 'package:travelci/core/utils/token_manager.dart';

/// Property Service
/// 
/// Handles property-related API calls
class PropertyService extends ApiService {
  /// Get all properties with filters and pagination
  Future<PropertyListResponse> getProperties({
    String? city,
    PropertyType? type,
    bool? furnished,
    double? priceMin,
    double? priceMax,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (city != null && city.isNotEmpty) {
      queryParams['city'] = city;
    }
    if (type != null) {
      queryParams['type'] = type.value;
    }
    if (furnished != null) {
      queryParams['furnished'] = furnished;
    }
    if (priceMin != null) {
      queryParams['priceMin'] = priceMin;
    }
    if (priceMax != null) {
      queryParams['priceMax'] = priceMax;
    }

    final response = await get<Map<String, dynamic>>(
      ApiConfig.propertiesEndpoint,
      queryParameters: queryParams,
      parser: (data) => data as Map<String, dynamic>,
    );

    // The API can return data as either:
    // 1. Direct array: { success: true, data: [properties...] }
    // 2. Wrapped: { success: true, data: { properties: [...] } }
    
    List<dynamic>? propertiesData;
    
    if (response['data'] is List) {
      // Direct array format
      propertiesData = response['data'] as List<dynamic>;
    } else if (response['data'] is Map && (response['data'] as Map).containsKey('properties')) {
      // Wrapped format
      propertiesData = (response['data'] as Map<String, dynamic>)['properties'] as List<dynamic>?;
    }

    if (propertiesData != null) {
      final properties = propertiesData
          .map((item) => Property.fromJson(item as Map<String, dynamic>))
          .toList();

      final apiResponse = ApiResponse<dynamic>.fromJson(
        response,
        (data) => data,
      );

      return PropertyListResponse(
        properties: properties,
        pagination: apiResponse.pagination,
      );
    }

    throw Exception(apiResponse.error?.message ?? 'Impossible de récupérer les propriétés');
  }

  /// Get property by ID
  Future<Property> getPropertyById(String id) async {
    final response = await get<Map<String, dynamic>>(
      ApiConfig.propertyEndpoint(id),
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      return Property.fromJson(apiResponse.data!);
    }

    throw Exception(apiResponse.error?.message ?? 'Propriété non trouvée');
  }

  /// Create a new property (with image uploads)
  Future<Property> createProperty({
    required String title,
    String? description,
    required PropertyType type,
    bool furnished = false,
    required double pricePerNight,
    required String address,
    required String city,
    double? latitude,
    double? longitude,
    List<String> amenities = const [],
    List<File>? images,
  }) async {
    // Check authentication
    final token = await TokenManager.getToken();
    if (token == null) {
      throw Exception('Vous devez être connecté pour créer une propriété');
    }

    // Prepare form data
    final formData = FormData.fromMap({
      'title': title,
      if (description != null) 'description': description,
      'type': type.value,
      'furnished': furnished,
      'price_per_night': pricePerNight,
      'address': address,
      'city': city,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (amenities.isNotEmpty) 'amenities': jsonEncode(amenities),
    });

    // Add images if provided (multiple files with same key name)
    if (images != null && images.isNotEmpty) {
      for (var image in images) {
        formData.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(
              image.path,
              filename: image.path.split('/').last,
            ),
          ),
        );
      }
    }

    try {
      final response = await dio.post(
        ApiConfig.propertiesEndpoint,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data,
      );

      if (apiResponse.data != null) {
        return Property.fromJson(apiResponse.data!);
      }

      throw Exception(apiResponse.error?.message ?? 'Erreur lors de la création de la propriété');
    } on DioException catch (e) {
      throw Exception(_getErrorMessage(e));
    }
  }

  /// Update property
  Future<Property> updateProperty({
    required String id,
    String? title,
    String? description,
    PropertyType? type,
    bool? furnished,
    double? pricePerNight,
    String? address,
    String? city,
    double? latitude,
    double? longitude,
    List<String>? amenities,
  }) async {
    final data = <String, dynamic>{};

    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (type != null) data['type'] = type.value;
    if (furnished != null) data['furnished'] = furnished;
    if (pricePerNight != null) data['price_per_night'] = pricePerNight;
    if (address != null) data['address'] = address;
    if (city != null) data['city'] = city;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (amenities != null) data['amenities'] = amenities;

    final response = await put<Map<String, dynamic>>(
      ApiConfig.propertyEndpoint(id),
      data: data,
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      return Property.fromJson(apiResponse.data!);
    }

    throw Exception(apiResponse.error?.message ?? 'Erreur lors de la mise à jour de la propriété');
  }

  /// Delete property
  Future<void> deleteProperty(String id) async {
    await delete<Map<String, dynamic>>(
      ApiConfig.propertyEndpoint(id),
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  String _getErrorMessage(DioException error) {
    if (error.response?.data != null && error.response!.data is Map<String, dynamic>) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('error')) {
        final errorObj = data['error'];
        if (errorObj is Map<String, dynamic> && errorObj.containsKey('message')) {
          return errorObj['message'] as String;
        }
      }
      if (data.containsKey('message')) {
        return data['message'] as String;
      }
    }
    return error.message ?? 'Une erreur s\'est produite';
  }
}

/// Property List Response
class PropertyListResponse {
  final List<Property> properties;
  final PaginationInfo? pagination;

  PropertyListResponse({
    required this.properties,
    this.pagination,
  });
}

