import 'dart:developer' as developer;
import 'package:travelci/core/models/api_response.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/services/api_service.dart';
import 'package:travelci/core/utils/api_config.dart';
import 'package:travelci/core/utils/token_manager.dart';

/// Authentication Service
/// 
/// Handles user authentication (register, login, logout, get current user)
class AuthService extends ApiService {
  /// Register a new user
  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    UserRole role = UserRole.client,
  }) async {
    final response = await post<Map<String, dynamic>>(
      ApiConfig.registerEndpoint,
      data: {
        'full_name': fullName,
        'email': email,
        'password': password,
        if (phone != null) 'phone': phone,
        'role': role.value,
      },
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      final userData = apiResponse.data!['user'] as Map<String, dynamic>;
      final token = apiResponse.data!['token'] as String;

      // Save token
      await TokenManager.saveToken(token);

      return AuthResponse(
        user: User.fromJson(userData),
        token: token,
      );
    }

    throw Exception(apiResponse.error?.message ?? 'Erreur lors de l\'inscription');
  }

  /// Login user
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final fullUrl = '${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}';
    developer.log('Login attempt - Endpoint: ${ApiConfig.loginEndpoint}');
    developer.log('Login attempt - Full URL: $fullUrl');
    
    final response = await post<Map<String, dynamic>>(
      ApiConfig.loginEndpoint,
      data: {
        'email': email,
        'password': password,
      },
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      final userData = apiResponse.data!['user'] as Map<String, dynamic>;
      final token = apiResponse.data!['token'] as String;

      // Debug: Log raw user data from API
      developer.log('Raw user data from API: $userData');
      developer.log('User role from API: ${userData['role']}');

      // Save token
      await TokenManager.saveToken(token);

      final user = User.fromJson(userData);
      developer.log('Parsed user role: ${user.role}');

      return AuthResponse(
        user: user,
        token: token,
      );
    }

    throw Exception(apiResponse.error?.message ?? 'Email ou mot de passe incorrect');
  }

  /// Get current user profile
  Future<User> getCurrentUser() async {
    final response = await get<Map<String, dynamic>>(
      ApiConfig.meEndpoint,
      parser: (data) => data as Map<String, dynamic>,
    );

    final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
      response,
      (data) => data,
    );

    if (apiResponse.data != null) {
      final userData = apiResponse.data!['user'] as Map<String, dynamic>;
      return User.fromJson(userData);
    }

    throw Exception(apiResponse.error?.message ?? 'Impossible de récupérer le profil utilisateur');
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await post<Map<String, dynamic>>(
        ApiConfig.logoutEndpoint,
        parser: (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      // Even if logout fails on server, clear local token
      // This ensures user can logout even if there's a network issue
    } finally {
      // Clear token locally
      await TokenManager.clearToken();
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return await TokenManager.isAuthenticated();
  }
}

/// Authentication Response
class AuthResponse {
  final User user;
  final String token;

  AuthResponse({
    required this.user,
    required this.token,
  });
}

