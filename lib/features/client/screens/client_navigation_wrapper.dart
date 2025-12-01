import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:travelci/core/providers/auth_provider.dart';

class ClientNavigationWrapper extends ConsumerWidget {
  final int initialIndex;
  final Widget child;

  const ClientNavigationWrapper({
    super.key,
    this.initialIndex = 0,
    required this.child,
  });

  void _onItemTapped(BuildContext context, int index, bool isAuthenticated) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        if (isAuthenticated) {
          context.go('/bookings');
        } else {
          context.push('/login');
        }
        break;
      case 2:
        if (isAuthenticated) {
          context.go('/chat');
        } else {
          context.push('/login');
        }
        break;
    }
  }

  int _getCurrentIndex(String location) {
    if (location == '/') {
      return 0;
    } else if (location == '/bookings') {
      return 1;
    } else if (location == '/chat') {
      return 2;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(authProvider).user != null;
    // Determine current index based on route
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _getCurrentIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onItemTapped(context, index, isAuthenticated),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.house),
            label: 'Appartements',
          ),
          BottomNavigationBarItem(
            icon: const Icon(FontAwesomeIcons.bookmark),
            label: 'Réservations',
            tooltip: isAuthenticated ? null : 'Connexion requise',
          ),
          BottomNavigationBarItem(
            icon: const Icon(FontAwesomeIcons.comments),
            label: 'Messages',
            tooltip: isAuthenticated ? null : 'Connexion requise',
          ),
        ],
      ),
    );
  }
}

