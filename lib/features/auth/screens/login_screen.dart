import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/utils/token_manager.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _hasShownSuccessMessage = false;
  String? _lastShownError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      developer.log('Login form validation failed');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    developer.log('Attempting login for: $email');

    // Reset flags
    _hasShownSuccessMessage = false;
    _lastShownError = null;
    
    // Clear any existing session before attempting new login
    if (!mounted) return;
    final currentAuthState = ref.read(authProvider);
    if (currentAuthState.user != null) {
      developer.log('User already logged in, logging out first');
      if (!mounted) return;
      await ref.read(authProvider.notifier).logout();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    final hasToken = await TokenManager.isAuthenticated();
    if (hasToken) {
      developer.log('Token still exists, clearing it');
      await TokenManager.clearToken();
    }

    try {
      developer.log('Calling login API...');
      // Just trigger login - the listener in build() will handle showing messages
      if (!mounted) return;
      await ref.read(authProvider.notifier).login(email, password);
      developer.log('Login API call completed');
      // Don't try to read state here - let the listener handle it
    } catch (e, stackTrace) {
      developer.log('Login exception: $e', error: e, stackTrace: stackTrace);
      // Only show error if widget is still mounted
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen to auth state changes - this handles errors that might occur asynchronously
    ref.listen<AuthState>(authProvider, (previous, next) {
      // Handle successful login - ONLY redirect if user is set AND no error
      if (next.user != null && 
          previous?.user == null && 
          !next.isLoading && 
          next.error == null &&
          !_hasShownSuccessMessage) {
        // User successfully logged in
        developer.log('Login successful detected in listener for: ${next.user?.email}, Role: ${next.user?.role}');
        
        // Mark that we've shown the message to prevent duplicate
        _hasShownSuccessMessage = true;
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connexion réussie ! Bienvenue ${next.user?.fullName ?? ""}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
        
        // The router will handle the redirect automatically via redirect logic
        // We just need to wait a bit for the success message to be visible
        // The router's redirect function will redirect to '/' when user is authenticated
        developer.log('Login successful - router will handle redirect automatically');
      }
      // Handle errors - only show if it's a new error and we haven't shown it yet
      // IMPORTANT: Do NOT redirect on error
      else if (next.error != null && 
               previous?.error != next.error && 
               !next.isLoading &&
               _lastShownError != next.error) {
        // Show error message
        developer.log('Login error detected in listener: ${next.error}');
        _lastShownError = next.error;
        
        // Reset success message flag since login failed
        _hasShownSuccessMessage = false;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        // NO REDIRECTION - user stays on login page
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const SizedBox(height: 60),
                const Text(
                  'Bienvenue',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Connectez-vous à votre compte',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !authState.isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(FontAwesomeIcons.envelope),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre email';
                    }
                    if (!value.contains('@')) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !authState.isLoading,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(FontAwesomeIcons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: authState.isLoading
                          ? null
                          : () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre mot de passe';
                    }
                    if (value.length < 6) {
                      return 'Le mot de passe doit contenir au moins 6 caractères';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: authState.isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Connexion en cours...',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        )
                      : const Text(
                          'Se connecter',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: authState.isLoading
                      ? null
                      : () {
                          context.push('/register');
                        },
                  child: const Text('Pas encore de compte ? S\'inscrire'),
                ),
                const SizedBox(height: 24),
                // Guest button
                OutlinedButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () {
                          context.go('/');
                        },
                  icon: const Icon(FontAwesomeIcons.userGroup),
                  label: const Text('Continuer en tant qu\'invité'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                // Quick login buttons for demo
                const Divider(),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () {
                          _emailController.text = 'john@example.com';
                          _passwordController.text = 'password123';
                        },
                  icon: const Icon(FontAwesomeIcons.user),
                  label: const Text('Remplir client'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () {
                          _emailController.text = 'jane@example.com';
                          _passwordController.text = 'password123';
                        },
                  icon: const Icon(FontAwesomeIcons.building),
                  label: const Text('Remplir propriétaire'),
                ),
                  ],
                ),
              ),
            ),
          ),
          // Loading overlay
          if (authState.isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Connexion en cours...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

