import 'package:equatable/equatable.dart';

enum PropertyType { apartment, villa }

class Property extends Equatable {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final PropertyType type;
  final bool furnished;
  final int pricePerNight; // XOF
  final String address;
  final String city;
  final double? latitude;
  final double? longitude;
  final List<String> imageUrls;
  final List<String> amenities;
  final DateTime createdAt;

  const Property({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
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
  });

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
      ];
}

