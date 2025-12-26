import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/services/auth_service.dart';
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

  AuthNotifier(this._authService) : super(AuthState()) {
    // Load user if authenticated on init
    _loadCurrentUser();
  }

  /// Load current user from token
  Future<void> _loadCurrentUser() async {
    final isAuthenticated = await TokenManager.isAuthenticated();
    if (isAuthenticated) {
      try {
        final user = await _authService.getCurrentUser();
        state = state.copyWith(user: user);
      } catch (e) {
        // If token is invalid, clear it
        await TokenManager.clearToken();
      }
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

  /// Register new user
  Future<void> register({
    required String fullName,
    required String email,
    String? phone,
    required String password,
    UserRole role = UserRole.client,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _authService.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        role: role,
      );

      state = state.copyWith(
        user: response.user,
        isLoading: false,
        error: null,
      );
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
    try {
      await _authService.logout();
    } catch (e) {
      // Even if logout fails, clear local state
    } finally {
      state = AuthState();
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

