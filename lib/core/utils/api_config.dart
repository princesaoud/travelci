/// API Configuration
/// 
/// Manages API base URL based on the platform/device type
class ApiConfig {
  // Base URLs for different environments
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:3000';
  static const String iosSimulatorBaseUrl = 'http://localhost:3000';
  static const String physicalDeviceBaseUrl = 'http://192.168.100.10:3000'; // Your testing IP - Updated to match your current IP
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

  // Get full API URL (for reference only, not used in Dio calls)
  static String get apiBaseUrl => '$baseUrl$apiPath';

  // Auth endpoints - use relative paths since Dio already has baseUrl
  static String get registerEndpoint => '$apiPath/auth/register';
  static String get loginEndpoint => '$apiPath/auth/login';
  static String get meEndpoint => '$apiPath/auth/me';
  static String get logoutEndpoint => '$apiPath/auth/logout';

  // Property endpoints - use relative paths
  static String get propertiesEndpoint => '$apiPath/properties';
  static String propertyEndpoint(String id) => '$apiPath/properties/$id';

  // Booking endpoints - use relative paths
  static String get bookingsEndpoint => '$apiPath/bookings';
  static String bookingEndpoint(String id) => '$apiPath/bookings/$id';
  static String bookingStatusEndpoint(String id) => '$apiPath/bookings/$id/status';
  static String bookingCancelEndpoint(String id) => '$apiPath/bookings/$id/cancel';

  // Image endpoints - use relative paths
  static String get imagesEndpoint => '$apiPath/images';

  // Request timeout
  static const Duration requestTimeout = Duration(seconds: 30);
}

