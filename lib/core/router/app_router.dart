import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/features/auth/screens/login_screen.dart';
import 'package:travelci/features/auth/screens/register_screen.dart';
import 'package:travelci/features/client/screens/home_screen.dart';
import 'package:travelci/features/client/screens/my_bookings_screen.dart';
import 'package:travelci/features/client/screens/property_detail_screen.dart';
import 'package:travelci/features/client/screens/search_screen.dart';
import 'package:travelci/features/client/screens/chat_screen.dart';
import 'package:travelci/features/client/screens/client_navigation_wrapper.dart';
import 'package:travelci/features/owner/screens/booking_requests_screen.dart';
import 'package:travelci/features/owner/screens/dashboard_screen.dart';
import 'package:travelci/features/owner/screens/property_form_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState.user != null;
      final isLoginRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      
      // Routes that require authentication
      final requiresAuth = [
        '/bookings',
        '/chat',
        '/owner/bookings',
        '/owner/property/new',
      ];
      final isOwnerRoute = state.matchedLocation.startsWith('/owner');
      final requiresAuthRoute = requiresAuth.contains(state.matchedLocation) || 
                                (isOwnerRoute && state.matchedLocation != '/owner');

      // Redirect to login if trying to access protected route without auth
      if (!isAuthenticated && requiresAuthRoute && !isLoginRoute) {
        return '/login';
      }

      // Redirect authenticated users away from login/register
      if (isAuthenticated && isLoginRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Client routes with bottom navigation (accessible to guests)
      ShellRoute(
        builder: (context, state, child) {
          final user = authState.user;
          if (user?.role == UserRole.owner) {
            return child;
          }
          
          // Determine index based on route
          int index = 0;
          final location = state.matchedLocation;
          if (location == '/') {
            index = 0;
          } else if (location == '/bookings') {
            index = 1;
          } else if (location == '/chat') {
            index = 2;
          }
          
          return ClientNavigationWrapper(
            initialIndex: index,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              final user = authState.user;
              if (user?.role == UserRole.owner) {
                return const OwnerDashboardScreen();
              }
              return const HomeScreen();
            },
          ),
          // Protected routes - require authentication
          GoRoute(
            path: '/bookings',
            builder: (context, state) {
              if (authState.user == null) {
                return const HomeScreen(); // Will redirect via redirect logic
              }
              return const MyBookingsScreen();
            },
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) {
              if (authState.user == null) {
                return const HomeScreen(); // Will redirect via redirect logic
              }
              return const ChatScreen();
            },
          ),
        ],
      ),
      // Client routes without bottom navigation (detail screens)
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/property/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PropertyDetailScreen(propertyId: id);
        },
      ),
      // Owner routes
      GoRoute(
        path: '/owner/bookings',
        builder: (context, state) => const BookingRequestsScreen(),
      ),
      GoRoute(
        path: '/owner/property/new',
        builder: (context, state) => const PropertyFormScreen(),
      ),
      GoRoute(
        path: '/owner/property/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PropertyFormScreen(propertyId: id);
        },
      ),
    ],
  );
});

