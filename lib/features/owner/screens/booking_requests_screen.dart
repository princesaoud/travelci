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
import 'package:travelci/core/utils/currency_formatter.dart';
import 'package:travelci/core/utils/date_formatter.dart';
import 'package:travelci/features/owner/screens/owner_chat_screen.dart';

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
        ref.read(bookingProvider.notifier).loadBookings(user.id, user.role);
      }
    });
  }

  void _handleAccept(String bookingId) {
    ref.read(bookingProvider.notifier).updateBookingStatus(
          bookingId,
          BookingStatus.accepted,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Réservation acceptée')),
    );
  }

  void _handleDecline(String bookingId) {
    ref.read(bookingProvider.notifier).updateBookingStatus(
          bookingId,
          BookingStatus.declined,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Réservation refusée')),
    );
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
      body: ownerBookings.isEmpty
          ? Center(
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
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ownerBookings.length,
              itemBuilder: (context, index) {
                final booking = ownerBookings[index];
                final property = properties.firstWhere(
                  (p) => p.id == booking.propertyId,
                );
                final client = MockDataService.mockUsers.firstWhere(
                  (u) => u.id == booking.clientId,
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
    );
  }
}

class _BookingRequestCard extends StatelessWidget {
  final Booking booking;
  final Property property;
  final User client;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

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
  Widget build(BuildContext context) {
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OwnerChatScreen(),
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
                      onPressed: onDecline,
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
                      onPressed: onAccept,
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OwnerChatScreen(
                        clientId: client.id,
                        bookingId: booking.id,
                      ),
                    ),
                  );
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

