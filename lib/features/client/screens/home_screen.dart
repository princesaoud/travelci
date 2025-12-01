import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/property_provider.dart';
import 'package:travelci/core/utils/currency_formatter.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchCity = 'Abidjan';
  PropertyType? _selectedType;
  bool? _furnished;

  @override
  Widget build(BuildContext context) {
    final filteredProperties = ref.read(propertyProvider.notifier).searchProperties(
          city: _searchCity,
          type: _selectedType,
          furnished: _furnished,
        );

    final user = ref.watch(authProvider).user;
    final isGuest = user == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TravelCI'),
        actions: [
          if (isGuest)
            TextButton.icon(
              onPressed: () {
                context.push('/login');
              },
              icon: const Icon(FontAwesomeIcons.rightToBracket),
              label: const Text('Connexion'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          else
            IconButton(
              icon: const Icon(FontAwesomeIcons.user),
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/');
              },
              tooltip: 'Déconnexion',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher une ville (ex: Abidjan)',
                    prefixIcon: const Icon(FontAwesomeIcons.magnifyingGlass),
                    suffixIcon: IconButton(
                      icon: const Icon(FontAwesomeIcons.sliders),
                      onPressed: () {
                        context.push('/search');
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchCity = value.isEmpty ? 'Abidjan' : value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Quick filters
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: const Text('Appartement'),
                        selected: _selectedType == PropertyType.apartment,
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = selected ? PropertyType.apartment : null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilterChip(
                        label: const Text('Villa'),
                        selected: _selectedType == PropertyType.villa,
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = selected ? PropertyType.villa : null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Meublé'),
                      selected: _furnished == true,
                      onSelected: (selected) {
                        setState(() {
                          _furnished = selected ? true : null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Properties list
          Expanded(
            child: filteredProperties.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FontAwesomeIcons.magnifyingGlass, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun logement trouvé',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredProperties.length,
                    itemBuilder: (context, index) {
                      final property = filteredProperties[index];
                      return _PropertyCard(property: property);
                    },
                  ),
          ),
        ],
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/property/${property.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: property.imageUrls.isNotEmpty
                  ? Image.network(
                      property.imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(FontAwesomeIcons.image, size: 48),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(FontAwesomeIcons.image, size: 48),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: property.type == PropertyType.apartment
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                              : Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          property.type == PropertyType.apartment
                              ? 'Appartement'
                              : 'Villa',
                          style: TextStyle(
                            fontSize: 12,
                            color: property.type == PropertyType.apartment
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(FontAwesomeIcons.locationDot, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${property.city}, ${property.address}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: property.amenities.take(3).map((amenity) {
                      return Chip(
                        label: Text(amenity),
                        labelStyle: const TextStyle(fontSize: 12),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        CurrencyFormatter.formatXOF(property.pricePerNight),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        '/nuit',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

