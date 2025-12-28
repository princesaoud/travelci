import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:travelci/core/models/booking.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/booking_provider.dart';
import 'package:travelci/core/providers/property_provider.dart';
import 'package:travelci/core/providers/notification_provider.dart';
import 'package:travelci/core/utils/currency_formatter.dart';
import 'package:travelci/core/utils/date_formatter.dart';
import 'package:travelci/core/models/conversation.dart';
import 'package:travelci/core/providers/chat_provider.dart';
import 'package:travelci/features/shared/screens/chat_detail_screen.dart';
import 'package:travelci/features/shared/screens/conversations_list_screen.dart';

class BookingRequestsScreen extends ConsumerStatefulWidget {
  const BookingRequestsScreen({super.key});

  @override
  ConsumerState<BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends ConsumerState<BookingRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(bookingProvider.notifier).loadBookings(role: 'owner');
      }
    });
  }

  Future<void> _handleAccept(String bookingId) async {
    final reason = await _showReasonDialog(
      context: context,
      title: 'Accepter la réservation',
      hint: 'Message optionnel pour le client (ex: "Bienvenue ! Les clés seront disponibles à l\'arrivée.")',
    );
    
    try {
      final booking = await ref.read(bookingProvider.notifier).updateBookingStatus(
            id: bookingId,
            status: BookingStatus.accepted,
          );
      
      // Get property for notification
      final properties = ref.read(propertyProvider).properties;
      final property = properties.firstWhere(
        (p) => p.id == booking.propertyId,
        orElse: () => Property(
          id: '',
          ownerId: '',
          title: 'Logement',
          description: '',
          type: PropertyType.apartment,
          furnished: false,
          pricePerNight: 0,
          address: '',
          city: '',
          imageUrls: [],
          amenities: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Send notification to client
      await ref.read(notificationProvider.notifier).notifyBookingAccepted(
        bookingId: bookingId,
        propertyTitle: property.title,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(reason != null && reason.isNotEmpty 
              ? 'Réservation acceptée avec message' 
              : 'Réservation acceptée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleDecline(String bookingId) async {
    final reason = await _showReasonDialog(
      context: context,
      title: 'Refuser la réservation',
      hint: 'Motif du refus (obligatoire)',
      isRequired: true,
    );
    
    if (reason == null || reason.isEmpty) {
      return; // User cancelled or didn't provide reason
    }
    
    try {
      final booking = await ref.read(bookingProvider.notifier).updateBookingStatus(
            id: bookingId,
            status: BookingStatus.declined,
          );
      
      // Get property for notification
      final properties = ref.read(propertyProvider).properties;
      final property = properties.firstWhere(
        (p) => p.id == booking.propertyId,
        orElse: () => Property(
          id: '',
          ownerId: '',
          title: 'Logement',
          description: '',
          type: PropertyType.apartment,
          furnished: false,
          pricePerNight: 0,
          address: '',
          city: '',
          imageUrls: [],
          amenities: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      // Send notification to client
      await ref.read(notificationProvider.notifier).notifyBookingDeclined(
        bookingId: bookingId,
        propertyTitle: property.title,
        reason: reason,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réservation refusée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<String?> _showReasonDialog({
    required BuildContext context,
    required String title,
    required String hint,
    bool isRequired = false,
  }) async {
    final reasonController = TextEditingController();
    String? result;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: isRequired ? 'Motif (obligatoire)' : 'Message (optionnel)',
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (isRequired && reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez indiquer un motif')),
                );
                return;
              }
              result = reasonController.text.trim();
              Navigator.pop(context);
            },
            child: Text(isRequired ? 'Refuser' : 'Accepter'),
          ),
        ],
      ),
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingProvider).bookings;
    final properties = ref.watch(propertyProvider).properties;
    final ownerProperties = ref.watch(authProvider).user != null
        ? ref.read(propertyProvider.notifier).getPropertiesByOwner(
              ref.watch(authProvider).user!.id,
            )
        : <Property>[];

    // Filter bookings for owner's properties
    final ownerBookings = bookings.where((booking) {
      return ownerProperties.any((p) => p.id == booking.propertyId);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes de réservation'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(bookingProvider.notifier).loadBookings(role: 'owner');
          await ref.read(propertyProvider.notifier).loadProperties();
        },
        child: ownerBookings.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FontAwesomeIcons.inbox, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune demande',
                          style: TextStyle(color: Colors.grey[600], fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ownerBookings.length,
                itemBuilder: (context, index) {
                final booking = ownerBookings[index];
                final property = properties.firstWhere(
                  (p) => p.id == booking.propertyId,
                  orElse: () => Property(
                    id: booking.propertyId,
                    ownerId: '',
                    title: 'Propriété inconnue',
                    description: '',
                    type: PropertyType.apartment,
                    address: '',
                    city: '',
                    pricePerNight: 0,
                    amenities: [],
                    imageUrls: [],
                    furnished: false,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );
                
                // Create a minimal client object from booking data
                // In the future, we could fetch full client data from API
                final client = User(
                  id: booking.clientId,
                  fullName: 'Client ${booking.clientId.substring(0, 8)}',
                  email: 'client@example.com',
                  role: UserRole.client,
                  phone: null,
                  isVerified: false,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                return _BookingRequestCard(
                  booking: booking,
                  property: property,
                  client: client,
                  onAccept: () => _handleAccept(booking.id),
                  onDecline: () => _handleDecline(booking.id),
                );
              },
            ),
      ),
    );
  }
}

class _BookingRequestCard extends ConsumerWidget {
  final Booking booking;
  final Property property;
  final User client;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  const _BookingRequestCard({
    required this.booking,
    required this.property,
    required this.client,
    required this.onAccept,
    required this.onDecline,
  });

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.accepted:
        return Colors.green;
      case BookingStatus.declined:
        return Colors.red;
      case BookingStatus.cancelled:
        return Colors.grey;
    }
  }

  String _getStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'En attente';
      case BookingStatus.accepted:
        return 'Acceptée';
      case BookingStatus.declined:
        return 'Refusée';
      case BookingStatus.cancelled:
        return 'Annulée';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      client.fullName[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        client.email,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(booking.status),
                    style: TextStyle(
                      color: _getStatusColor(booking.status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              property.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Arrivée:'),
                Text(
                  DateFormatter.formatDate(booking.startDate),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Départ:'),
                Text(
                  DateFormatter.formatDate(booking.endDate),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Voyageurs:'),
                Text('${booking.guests}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:'),
                Text(
                  CurrencyFormatter.formatXOF(booking.totalPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Date de demande:'),
                Text(
                  DateFormatter.formatDate(booking.createdAt),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (booking.message != null && booking.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(booking.message!),
                  ],
                ),
              ),
            ],
            if (booking.status == BookingStatus.pending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // Navigate to conversations list
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ConversationsListScreen(),
                          ),
                        );
                      },
                      icon: const Icon(FontAwesomeIcons.comments),
                      label: const Text('Chat'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await onDecline();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await onAccept();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Accepter'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  // Try to find or create conversation for this booking
                  try {
                    // First, try to get existing conversation
                    final conversations = ref.read(chatProvider).conversations;
                    var conversation = conversations.firstWhere(
                      (conv) => conv.bookingId == booking.id,
                      orElse: () => Conversation(
                        id: '',
                        bookingId: booking.id,
                        clientId: booking.clientId,
                        ownerId: '',
                        propertyId: booking.propertyId,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );

                    // If conversation doesn't exist, create it
                    if (conversation.id.isEmpty) {
                      conversation = await ref.read(chatProvider.notifier).createConversation(booking.id);
                    }

                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailScreen(conversation: conversation),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: ${e.toString().replaceFirst('Exception: ', '')}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(FontAwesomeIcons.comments),
                label: const Text('Chatter avec le client'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

