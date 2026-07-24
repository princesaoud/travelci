import 'dart:io' show Platform;
import 'package:travelci/core/services/api_service.dart';
import 'package:travelci/core/utils/api_config.dart';

/// Registers/unregisters this device's FCM push token with the backend so that
/// the server can send push notifications to the authenticated user.
class DeviceService extends ApiService {
  /// The platform string expected by the backend ('ios' or 'android').
  static String get _platform => Platform.isIOS ? 'ios' : 'android';

  /// Register (or refresh) the FCM token for the current user.
  Future<void> registerToken(String token) async {
    await post<void>(
      ApiConfig.deviceTokenEndpoint,
      data: {'token': token, 'platform': _platform},
      parser: (_) {},
    );
  }

  /// Deactivate the FCM token (e.g. on logout).
  Future<void> removeToken(String token) async {
    await delete<void>(
      ApiConfig.deviceTokenEndpoint,
      data: {'token': token},
      parser: (_) {},
    );
  }
}

final deviceService = DeviceService();
