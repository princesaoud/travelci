import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/services/mock_data_service.dart';

class PropertyNotifier extends StateNotifier<List<Property>> {
  PropertyNotifier() : super(MockDataService.mockProperties);

  List<Property> searchProperties({
    String? city,
    PropertyType? type,
    bool? furnished,
    int? priceMin,
    int? priceMax,
  }) {
    var results = MockDataService.mockProperties;

    if (city != null && city.isNotEmpty) {
      results = results.where((p) => p.city.toLowerCase().contains(city.toLowerCase())).toList();
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

  Property? getPropertyById(String id) {
    try {
      return state.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Property> getPropertiesByOwner(String ownerId) {
    return state.where((p) => p.ownerId == ownerId).toList();
  }

  void addProperty(Property property) {
    state = [...state, property];
  }

  void updateProperty(Property property) {
    state = state.map((p) => p.id == property.id ? property : p).toList();
  }
}

final propertyProvider = StateNotifierProvider<PropertyNotifier, List<Property>>((ref) {
  return PropertyNotifier();
});

