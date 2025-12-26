import 'package:dio/dio.dart';

/// API Error Handler
/// 
/// Handles API errors and converts them to user-friendly messages
class ApiErrorHandler {
  /// Extract error message from DioException
  static String getErrorMessage(DioException error) {
    // Check if there's a response with error data
    if (error.response != null && error.response!.data != null) {
      final data = error.response!.data;

      // Check for API error format
      if (data is Map<String, dynamic>) {
        // Check for nested error object
        if (data.containsKey('error')) {
          final errorObj = data['error'];
          if (errorObj is Map<String, dynamic> && errorObj.containsKey('message')) {
            return errorObj['message'] as String;
          }
        }

        // Check for direct message field
        if (data.containsKey('message')) {
          return data['message'] as String;
        }
      }
    }

    // Handle different error types
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Délai d\'attente dépassé. Veuillez réessayer.';

      case DioExceptionType.badResponse:
        switch (error.response?.statusCode) {
          case 400:
            return 'Requête invalide. Veuillez vérifier vos données.';
          case 401:
            return 'Non autorisé. Veuillez vous connecter.';
          case 403:
            return 'Accès interdit. Vous n\'avez pas les permissions nécessaires.';
          case 404:
            return 'Ressource non trouvée.';
          case 422:
            return 'Données invalides. Veuillez vérifier les champs requis.';
          case 429:
            return 'Trop de requêtes. Veuillez patienter avant de réessayer.';
          case 500:
            return 'Erreur serveur. Veuillez réessayer plus tard.';
          default:
            return 'Erreur ${error.response?.statusCode}. Veuillez réessayer.';
        }

      case DioExceptionType.cancel:
        return 'Requête annulée.';

      case DioExceptionType.connectionError:
        return 'Impossible de se connecter au serveur. Vérifiez que le backend est en cours d\'exécution et que vous êtes sur le même réseau Wi-Fi.';

      case DioExceptionType.badCertificate:
        return 'Erreur de certificat SSL.';

      case DioExceptionType.unknown:
      default:
        return error.message ?? 'Une erreur inattendue s\'est produite.';
    }
  }

  /// Extract error code from response
  static String? getErrorCode(DioException error) {
    if (error.response?.data != null && error.response!.data is Map<String, dynamic>) {
      final data = error.response!.data as Map<String, dynamic>;
      if (data.containsKey('error')) {
        final errorObj = data['error'];
        if (errorObj is Map<String, dynamic> && errorObj.containsKey('code')) {
          return errorObj['code'] as String;
        }
      }
    }
    return null;
  }

  /// Check if error is a network error
  static bool isNetworkError(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout;
  }

  /// Check if error is an authentication error
  static bool isAuthenticationError(DioException error) {
    return error.response?.statusCode == 401;
  }
}

