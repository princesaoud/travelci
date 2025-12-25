import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:travelci/core/models/booking.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/booking_provider.dart';
import 'package:travelci/core/providers/property_provider.dart';
import 'package:travelci/core/services/mock_data_service.dart';

class OwnerChatScreen extends ConsumerStatefulWidget {
  final String? clientId;
  final String? bookingId;

  const OwnerChatScreen({
    super.key,
    this.clientId,
    this.bookingId,
  });

  @override
  ConsumerState<OwnerChatScreen> createState() => _OwnerChatScreenState();
}

class _OwnerChatScreenState extends ConsumerState<OwnerChatScreen> {
  final TextEditingController _messageController = TextEditingController();
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
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getChatList() {
    final bookings = ref.watch(bookingProvider).bookings;
    final properties = ref.watch(propertyProvider).properties;
    final owner = ref.watch(authProvider).user;
    
    if (owner == null) return [];

    final ownerProperties = properties.where((p) => p.ownerId == owner.id).toList();
    final ownerBookings = bookings.where((booking) {
      return ownerProperties.any((p) => p.id == booking.propertyId);
    }).toList();

    // Group bookings by client
    final Map<String, Map<String, dynamic>> chatMap = {};
    
    for (final booking in ownerBookings) {
      final property = ownerProperties.firstWhere((p) => p.id == booking.propertyId);
      final client = MockDataService.mockUsers.firstWhere(
        (u) => u.id == booking.clientId,
        orElse: () => User(
          id: booking.clientId,
          fullName: 'Client',
          email: 'client@example.com',
          phone: '',
          role: UserRole.client,
          isVerified: false,
          createdAt: DateTime.now(),
        ),
      );

      if (!chatMap.containsKey(booking.clientId)) {
        chatMap[booking.clientId] = {
          'client': client,
          'bookings': <Booking>[],
          'properties': <Property>[],
        };
      }
      
      chatMap[booking.clientId]!['bookings'].add(booking);
      if (!chatMap[booking.clientId]!['properties'].any((p) => p.id == property.id)) {
        chatMap[booking.clientId]!['properties'].add(property);
      }
    }

    return chatMap.values.toList();
  }

  List<Map<String, dynamic>> _filterChats(List<Map<String, dynamic>> chats) {
    if (_searchQuery.isEmpty) return chats;

    return chats.where((chat) {
      final client = chat['client'] as User;
      final properties = chat['properties'] as List<Property>;
      
      return client.fullName.toLowerCase().contains(_searchQuery) ||
          client.email.toLowerCase().contains(_searchQuery) ||
          properties.any((p) => p.title.toLowerCase().contains(_searchQuery) ||
                              p.city.toLowerCase().contains(_searchQuery));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chats = _getChatList();
    final filteredChats = _filterChats(chats);

    if (widget.clientId != null && widget.bookingId != null) {
      // Show chat detail for specific client
      return _ChatDetailView(
        clientId: widget.clientId!,
        bookingId: widget.bookingId!,
        messageController: _messageController,
      );
    }

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
                hintText: 'Rechercher un client...',
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
          // Chat list
          Expanded(
            child: filteredChats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off : Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Aucun client trouvé'
                              : 'Aucun message',
                          style: TextStyle(color: Colors.grey[600], fontSize: 18),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredChats.length,
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      final client = chat['client'] as User;
                      final bookings = chat['bookings'] as List<Booking>;
                      final properties = chat['properties'] as List<Property>;
                      final latestBooking = bookings.first;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              client.fullName[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            client.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${properties.length} logement${properties.length > 1 ? 's' : ''}'),
                              Text(
                                '${bookings.length} réservation${bookings.length > 1 ? 's' : ''}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: const Icon(FontAwesomeIcons.chevronRight),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OwnerChatScreen(
                                  clientId: client.id,
                                  bookingId: latestBooking.id,
                                ),
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

class _ChatDetailView extends ConsumerWidget {
  final String clientId;
  final String bookingId;
  final TextEditingController messageController;

  const _ChatDetailView({
    required this.clientId,
    required this.bookingId,
    required this.messageController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider.notifier).getBookingById(bookingId);
    final properties = ref.watch(propertyProvider).properties;
    final client = MockDataService.mockUsers.firstWhere(
      (u) => u.id == clientId,
      orElse: () => User(
        id: clientId,
        fullName: 'Client',
        email: 'client@example.com',
        phone: '',
        role: UserRole.client,
        isVerified: false,
        createdAt: DateTime.now(),
      ),
    );

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('Réservation non trouvée')),
      );
    }

    final property = properties.firstWhere((p) => p.id == booking.propertyId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(client.fullName),
            Text(
              property.title,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Booking info card
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Réservation: ${property.title}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Dates: ${booking.startDate.day}/${booking.startDate.month}/${booking.startDate.year} - ${booking.endDate.day}/${booking.endDate.month}/${booking.endDate.year}'),
                if (booking.message != null && booking.message!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Message: ${booking.message}'),
                ],
              ],
            ),
          ),
          // Messages area (placeholder - in real app, implement actual chat)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FontAwesomeIcons.comments, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Fonctionnalité de chat en cours de développement',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vous pouvez contacter le client via: ${client.email}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          // Message input (placeholder)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Tapez un message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(FontAwesomeIcons.paperPlane),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fonctionnalité de chat en cours de développement'),
                      ),
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
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

