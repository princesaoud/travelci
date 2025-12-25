/// API Configuration
/// 
/// Manages API base URL based on the platform/device type
class ApiConfig {
  // Base URLs for different environments
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:3000';
  static const String iosSimulatorBaseUrl = 'http://localhost:3000';
  static const String physicalDeviceBaseUrl = 'http://192.168.100.32:3000'; // Your testing IP
  static const String localhostBaseUrl = 'http://localhost:3000';

  // API base path
  static const String apiPath = '/api';

  // Health check endpoint (no /api prefix)
  static const String healthEndpoint = '/health';

  // Get base URL based on environment
  // You can modify this to detect the platform or use a specific URL
  static String get baseUrl {
    // For now, default to physical device URL
    // You can change this or add platform detection
    return physicalDeviceBaseUrl;
  }

  // Get full API URL
  static String get apiBaseUrl => '$baseUrl$apiPath';

  // Auth endpoints
  static String get registerEndpoint => '$apiBaseUrl/auth/register';
  static String get loginEndpoint => '$apiBaseUrl/auth/login';
  static String get meEndpoint => '$apiBaseUrl/auth/me';
  static String get logoutEndpoint => '$apiBaseUrl/auth/logout';

  // Property endpoints
  static String get propertiesEndpoint => '$apiBaseUrl/properties';
  static String propertyEndpoint(String id) => '$apiBaseUrl/properties/$id';

  // Booking endpoints
  static String get bookingsEndpoint => '$apiBaseUrl/bookings';
  static String bookingEndpoint(String id) => '$apiBaseUrl/bookings/$id';
  static String bookingStatusEndpoint(String id) => '$apiBaseUrl/bookings/$id/status';
  static String bookingCancelEndpoint(String id) => '$apiBaseUrl/bookings/$id/cancel';

  // Image endpoints
  static String get imagesEndpoint => '$apiBaseUrl/images';

  // Request timeout
  static const Duration requestTimeout = Duration(seconds: 30);
}

