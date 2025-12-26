import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:travelci/core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize French locale for date formatting
  await initializeDateFormatting('fr', null);

  runApp(
    const ProviderScope(
      child: TravelCIApp(),
    ),
  );
}

class TravelCIApp extends ConsumerWidget {
  const TravelCIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'TravelCI',
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
