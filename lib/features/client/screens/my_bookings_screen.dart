import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:travelci/core/models/booking.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/booking_provider.dart';
import 'package:travelci/core/providers/property_provider.dart';
import 'package:travelci/core/providers/notification_provider.dart';
import 'package:travelci/core/utils/currency_formatter.dart';
import 'package:travelci/core/utils/date_formatter.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(bookingProvider.notifier).loadBookings(role: 'client');
      }
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Booking> _filterBookings(List<Booking> bookings, List<Property> properties) {
    if (_searchQuery.isEmpty) {
      return bookings;
    }

    return bookings.where((booking) {
      final property = properties.firstWhere(
        (p) => p.id == booking.propertyId,
        orElse: () => Property(
          id: '',
          ownerId: '',
          title: 'Logement supprimé',
          description: '',
          type: PropertyType.apartment,
          furnished: false,
          pricePerNight: 0,
          address: '',
          city: '',
          imageUrls: [],
          amenities: [],
          createdAt: DateTime.now(),
        ),
      );

      // Search in property title, city, or status
      final statusText = _getStatusText(booking.status).toLowerCase();
      return property.title.toLowerCase().contains(_searchQuery) ||
          property.city.toLowerCase().contains(_searchQuery) ||
          statusText.contains(_searchQuery);
    }).toList();
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
    final user = ref.watch(authProvider).user;
    
    // Redirect guests to login
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bookings = ref.watch(bookingProvider).bookings;
    final properties = ref.watch(propertyProvider).properties;
    final filteredBookings = _filterBookings(bookings, properties);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes réservations'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par titre, ville ou statut...',
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
          // Bookings list
          Expanded(
            child: filteredBookings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? FontAwesomeIcons.magnifyingGlass : FontAwesomeIcons.bookmark,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Aucune réservation trouvée'
                              : 'Aucune réservation',
                          style: TextStyle(color: Colors.grey[600], fontSize: 18),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            child: const Text('Effacer la recherche'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredBookings.length,
                    itemBuilder: (context, index) {
                      final booking = filteredBookings[index];
                      final property = properties.firstWhere(
                        (p) => p.id == booking.propertyId,
                        orElse: () => Property(
                          id: '',
                          ownerId: '',
                          title: 'Logement supprimé',
                          description: '',
                          type: PropertyType.apartment,
                          furnished: false,
                          pricePerNight: 0,
                          address: '',
                          city: '',
                          imageUrls: [],
                          amenities: [],
                          createdAt: DateTime.now(),
                        ),
                      );

                      return _BookingCard(booking: booking, property: property);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends ConsumerStatefulWidget {
  final Booking booking;
  final Property property;

  const _BookingCard({
    required this.booking,
    required this.property,
  });

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
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

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler la réservation'),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler cette réservation ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _handleCancel();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancel() async {
    try {
      // Show loading indicator
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Annulation en cours...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Cancel booking
      await ref.read(bookingProvider.notifier).cancelBooking(widget.booking.id);

      // Send notification to owner
      await ref.read(notificationProvider.notifier).notifyBookingCancelled(
        bookingId: widget.booking.id,
        propertyTitle: widget.property.title,
        isOwner: false, // This is from client side
      );

      // Reload bookings to get updated list
      final user = ref.read(authProvider).user;
      if (user != null) {
        await ref.read(bookingProvider.notifier).loadBookings(role: 'client');
      }

      // Show success message
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réservation annulée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
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
                if (widget.property.imageUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.property.imageUrls.first,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(FontAwesomeIcons.image),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(FontAwesomeIcons.image),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.property.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.property.city,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Dates:'),
                Text(
                  '${DateFormatter.formatShortDate(widget.booking.startDate)} - ${DateFormatter.formatShortDate(widget.booking.endDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Voyageurs:'),
                Text('${widget.booking.guests}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:'),
                Text(
                  CurrencyFormatter.formatXOF(widget.booking.totalPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
                  DateFormatter.formatDate(widget.booking.createdAt),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(widget.booking.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(widget.booking.status),
                    style: TextStyle(
                      color: _getStatusColor(widget.booking.status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.booking.status == BookingStatus.pending ||
                    widget.booking.status == BookingStatus.accepted)
                  TextButton(
                    onPressed: _showCancelConfirmationDialog,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Annuler'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

