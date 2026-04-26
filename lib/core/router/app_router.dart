import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import 'package:travelci/features/shared/screens/conversations_list_screen.dart';
import 'package:travelci/features/shared/screens/chat_detail_screen.dart';
import 'package:travelci/core/models/conversation.dart';
import 'package:travelci/features/client/screens/client_navigation_wrapper.dart';
import 'package:travelci/features/owner/screens/booking_requests_screen.dart';
import 'package:travelci/features/owner/screens/dashboard_screen.dart';
import 'package:travelci/features/owner/screens/property_form_screen.dart';
import 'package:travelci/features/owner/screens/property_availability_screen.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/features/shared/screens/notifications_screen.dart';

/// Notifier used to re-run router redirect when auth changes, without recreating the router.
/// This keeps the navigation stack (e.g. Disponibilité, edit view) from closing when /me runs.
class _RouterRefreshNotifier extends ChangeNotifier {}

final _routerRefreshNotifier = _RouterRefreshNotifier();

final routerProvider = Provider<GoRouter>((ref) {
  // Only auth is listened to. Property/booking API calls never recreate the router or close child screens.
  ref.listen(authProvider, (_, __) {
    _routerRefreshNotifier.notifyListeners();
  });

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _routerRefreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
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

      if (!isAuthenticated && requiresAuthRoute && !isLoginRoute) {
        return '/login';
      }
      if (isAuthenticated && isLoginRoute && authState.error == null && !authState.isLoading) {
        return '/';
      }
      if (isLoginRoute && authState.error != null) {
        return null;
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
      ShellRoute(
        builder: (context, state, child) {
          return Consumer(
            builder: (context, ref, _) {
              final user = ref.watch(authProvider).user;
              if (user?.role == UserRole.owner) {
                return child;
              }
              int index = 0;
              final location = state.matchedLocation;
              if (location == '/') index = 0;
              else if (location == '/bookings') index = 1;
              else if (location == '/chat') index = 2;
              return ClientNavigationWrapper(
                initialIndex: index,
                child: child,
              );
            },
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              return Consumer(
                builder: (context, ref, _) {
                  final user = ref.watch(authProvider).user;
                  if (user?.role == UserRole.owner) {
                    return const OwnerDashboardScreen();
                  }
                  return const HomeScreen();
                },
              );
            },
          ),
          GoRoute(
            path: '/bookings',
            builder: (context, state) {
              return Consumer(
                builder: (context, ref, _) {
                  if (ref.watch(authProvider).user == null) {
                    return const HomeScreen();
                  }
                  return const MyBookingsScreen();
                },
              );
            },
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) {
              return Consumer(
                builder: (context, ref, _) {
                  if (ref.watch(authProvider).user == null) {
                    return const HomeScreen();
                  }
                  return const ConversationsListScreen();
                },
              );
            },
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) {
              return Consumer(
                builder: (context, ref, _) {
                  if (ref.watch(authProvider).user == null) {
                    return const HomeScreen();
                  }
                  final conversation = state.extra as Conversation?;
                  if (conversation == null) {
                    return const ConversationsListScreen();
                  }
                  return ChatDetailScreen(conversation: conversation);
                },
              );
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
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/booking/:id',
        builder: (context, state) {
          return Consumer(
            builder: (context, ref, _) {
              final user = ref.watch(authProvider).user;
              if (user == null) return const HomeScreen();
              if (user.role == UserRole.owner) {
                return const BookingRequestsScreen();
              }
              return const MyBookingsScreen();
            },
          );
        },
      ),
      GoRoute(
        path: '/owner/property/:id/availability',
        builder: (context, state) {
          final property = state.extra as Property?;
          if (property == null) {
            return const Scaffold(
              body: Center(child: Text('Logement introuvable')),
            );
          }
          return PropertyAvailabilityScreen(property: property);
        },
      ),
    ],
  );
});

