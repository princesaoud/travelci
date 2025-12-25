import 'package:equatable/equatable.dart';

enum PropertyType { apartment, villa }

extension PropertyTypeExtension on PropertyType {
  String get value {
    switch (this) {
      case PropertyType.apartment:
        return 'apartment';
      case PropertyType.villa:
        return 'villa';
    }
  }

  static PropertyType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'apartment':
        return PropertyType.apartment;
      case 'villa':
        return PropertyType.villa;
      default:
        return PropertyType.apartment;
    }
  }
}

class Property extends Equatable {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final PropertyType type;
  final bool furnished;
  final int pricePerNight; // XOF - stored as int for precision
  final String address;
  final String city;
  final double? latitude;
  final double? longitude;
  final List<String> imageUrls;
  final List<String> amenities;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Property({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    required this.type,
    required this.furnished,
    required this.pricePerNight,
    required this.address,
    required this.city,
    this.latitude,
    this.longitude,
    required this.imageUrls,
    required this.amenities,
    required this.createdAt,
    this.updatedAt,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    // Handle both single property object and nested property object
    final data = json.containsKey('property') ? json['property'] as Map<String, dynamic> : json;

    return Property(
      id: data['id'] as String,
      ownerId: data['owner_id'] as String? ?? data['ownerId'] as String,
      title: data['title'] as String,
      description: data['description'] as String?,
      type: PropertyTypeExtension.fromString(
        data['type'] as String? ?? 'apartment',
      ),
      furnished: data['furnished'] as bool? ?? false,
      pricePerNight: (data['price_per_night'] as num? ?? data['pricePerNight'] as num? ?? 0).toInt(),
      address: data['address'] as String,
      city: data['city'] as String,
      latitude: data['latitude'] != null ? (data['latitude'] as num).toDouble() : null,
      longitude: data['longitude'] != null ? (data['longitude'] as num).toDouble() : null,
      imageUrls: data['image_urls'] != null
          ? List<String>.from(data['image_urls'] as List)
          : data['imageUrls'] != null
              ? List<String>.from(data['imageUrls'] as List)
              : [],
      amenities: data['amenities'] != null
          ? List<String>.from(data['amenities'] as List)
          : [],
      createdAt: DateTime.parse(data['created_at'] as String? ?? data['createdAt'] as String),
      updatedAt: data['updated_at'] != null || data['updatedAt'] != null
          ? DateTime.parse(data['updated_at'] as String? ?? data['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'type': type.value,
      'furnished': furnished,
      'price_per_night': pricePerNight.toDouble(),
      'address': address,
      'city': city,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'amenities': amenities,
    };
  }

  @override
  List<Object?> get props => [
        id,
        ownerId,
        title,
        description,
        type,
        furnished,
        pricePerNight,
        address,
        city,
        latitude,
        longitude,
        imageUrls,
        amenities,
        createdAt,
        updatedAt,
      ];
}

