import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/services/auth_service.dart';
import 'package:travelci/core/services/device_service.dart';
import 'package:travelci/core/services/notification_service.dart';
import 'package:travelci/core/utils/token_manager.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final NotificationService _notificationService = NotificationService();

  /// The FCM token currently registered with the backend (so we can deactivate it on logout).
  String? _registeredFcmToken;
  StreamSubscription<String>? _tokenRefreshSub;

  AuthNotifier(this._authService) : super(AuthState()) {
    // Re-register the device whenever FCM rotates the token (only while logged in).
    _tokenRefreshSub = _notificationService.onTokenRefresh.listen((token) {
      if (state.user != null) {
        _registerDevice(token);
      }
    });
    // Load user if authenticated on init
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  /// Load current user from token
  Future<void> _loadCurrentUser() async {
    final isAuthenticated = await TokenManager.isAuthenticated();
    if (isAuthenticated) {
      try {
        final user = await _authService.getCurrentUser();
        state = state.copyWith(user: user);
        _registerDevice();
      } catch (e) {
        // If token is invalid, clear it
        await TokenManager.clearToken();
      }
    }
  }

  /// Send this device's FCM token to the backend so the user can receive push
  /// notifications. Never throws — notification failures must not break auth.
  Future<void> _registerDevice([String? knownToken]) async {
    try {
      await _notificationService.initialize();
      final token = knownToken ?? await _notificationService.getFCMToken();
      if (token == null || token.isEmpty) return;
      await deviceService.registerToken(token);
      _registeredFcmToken = token;
    } catch (e) {
      developer.log('FCM token registration failed: $e', name: 'AuthNotifier');
    }
  }

  /// Deactivate this device's FCM token on the backend (best-effort, on logout).
  Future<void> _unregisterDevice() async {
    final token = _registeredFcmToken;
    if (token == null || token.isEmpty) return;
    try {
      await deviceService.removeToken(token);
    } catch (e) {
      developer.log('FCM token removal failed: $e', name: 'AuthNotifier');
    } finally {
      _registeredFcmToken = null;
    }
  }

  /// Login user
  /// Returns true if login successful, false otherwise
  Future<bool> login(String email, String password) async {
    // Clear any existing user and errors before attempting login
    state = state.copyWith(
      isLoading: true,
      error: null,
      user: null, // Clear previous user
    );

    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );

      state = state.copyWith(
        user: response.user,
        isLoading: false,
        error: null,
      );
      // Register this device for push notifications now that we're authenticated.
      _registerDevice();
      // Debug: Log user role after login
      developer.log('Login successful - User: ${response.user.email}, Role: ${response.user.role}');
      return true;
    } catch (e) {
      // Ensure user is null on error
      final errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
      state = state.copyWith(
        user: null,
        isLoading: false,
        error: errorMessage,
      );
      return false;
    }
  }

  /// Register new user. For owner role, optional national ID images can be provided.
  Future<void> register({
    required String fullName,
    required String email,
    String? phone,
    required String password,
    UserRole role = UserRole.client,
    File? nationalIdFront,
    File? nationalIdBack,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authService.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        role: role,
        nationalIdFront: nationalIdFront,
        nationalIdBack: nationalIdBack,
      );

      state = state.copyWith(
        user: response.user,
        isLoading: false,
        error: null,
      );
      // Register this device for push notifications now that we're authenticated.
      _registerDevice();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Logout user
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    // Deactivate the push token before the auth token is cleared.
    await _unregisterDevice();
    try {
      await _authService.logout();
    } catch (e) {
      // Even if logout fails, clear local state
    } finally {
      state = AuthState();
    }
  }

  /// Update the current user's profile (name, phone, avatar). Throws on failure
  /// so the UI can show an error message.
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    File? avatar,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updated = await _authService.updateProfile(
        fullName: fullName,
        phone: phone,
        avatar: avatar,
      );
      state = state.copyWith(user: updated, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Refresh current user data
  Future<void> refreshUser() async {
    try {
      final user = await _authService.getCurrentUser();
      state = state.copyWith(user: user);
    } catch (e) {
      // If refresh fails, user might be logged out
      state = AuthState();
    }
  }
}

// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Provider for AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

