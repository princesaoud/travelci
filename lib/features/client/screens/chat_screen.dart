import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/property_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<Property>> _filterOwners(
    Map<String, List<Property>> ownerProperties,
  ) {
    if (_searchQuery.isEmpty) {
      return ownerProperties;
    }

    final filtered = <String, List<Property>>{};
    ownerProperties.forEach((ownerId, properties) {
      final firstProperty = properties.first;
      final matchesCity = firstProperty.city.toLowerCase().contains(_searchQuery);
      final matchesTitle = properties.any(
        (p) => p.title.toLowerCase().contains(_searchQuery),
      );
      
      if (matchesCity || matchesTitle) {
        filtered[ownerId] = properties;
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    
    // Redirect guests to login
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final properties = ref.watch(propertyProvider).properties;
    
    // Get unique owners from properties
    final ownerProperties = <String, List<Property>>{};
    for (final property in properties) {
      if (!ownerProperties.containsKey(property.ownerId)) {
        ownerProperties[property.ownerId] = [];
      }
      ownerProperties[property.ownerId]!.add(property);
    }

    final filteredOwners = _filterOwners(ownerProperties);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par ville ou logement...',
                prefixIcon: const Icon(FontAwesomeIcons.magnifyingGlass),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(FontAwesomeIcons.xmark),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          // Messages list
          Expanded(
            child: filteredOwners.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? FontAwesomeIcons.magnifyingGlass : FontAwesomeIcons.comments,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Aucun propriétaire trouvé'
                              : 'Aucun message',
                          style: TextStyle(color: Colors.grey[600], fontSize: 18),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            child: const Text('Effacer la recherche'),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Text(
                            'Contactez les propriétaires de vos réservations',
                            style: TextStyle(color: Colors.grey[500], fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredOwners.length,
                    itemBuilder: (context, index) {
                      final ownerId = filteredOwners.keys.elementAt(index);
                      final ownerProps = filteredOwners[ownerId]!;
                      final firstProperty = ownerProps.first;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: const Icon(FontAwesomeIcons.user, color: Colors.white),
                          ),
                          title: Text(
                            'Propriétaire - ${firstProperty.city}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${ownerProps.length} logement${ownerProps.length > 1 ? 's' : ''} disponible${ownerProps.length > 1 ? 's' : ''}',
                          ),
                          trailing: const Icon(FontAwesomeIcons.chevronRight),
                          onTap: () {
                            // TODO: Navigate to chat detail with owner
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fonctionnalité de chat en cours de développement'),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

