import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelci/core/models/api_response.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/services/property_service.dart';

class PropertyState {
  final List<Property> properties;
  final bool isLoading;
  final String? error;
  final PaginationInfo? pagination;
  final Map<String, Property> propertyCache; // Cache for individual properties

  const PropertyState({
    this.properties = const [],
    this.isLoading = false,
    this.error,
    this.pagination,
    this.propertyCache = const {},
  });

  PropertyState copyWith({
    List<Property>? properties,
    bool? isLoading,
    String? error,
    PaginationInfo? pagination,
    Map<String, Property>? propertyCache,
  }) {
    return PropertyState(
      properties: properties ?? this.properties,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pagination: pagination ?? this.pagination,
      propertyCache: propertyCache ?? this.propertyCache,
    );
  }

  // Helper method to merge property cache
  PropertyState copyWithMergedCache(Map<String, Property> newCache) {
    final mergedCache = Map<String, Property>.from(propertyCache);
    mergedCache.addAll(newCache);
    return copyWith(propertyCache: mergedCache);
  }
}

class PropertyNotifier extends StateNotifier<PropertyState> {
  final PropertyService _propertyService;

  PropertyNotifier(this._propertyService) : super(PropertyState()) {
    // Load properties on initialization
    loadProperties();
  }

  /// Load properties from API
  Future<void> loadProperties({
    String? city,
    PropertyType? type,
    bool? furnished,
    double? priceMin,
    double? priceMax,
    int page = 1,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _propertyService.getProperties(
        city: city,
        type: type,
        furnished: furnished,
        priceMin: priceMin,
        priceMax: priceMax,
        page: page,
        limit: 50, // Load more properties for better UX
      );

      final newCache = {
        for (var prop in response.properties) prop.id: prop,
      };
      state = state.copyWithMergedCache(newCache).copyWith(
        properties: response.properties,
        isLoading: false,
        pagination: response.pagination,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Search/filter properties (local filtering for immediate feedback)
  List<Property> searchProperties({
    String? city,
    PropertyType? type,
    bool? furnished,
    int? priceMin,
    int? priceMax,
  }) {
    var results = state.properties;

    if (city != null && city.isNotEmpty) {
      results = results
          .where((p) => p.city.toLowerCase().contains(city.toLowerCase()))
          .toList();
    }

    if (type != null) {
      results = results.where((p) => p.type == type).toList();
    }

    if (furnished != null) {
      results = results.where((p) => p.furnished == furnished).toList();
    }

    if (priceMin != null) {
      results = results.where((p) => p.pricePerNight >= priceMin).toList();
    }

    if (priceMax != null) {
      results = results.where((p) => p.pricePerNight <= priceMax).toList();
    }

    return results;
  }

  /// Get property by ID (check cache first, then fetch if needed)
  Property? getPropertyById(String id) {
    // Check cache first
    if (state.propertyCache.containsKey(id)) {
      return state.propertyCache[id];
    }

    // Check loaded properties
    try {
      return state.properties.firstWhere((p) => p.id == id);
    } catch (e) {
      // Property not in cache, will be fetched when needed
      return null;
    }
  }

  /// Fetch a single property by ID from API
  Future<Property?> fetchPropertyById(String id) async {
    try {
      final property = await _propertyService.getPropertyById(id);
      state = state.copyWithMergedCache({id: property});
      return property;
    } catch (e) {
      return null;
    }
  }

  /// Get properties by owner ID
  List<Property> getPropertiesByOwner(String ownerId) {
    return state.properties.where((p) => p.ownerId == ownerId).toList();
  }

  /// Create a new property
  Future<Property> createProperty({
    required String title,
    String? description,
    required PropertyType type,
    bool furnished = false,
    required double pricePerNight,
    required String address,
    required String city,
    double? latitude,
    double? longitude,
    List<String> amenities = const [],
    List<File>? images,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final property = await _propertyService.createProperty(
        title: title,
        description: description,
        type: type,
        furnished: furnished,
        pricePerNight: pricePerNight,
        address: address,
        city: city,
        latitude: latitude,
        longitude: longitude,
        amenities: amenities,
        images: images,
      );

      // Add to state
      final updatedProperties = [property, ...state.properties];
      state = state.copyWithMergedCache({property.id: property}).copyWith(
        properties: updatedProperties,
        isLoading: false,
        error: null,
      );

      return property;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Update a property
  Future<Property> updateProperty({
    required String id,
    String? title,
    String? description,
    PropertyType? type,
    bool? furnished,
    double? pricePerNight,
    String? address,
    String? city,
    double? latitude,
    double? longitude,
    List<String>? amenities,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final property = await _propertyService.updateProperty(
        id: id,
        title: title,
        description: description,
        type: type,
        furnished: furnished,
        pricePerNight: pricePerNight,
        address: address,
        city: city,
        latitude: latitude,
        longitude: longitude,
        amenities: amenities,
      );

      // Update in state
      final updatedProperties = state.properties
          .map((p) => p.id == id ? property : p)
          .toList();
      state = state.copyWithMergedCache({id: property}).copyWith(
        properties: updatedProperties,
        isLoading: false,
        error: null,
      );

      return property;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Delete a property
  Future<void> deleteProperty(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _propertyService.deleteProperty(id);

      // Remove from state
      final updatedProperties = state.properties.where((p) => p.id != id).toList();
      final updatedCache = Map<String, Property>.from(state.propertyCache);
      updatedCache.remove(id);

      state = state.copyWith(
        properties: updatedProperties,
        isLoading: false,
        propertyCache: updatedCache,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Refresh properties
  Future<void> refresh() async {
    await loadProperties();
  }
}

// Provider for PropertyService
final propertyServiceProvider = Provider<PropertyService>((ref) {
  return PropertyService();
});

// Provider for PropertyNotifier
final propertyProvider = StateNotifierProvider<PropertyNotifier, PropertyState>((ref) {
  final propertyService = ref.watch(propertyServiceProvider);
  return PropertyNotifier(propertyService);
});
