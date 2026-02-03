import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:travelci/core/models/booking.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/booking_provider.dart';
import 'package:travelci/core/providers/property_provider.dart';
import 'package:travelci/core/providers/notification_provider.dart';
import 'package:travelci/core/widgets/notification_badge.dart';
import 'package:travelci/features/shared/screens/notifications_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travelci/core/utils/currency_formatter.dart';
import 'package:travelci/core/utils/feedback.dart';
import 'package:travelci/features/shared/screens/conversations_list_screen.dart';
import 'package:travelci/features/owner/screens/booking_requests_screen.dart';
import 'package:travelci/features/owner/screens/property_availability_screen.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Single load when dashboard opens; use pull-to-refresh to refresh (reduces API rate)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(propertyProvider.notifier).loadProperties();
        ref.read(bookingProvider.notifier).loadBookings(role: 'owner');
        ref.read(authProvider.notifier).refreshUser();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final propertyState = ref.watch(propertyProvider);
    final bookingState = ref.watch(bookingProvider);
    
    // Get properties for this owner - use watch to get updates automatically
    final ownerProperties = user != null
        ? propertyState.properties.where((p) => p.ownerId == user.id).toList()
        : <Property>[];
    
    // Get bookings for owner's properties
    final ownerPropertyIds = ownerProperties.map((p) => p.id).toSet();
    final ownerBookings = bookingState.bookings
        .where((booking) => ownerPropertyIds.contains(booking.propertyId))
        .toList();
    
    // Count only pending bookings for the stats card
    final pendingBookings = ownerBookings
        .where((booking) => booking.status == BookingStatus.pending)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(FontAwesomeIcons.comments),
            onPressed: () { tapFeedback(); Navigator.push(context, MaterialPageRoute(builder: (context) => const ConversationsListScreen())); },
            tooltip: 'Messages',
          ),
          NotificationBadge(
            icon: const Icon(FontAwesomeIcons.bell),
            onTap: () { tapFeedback(); Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())); },
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.bookmark),
            onPressed: () { tapFeedback(); Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingRequestsScreen())); },
            tooltip: 'Demandes de réservation',
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.user),
            onPressed: () { tapFeedback(); ref.read(authProvider.notifier).logout(); context.go('/login'); },
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(propertyProvider.notifier).loadProperties(forceRefresh: true);
          await ref.read(bookingProvider.notifier).loadBookings(role: 'owner', forceRefresh: true);
        },
        child: Column(
          children: [
            // Profile card (owner: name, email, national ID images)
            if (user != null) _ProfileCard(user: user),
            // Stats cards
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Mes logements',
                      value: '${ownerProperties.length}',
                      icon: FontAwesomeIcons.house,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Réservations en attente',
                      value: '${pendingBookings.length}',
                      icon: FontAwesomeIcons.bookmark,
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BookingRequestsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Properties list
            Expanded(
              child: ownerProperties.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height - 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(FontAwesomeIcons.house, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun logement',
                                style: TextStyle(color: Colors.grey[600], fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ajoutez votre premier logement',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: ownerProperties.length,
                      itemBuilder: (context, index) {
                        final property = ownerProperties[index];
                        return _PropertyCard(property: property);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () { tapFeedback(); context.push('/owner/property/new'); },
        icon: const Icon(FontAwesomeIcons.plus),
        label: const Text('Ajouter un logement'),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final User user;

  const _ProfileCard({required this.user});

  void _showFullImage(BuildContext context, String url, String label) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Flexible(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) => const Icon(Icons.error, size: 48),
                ),
              ),
            ),
            TextButton(
              onPressed: () { tapFeedback(); Navigator.of(context).pop(); },
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFront = user.nationalIdFrontUrl != null && user.nationalIdFrontUrl!.isNotEmpty;
    final hasBack = user.nationalIdBackUrl != null && user.nationalIdBackUrl!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(FontAwesomeIcons.user, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasFront || hasBack) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Pièce d\'identité',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (hasFront)
                    Expanded(
                      child: GestureDetector(
                        onTap: () { tapFeedback(); _showFullImage(context, user.nationalIdFrontUrl!, 'Recto'); },
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: user.nationalIdFrontUrl!,
                                height: 80,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                                errorWidget: (_, __, ___) => Container(height: 80, color: Colors.grey[300], child: const Icon(Icons.error)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Recto', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ),
                  if (hasFront && hasBack) const SizedBox(width: 12),
                  if (hasBack)
                    Expanded(
                      child: GestureDetector(
                        onTap: () { tapFeedback(); _showFullImage(context, user.nationalIdBackUrl!, 'Verso'); },
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: user.nationalIdBackUrl!,
                                height: 80,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                                errorWidget: (_, __, ___) => Container(height: 80, color: Colors.grey[300], child: const Icon(Icons.error)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Verso', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: () { tapFeedback(); onTap!(); },
        borderRadius: BorderRadius.circular(12),
        child: cardContent,
      );
    }

    return cardContent;
  }
}

class _PropertyCard extends ConsumerWidget {
  final Property property;

  const _PropertyCard({required this.property});

  Future<void> _showDeleteConfirmation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le logement'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${property.title}" ?\n\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () { tapFeedback(); Navigator.of(context).pop(false); },
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () { tapFeedback(); Navigator.of(context).pop(true); },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(propertyProvider.notifier).deleteProperty(property.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logement supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () { tapFeedback(); context.push('/owner/property/${property.id}'); },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (property.imageUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    property.imageUrls.first,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: const Icon(FontAwesomeIcons.image),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[300],
                  child: const Icon(FontAwesomeIcons.image),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${property.city}, ${property.address}',
                      style: TextStyle(color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: property.type == PropertyType.apartment
                                ? Colors.blue[100]
                                : Colors.green[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            property.type == PropertyType.apartment
                                ? 'Appartement'
                                : 'Villa',
                            style: TextStyle(
                              fontSize: 12,
                              color: property.type == PropertyType.apartment
                                  ? Colors.blue[900]
                                  : Colors.green[900],
                            ),
                          ),
                        ),
                        if (property.furnished)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Meublé',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.formatXOF(property.pricePerNight),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            icon: const Icon(FontAwesomeIcons.calendarDays, size: 16),
                            label: const Text('Disponibilité'),
                            onPressed: () {
                              tapFeedback();
                              context.push('/owner/property/${property.id}/availability', extra: property);
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(FontAwesomeIcons.pen, size: 16),
                            label: const Text('Modifier'),
                            onPressed: () { tapFeedback(); context.push('/owner/property/${property.id}'); },
                          ),
                          TextButton.icon(
                            icon: Icon(FontAwesomeIcons.trash, size: 16, color: Colors.red[700]),
                            label: Text('Supprimer', style: TextStyle(color: Colors.red[700])),
                            onPressed: () { tapFeedback(); _showDeleteConfirmation(context, ref); },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

