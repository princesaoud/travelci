import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/providers/property_provider.dart';
import 'package:travelci/core/utils/currency_formatter.dart';
import 'package:travelci/core/utils/feedback.dart';

// Default center: Abidjan
const _defaultCenter = LatLng(5.3600, -4.0083);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  Position? _userPosition;
  Property? _selectedProperty;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fetchLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      setState(() => _userPosition = pos);
      if (_mapReady) {
        _mapController.move(
          LatLng(pos.latitude, pos.longitude),
          13.0,
        );
      }
    } catch (_) {}
  }

  void _onMarkerTap(Property property) {
    tapFeedback();
    setState(() => _selectedProperty = property);
    _mapController.move(
      LatLng(property.latitude!, property.longitude!),
      14.5,
    );
  }

  void _centerOnUser() {
    tapFeedback();
    if (_userPosition != null) {
      _mapController.move(
        LatLng(_userPosition!.latitude, _userPosition!.longitude),
        14.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final propertyState = ref.watch(propertyProvider);
    final properties = propertyState.properties
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();

    final colorScheme = Theme.of(context).colorScheme;
    final userLatLng = _userPosition != null
        ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
        : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Carte des logements',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${properties.length} logement${properties.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLatLng ?? _defaultCenter,
              initialZoom: 12.5,
              onMapReady: () {
                setState(() => _mapReady = true);
                if (_userPosition != null) {
                  _mapController.move(userLatLng!, 13.0);
                }
              },
              onTap: (_, __) => setState(() => _selectedProperty = null),
            ),
            children: [
              // Map tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.somo.app',
                maxZoom: 19,
              ),
              // User location
              if (userLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLatLng,
                      width: 64,
                      height: 64,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) => Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 48 * _pulseAnimation.value,
                              height: 48 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.primary
                                    .withValues(alpha: 0.2 * (1 - _pulseAnimation.value + 0.5)),
                              ),
                            ),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.primary,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              // Property markers
              MarkerLayer(
                markers: properties.map((property) {
                  final isSelected = _selectedProperty?.id == property.id;
                  return Marker(
                    point: LatLng(property.latitude!, property.longitude!),
                    width: 100,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _onMarkerTap(property),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? colorScheme.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isSelected ? 0.25 : 0.15),
                              blurRadius: isSelected ? 12 : 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          CurrencyFormatter.formatXOF(property.pricePerNight),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Center on user FAB
          Positioned(
            bottom: _selectedProperty != null ? 260 : 32,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'centerUser',
              backgroundColor: Colors.white,
              foregroundColor: colorScheme.primary,
              elevation: 4,
              onPressed: _centerOnUser,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Property bottom sheet
          if (_selectedProperty != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _PropertyBottomCard(
                property: _selectedProperty!,
                onClose: () => setState(() => _selectedProperty = null),
              ),
            ),
        ],
      ),
    );
  }
}

class _PropertyBottomCard extends StatelessWidget {
  final Property property;
  final VoidCallback onClose;

  const _PropertyBottomCard({required this.property, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: property.imageUrls.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: property.imageUrls.first,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: Icon(FontAwesomeIcons.image,
                                  color: Colors.grey[400]),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Icon(FontAwesomeIcons.image,
                                color: Colors.grey[400]),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              property.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: onClose,
                            child: Icon(Icons.close,
                                size: 20, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(FontAwesomeIcons.locationDot,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${property.city}, ${property.address}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          property.type == PropertyType.apartment
                              ? 'Appartement'
                              : 'Villa',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: CurrencyFormatter.formatXOF(
                                      property.pricePerNight),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                TextSpan(
                                  text: ' /nuit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () {
                              tapFeedback();
                              context.push('/property/${property.id}');
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Voir',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
