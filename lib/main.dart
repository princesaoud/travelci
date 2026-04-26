import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:travelci/core/providers/notification_provider.dart';
import 'package:travelci/core/router/app_router.dart';
import 'package:travelci/firebase_options.dart';

/// Called when a FCM message arrives while the app is terminated or in background.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // flutter_local_notifications will display the notification automatically
  // via the FCM system tray on Android; iOS handles it natively.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FlutterError.onError = (details) {
    developer.log(
      details.exceptionAsString(),
      name: 'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log(
      error.toString(),
      name: 'PlatformError',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  await initializeDateFormatting('fr', null);

  runApp(
    const ProviderScope(
      child: SOMOApp(),
    ),
  );
}

class SOMOApp extends ConsumerWidget {
  const SOMOApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Wire FCM / local notification tap → deep-link via GoRouter
    final service = ref.read(notificationServiceProvider);
    service.onNotificationTap = (payload) {
      if (payload == null || payload.isEmpty) return;
      final route = payload.startsWith('/') ? payload : '/$payload';
      router.go(route);
    };

    return MaterialApp.router(
      title: 'SOMO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: const Color(0xFFD32F2F), // Vibrant red
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFD32F2F), // For Material 3 buttons
          onPrimaryContainer: Colors.white,
          secondary: const Color(0xFF1976D2), // Vibrant blue
          onSecondary: Colors.white,
          error: const Color(0xFFD32F2F),
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black87,
          outline: Colors.grey,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        // Button themes to ensure buttons are visible
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F), // Primary red
            foregroundColor: Colors.white, // White text
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFD32F2F), // Primary red text
            side: const BorderSide(color: Color(0xFFD32F2F)), // Primary red border
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFD32F2F), // Primary red text
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
