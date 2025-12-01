import 'package:travelci/core/models/booking.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/models/user.dart';
import 'package:uuid/uuid.dart';

class MockDataService {
  static final _uuid = const Uuid();

  // Mock users
  static final List<User> mockUsers = [
    User(
      id: _uuid.v4(),
      fullName: 'Jean Kouassi',
      email: 'client@example.com',
      phone: '+225 07 12 34 56 78',
      role: UserRole.client,
      isVerified: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    User(
      id: _uuid.v4(),
      fullName: 'Marie Diabaté',
      email: 'owner@example.com',
      phone: '+225 05 98 76 54 32',
      role: UserRole.owner,
      isVerified: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
  ];

  // Mock properties in Abidjan
  static final List<Property> mockProperties = [
    Property(
      id: _uuid.v4(),
      ownerId: mockUsers[1].id,
      title: 'Appartement moderne à Cocody',
      description:
          'Magnifique appartement de 3 chambres, entièrement meublé, avec vue sur la lagune. Proche des commodités et des transports.',
      type: PropertyType.apartment,
      furnished: true,
      pricePerNight: 25000,
      address: 'Rue des Jardins, Cocody',
      city: 'Abidjan',
      latitude: 5.3364,
      longitude: -4.0267,
      imageUrls: [
        'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800',
        'https://images.unsplash.com/photo-1502672260256-1c1ef2d93688?w=800',
      ],
      amenities: ['WiFi', 'Climatisation', 'Parking', 'Cuisine équipée'],
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    Property(
      id: _uuid.v4(),
      ownerId: mockUsers[1].id,
      title: 'Villa luxueuse à Yopougon',
      description:
          'Superbe villa avec piscine, jardin et terrasse. Idéale pour les familles. 4 chambres, 3 salles de bain.',
      type: PropertyType.villa,
      furnished: true,
      pricePerNight: 75000,
      address: 'Boulevard de la Paix, Yopougon',
      city: 'Abidjan',
      latitude: 5.3167,
      longitude: -4.3667,
      imageUrls: [
        'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800',
        'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800',
      ],
      amenities: [
        'WiFi',
        'Climatisation',
        'Parking',
        'Piscine',
        'Jardin',
        'Cuisine équipée',
        'TV',
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    Property(
      id: _uuid.v4(),
      ownerId: mockUsers[1].id,
      title: 'Studio cosy à Marcory',
      description:
          'Studio bien aménagé, proche de la plage et du centre-ville. Parfait pour un séjour court.',
      type: PropertyType.apartment,
      furnished: true,
      pricePerNight: 15000,
      address: 'Avenue Franchet d\'Esperey, Marcory',
      city: 'Abidjan',
      latitude: 5.2833,
      longitude: -4.0167,
      imageUrls: [
        'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?w=800',
      ],
      amenities: ['WiFi', 'Climatisation', 'Parking'],
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    Property(
      id: _uuid.v4(),
      ownerId: mockUsers[1].id,
      title: 'Appartement 2 chambres à Plateau',
      description:
          'Appartement spacieux au cœur du Plateau, quartier d\'affaires. Vue panoramique sur la ville.',
      type: PropertyType.apartment,
      furnished: false,
      pricePerNight: 30000,
      address: 'Boulevard de la République, Plateau',
      city: 'Abidjan',
      latitude: 5.3197,
      longitude: -4.0267,
      imageUrls: [
        'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800',
      ],
      amenities: ['WiFi', 'Climatisation', 'Parking', 'Ascenseur'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Property(
      id: _uuid.v4(),
      ownerId: mockUsers[1].id,
      title: 'Villa avec jardin à Riviera',
      description:
          'Charmante villa avec grand jardin, idéale pour se détendre. 3 chambres, proche des plages.',
      type: PropertyType.villa,
      furnished: true,
      pricePerNight: 60000,
      address: 'Riviera 2, Cocody',
      city: 'Abidjan',
      latitude: 5.3500,
      longitude: -4.0500,
      imageUrls: [
        'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800',
      ],
      amenities: [
        'WiFi',
        'Climatisation',
        'Parking',
        'Jardin',
        'Cuisine équipée',
        'TV',
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
  ];

  // Mock bookings
  static List<Booking> getMockBookings(String userId, UserRole role) {
    if (role == UserRole.client) {
      return [
        Booking(
          id: _uuid.v4(),
          propertyId: mockProperties[0].id,
          clientId: userId,
          startDate: DateTime.now().add(const Duration(days: 5)),
          endDate: DateTime.now().add(const Duration(days: 8)),
          nights: 3,
          guests: 2,
          message: 'Séjour professionnel',
          totalPrice: 75000,
          status: BookingStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        Booking(
          id: _uuid.v4(),
          propertyId: mockProperties[1].id,
          clientId: userId,
          startDate: DateTime.now().subtract(const Duration(days: 10)),
          endDate: DateTime.now().subtract(const Duration(days: 7)),
          nights: 3,
          guests: 4,
          message: 'Vacances en famille',
          totalPrice: 225000,
          status: BookingStatus.accepted,
          createdAt: DateTime.now().subtract(const Duration(days: 15)),
        ),
      ];
    } else {
      // Owner bookings
      return [
        Booking(
          id: _uuid.v4(),
          propertyId: mockProperties[0].id,
          clientId: mockUsers[0].id,
          startDate: DateTime.now().add(const Duration(days: 5)),
          endDate: DateTime.now().add(const Duration(days: 8)),
          nights: 3,
          guests: 2,
          message: 'Séjour professionnel',
          totalPrice: 75000,
          status: BookingStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
    }
  }
}

