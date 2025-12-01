import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/property_provider.dart';
import 'package:travelci/core/utils/currency_formatter.dart';
import 'package:travelci/features/owner/screens/owner_chat_screen.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final ownerProperties = user != null
        ? ref.read(propertyProvider.notifier).getPropertiesByOwner(user.id)
        : <Property>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.comments),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OwnerChatScreen(),
                ),
              );
            },
            tooltip: 'Messages',
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.bell),
            onPressed: () {
              context.push('/owner/bookings');
            },
            tooltip: 'Demandes de réservation',
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.user),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Mes logements',
                    value: '${ownerProperties.length}',
                    icon: FontAwesomeIcons.house,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Réservations',
                    value: '0',
                    icon: FontAwesomeIcons.bookmark,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          // Properties list
          Expanded(
            child: ownerProperties.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FontAwesomeIcons.house, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun logement',
                          style: TextStyle(color: Colors.grey[600], fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ajoutez votre premier logement',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: ownerProperties.length,
                    itemBuilder: (context, index) {
                      final property = ownerProperties[index];
                      return _PropertyCard(property: property);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/owner/property/new');
        },
        icon: const Icon(FontAwesomeIcons.plus),
        label: const Text('Ajouter un logement'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final Property property;

  const _PropertyCard({required this.property});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          context.push('/owner/property/${property.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (property.imageUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    property.imageUrls.first,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: const Icon(FontAwesomeIcons.image),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[300],
                  child: const Icon(FontAwesomeIcons.image),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${property.city}, ${property.address}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: property.type == PropertyType.apartment
                                ? Colors.blue[100]
                                : Colors.green[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            property.type == PropertyType.apartment
                                ? 'Appartement'
                                : 'Villa',
                            style: TextStyle(
                              fontSize: 12,
                              color: property.type == PropertyType.apartment
                                  ? Colors.blue[900]
                                  : Colors.green[900],
                            ),
                          ),
                        ),
                        if (property.furnished) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Meublé',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.formatXOF(property.pricePerNight),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(FontAwesomeIcons.pen),
                onPressed: () {
                  context.push('/owner/property/${property.id}');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

