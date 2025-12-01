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
          secondary: const Color(0xFF1976D2), // Vibrant blue
          onSecondary: Colors.white,
          error: const Color(0xFFD32F2F),
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardTheme(
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
      ),
      routerConfig: router,
    );
  }
}
