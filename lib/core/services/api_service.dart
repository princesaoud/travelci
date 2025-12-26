import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:travelci/core/utils/api_config.dart';
import 'package:travelci/core/utils/error_handler.dart';
import 'package:travelci/core/utils/token_manager.dart';

/// Base API Service
/// 
/// Provides common functionality for all API services
class ApiService {
  late final Dio _dio;

  ApiService() {
    developer.log('[ApiService] Initializing with baseUrl: ${ApiConfig.baseUrl}');
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.requestTimeout,
        receiveTimeout: ApiConfig.requestTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptor to include auth token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await TokenManager.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          // Handle errors globally if needed
          return handler.next(error);
        },
      ),
    );
  }

  /// Get Dio instance
  Dio get dio => _dio;

  /// Handle API errors and throw user-friendly exceptions
  T handleApiResponse<T>(
    Response response,
    T Function(dynamic) parser,
  ) {
    final data = response.data;

    if (data is Map<String, dynamic> && data.containsKey('success')) {
      final success = data['success'] as bool;
      if (!success && data.containsKey('error')) {
        final error = data['error'];
        if (error is Map<String, dynamic>) {
          throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: error['message'] ?? 'Une erreur s\'est produite',
          );
        }
      }
    }

    return parser(data);
  }

  /// Make GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic) parser,
    Options? options,
  }) async {
    try {
      final fullUrl = '${ApiConfig.baseUrl}$path';
      developer.log('[API] GET Request to: $fullUrl');
      
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return handleApiResponse(response, parser);
    } on DioException catch (e) {
      developer.log('[API] GET DioException Type: ${e.type}');
      developer.log('[API] GET Error Message: ${e.message}');
      developer.log('[API] GET Request URL: ${e.requestOptions.uri}');
      throw Exception(ApiErrorHandler.getErrorMessage(e));
    } catch (e) {
      developer.log('[API] GET Unexpected error: $e');
      rethrow;
    }
  }

  /// Make POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic) parser,
    Options? options,
  }) async {
    try {
      // Log the full URL being called
      final fullUrl = '${ApiConfig.baseUrl}$path';
      developer.log('[API] POST Request to: $fullUrl');
      developer.log('[API] Base URL: ${ApiConfig.baseUrl}');
      developer.log('[API] Path: $path');
      
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      developer.log('[API] POST Response Status: ${response.statusCode}');
      return handleApiResponse(response, parser);
    } on DioException catch (e) {
      // Log detailed error information
      developer.log('[API] POST DioException Type: ${e.type}');
      developer.log('[API] POST Error Message: ${e.message}');
      developer.log('[API] POST Request URL: ${e.requestOptions.uri}');
      if (e.response != null) {
        developer.log('[API] POST Response Status: ${e.response?.statusCode}');
        developer.log('[API] POST Response Data: ${e.response?.data}');
      } else {
        developer.log('[API] POST No response received - connection error');
      }
      throw Exception(ApiErrorHandler.getErrorMessage(e));
    } catch (e) {
      developer.log('[API] POST Unexpected error: $e');
      rethrow;
    }
  }

  /// Make PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic) parser,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return handleApiResponse(response, parser);
    } on DioException catch (e) {
      throw Exception(ApiErrorHandler.getErrorMessage(e));
    }
  }

  /// Make DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic) parser,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return handleApiResponse(response, parser);
    } on DioException catch (e) {
      throw Exception(ApiErrorHandler.getErrorMessage(e));
    }
  }
}

