import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/services/mock_data_service.dart';

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
  AuthNotifier() : super(AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    try {
      // Mock authentication - in real app, call API
      final user = MockDataService.mockUsers.firstWhere(
        (u) => u.email == email,
        orElse: () => throw Exception('Utilisateur non trouvé'),
      );

      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Email ou mot de passe incorrect',
      );
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    try {
      // Mock registration - in real app, call API
      final newUser = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fullName: fullName,
        email: email,
        phone: phone,
        role: role,
        isVerified: false,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(user: newUser, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors de l\'inscription',
      );
    }
  }

  void logout() {
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

