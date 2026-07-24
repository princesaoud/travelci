import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/property_provider.dart';
import 'package:travelci/core/providers/favorites_provider.dart';
import 'package:travelci/core/utils/currency_formatter.dart';
import 'package:travelci/core/utils/feedback.dart';
import 'package:travelci/features/shared/screens/profile_edit_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchCity = 'Abidjan';
  PropertyType? _selectedType;
  bool? _furnished;
  Position? _userLocation;
  String? _locationError;
  bool _locationChecked = false;

  Future<void> _fetchLocationThenLoadProperties() async {
    if (!mounted) return;
    ref.read(propertyProvider.notifier).loadProperties();

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      setState(() {
        _locationError = 'Localisation désactivée';
        _locationChecked = true;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever && mounted) {
      setState(() {
        _locationError = 'Accès à la position refusé';
        _locationChecked = true;
      });
      return;
    }
    if (permission == LocationPermission.denied && mounted) {
      setState(() {
        _locationError = null;
        _locationChecked = true;
      });
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (mounted) {
        setState(() {
          _userLocation = position;
          _locationError = null;
          _locationChecked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userLocation = null;
          _locationError = 'Position indisponible';
          _locationChecked = true;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchLocationThenLoadProperties();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch property state to get reactive updates
    final propertyState = ref.watch(propertyProvider);
    
    final filteredProperties = ref.read(propertyProvider.notifier).searchProperties(
          city: _searchCity,
          type: _selectedType,
          furnished: _furnished,
        );

    final user = ref.watch(authProvider).user;
    final isGuest = user == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOMO'),
        actions: [
          if (isGuest)
            TextButton.icon(
              onPressed: () {
                tapFeedback();
                context.push('/login');
              },
              icon: const Icon(FontAwesomeIcons.rightToBracket),
              label: const Text('Connexion'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(FontAwesomeIcons.user),
              tooltip: 'Compte',
              onSelected: (value) {
                tapFeedback();
                if (value == 'profile') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileEditScreen()));
                } else if (value == 'logout') {
                  ref.read(authProvider.notifier).logout();
                  context.go('/');
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(FontAwesomeIcons.penToSquare),
                    title: Text('Modifier le profil'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(FontAwesomeIcons.rightFromBracket),
                    title: Text('Déconnexion'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          tapFeedback();
          context.push('/map');
        },
        icon: const Icon(FontAwesomeIcons.map),
        label: const Text('Carte', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 4,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(propertyProvider.notifier).loadProperties(forceRefresh: true);
          _fetchLocationThenLoadProperties();
        },
        child: Column(
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
                          tapFeedback();
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
                            tapFeedback();
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
                            tapFeedback();
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
                          tapFeedback();
                          setState(() {
                            _furnished = selected ? true : null;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_userLocation != null && filteredProperties.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(FontAwesomeIcons.locationDot, size: 14, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Triés par proximité',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Properties list
            Expanded(
              child: propertyState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : filteredProperties.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height - 300,
                            child: Center(
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
                            ),
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
      ),
    );
  }
}

class _PropertyCard extends ConsumerWidget {
  final Property property;

  const _PropertyCard({required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref
            .watch(favoritesProvider)
            .valueOrNull
            ?.contains(property.id) ??
        false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          tapFeedback();
          context.push('/property/${property.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with heart overlay
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: property.imageUrls.isNotEmpty
                      ? Image.network(
                          property.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(FontAwesomeIcons.image,
                                  size: 48),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(FontAwesomeIcons.image, size: 48),
                        ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () {
                      tapFeedback();
                      ref
                          .read(favoritesProvider.notifier)
                          .toggleFavorite(property.id);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: isFav ? Colors.red : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
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
                      Expanded(
                        child: Text(
                          '${property.city}, ${property.address}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (property.roomCount != null)
                        Text(
                          property.roomCount == 1
                              ? 'Studio'
                              : '${property.roomCount} pièces',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
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

