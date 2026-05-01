import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/models/booking.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/booking_provider.dart';
import 'package:travelci/core/providers/property_provider.dart';
import 'package:travelci/core/services/availability_service.dart';
import 'package:travelci/core/providers/notification_provider.dart';
import 'package:travelci/core/providers/chat_provider.dart';
import 'package:travelci/core/models/review.dart';
import 'package:travelci/core/providers/favorites_provider.dart';
import 'package:travelci/core/providers/review_provider.dart';
import 'package:travelci/core/utils/currency_formatter.dart';
import 'package:travelci/core/utils/feedback.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;

  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
  });

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  int _currentImageIndex = 0;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  int _guests = 1;
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reviewProvider.notifier).loadReviews(widget.propertyId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _showBookingDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => _BookingSheet(
          property: ref.read(propertyProvider.notifier).getPropertyById(widget.propertyId)!,
          startDate: _selectedStartDate,
          endDate: _selectedEndDate,
          guests: _guests,
          messageController: _messageController,
          onStartDateSelected: (date) {
            setState(() {
              _selectedStartDate = date;
              if (_selectedEndDate != null && _selectedEndDate!.isBefore(date)) {
                _selectedEndDate = null;
              }
            });
            // Forcer la reconstruction du bottom sheet
            setModalState(() {});
          },
          onEndDateSelected: (date) {
            setState(() {
              _selectedEndDate = date;
            });
            // Forcer la reconstruction du bottom sheet
            setModalState(() {});
          },
          onGuestsChanged: (guests) {
            setState(() {
              _guests = guests;
            });
            // Forcer la reconstruction du bottom sheet
            setModalState(() {});
          },
          onBook: () async {
            final property = ref.read(propertyProvider.notifier).getPropertyById(widget.propertyId)!;
            final user = ref.read(authProvider).user!;
            
            if (_selectedStartDate == null || _selectedEndDate == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Veuillez sélectionner les dates')),
              );
              return;
            }

            try {
              final booking = await ref.read(bookingProvider.notifier).createBooking(
                    propertyId: property.id,
                    startDate: _selectedStartDate!,
                    endDate: _selectedEndDate!,
                    guests: _guests,
                    message: _messageController.text.isEmpty ? null : _messageController.text,
                  );

              // Send notification to owner
              await ref.read(notificationProvider.notifier).notifyBookingRequest(
                bookingId: booking.id,
                propertyTitle: property.title,
                clientName: user.fullName,
              );

              // Refresh conversations to show the newly created conversation
              // The backend should auto-create a conversation when booking is created
              // Wait a bit for the backend to create the conversation (it's async)
              // Increased delay to ensure conversation is created
              await Future.delayed(const Duration(milliseconds: 1500));
              try {
                await ref.read(chatProvider.notifier).refreshConversations(role: user.role.value);
              } catch (_) {
                // Don't fail the booking creation if conversation refresh fails
              }

              // Show success message first
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Demande de réservation envoyée avec succès'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
                
                // Wait a bit for user to see the message, then close
                await Future.delayed(const Duration(milliseconds: 800));
                
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
              // Note: _isLoading will be reset when the popup closes
            } catch (e) {
              // Re-throw to let the button handler reset loading state
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString().replaceFirst('Exception: ', '')}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              rethrow; // Re-throw so the button handler can reset _isLoading
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final property = ref.watch(propertyProvider.notifier).getPropertyById(widget.propertyId);
    final user = ref.watch(authProvider).user;
    final isFav = ref.watch(favoritesProvider).valueOrNull?.contains(widget.propertyId) ?? false;
    final reviews = ref.watch(reviewProvider.select((m) => m[widget.propertyId] ?? []));
    final avgRating = reviews.isNotEmpty
        ? reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length
        : 0.0;

    if (property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détails')),
        body: const Center(child: Text('Logement non trouvé')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with images
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFav ? Colors.red : Colors.white,
                ),
                onPressed: () {
                  tapFeedback();
                  ref.read(favoritesProvider.notifier).toggleFavorite(widget.propertyId);
                },
                tooltip: isFav ? 'Retirer des favoris' : 'Ajouter aux favoris',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: PageView.builder(
                itemCount: property.imageUrls.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Image.network(
                    property.imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Icon(FontAwesomeIcons.image, size: 64),
                      );
                    },
                  );
                },
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    property.imageUrls.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentImageIndex == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: property.type == PropertyType.apartment
                              ? Colors.blue[100]
                              : Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          property.type == PropertyType.apartment
                              ? 'Appartement'
                              : 'Villa',
                          style: TextStyle(
                            color: property.type == PropertyType.apartment
                                ? Colors.blue[900]
                                : Colors.green[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(FontAwesomeIcons.locationDot, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${property.city}, ${property.address}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                  if (property.roomCount != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(FontAwesomeIcons.doorOpen, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          property.roomCount == 1
                              ? 'Studio (1 pièce)'
                              : '${property.roomCount} pièces',
                          style: TextStyle(color: Colors.grey[700], fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        CurrencyFormatter.formatXOF(property.pricePerNight),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/nuit',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    property.description ?? 'Aucune description disponible',
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Équipements',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: property.amenities.map((amenity) {
                      return Chip(
                        avatar: const Icon(FontAwesomeIcons.circleCheck, size: 18),
                        label: Text(amenity),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Reviews section
                  _ReviewsSection(
                    propertyId: widget.propertyId,
                    reviews: reviews,
                    avgRating: avgRating,
                    user: user,
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  if (user?.role == UserRole.client)
                    ElevatedButton.icon(
                      onPressed: () { tapFeedback(); _showBookingDialog(); },
                      icon: const Icon(FontAwesomeIcons.calendarDays),
                      label: const Text('Demander une réservation'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    )
                  else
                    Column(
                      children: [
                        Text(
                          'Connectez-vous pour réserver ce logement',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            tapFeedback();
                            context.push('/login');
                          },
                          icon: const Icon(FontAwesomeIcons.rightToBracket),
                          label: const Text('Se connecter'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Reviews
// ──────────────────────────────────────────────

class _ReviewsSection extends ConsumerWidget {
  final String propertyId;
  final List<Review> reviews;
  final double avgRating;
  final dynamic user;

  const _ReviewsSection({
    required this.propertyId,
    required this.reviews,
    required this.avgRating,
    required this.user,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasReviewed = user != null &&
        ref
            .read(reviewProvider.notifier)
            .hasUserReviewed(propertyId, user!.id as String);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Avis',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (reviews.isNotEmpty) ...[
              const Icon(Icons.star_rounded, size: 20, color: Color(0xFFFFC107)),
              const SizedBox(width: 3),
              Text(
                avgRating.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                ' · ${reviews.length} avis',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            const Spacer(),
            if (user?.role?.toString().contains('client') == true && !hasReviewed)
              TextButton.icon(
                onPressed: () {
                  tapFeedback();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _WriteReviewSheet(
                      propertyId: propertyId,
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Écrire un avis'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Aucun avis pour l\'instant.\nSoyez le premier à donner votre avis !',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (_, i) => _ReviewCard(review: reviews[i]),
          ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final initials = review.userName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          child: Text(
            initials,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    review.userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(review.createdAt),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _StarDisplay(rating: review.rating, size: 14),
              const SizedBox(height: 6),
              Text(
                review.comment,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _StarDisplay extends StatelessWidget {
  final double rating;
  final double size;

  const _StarDisplay({required this.rating, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return Icon(Icons.star_rounded,
              size: size, color: const Color(0xFFFFC107));
        } else if (i < rating && rating - i >= 0.5) {
          return Icon(Icons.star_half_rounded,
              size: size, color: const Color(0xFFFFC107));
        } else {
          return Icon(Icons.star_outline_rounded,
              size: size, color: Colors.grey[400]);
        }
      }),
    );
  }
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  final String propertyId;

  const _WriteReviewSheet({required this.propertyId});

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  double _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une note')),
      );
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez écrire un commentaire')),
      );
      return;
    }
    setState(() => _submitting = true);
    await ref.read(reviewProvider.notifier).addReview(
          propertyId: widget.propertyId,
          rating: _rating,
          comment: _commentController.text.trim(),
        );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avis publié avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Écrire un avis',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text('Votre note',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (i) {
                final starValue = i + 1.0;
                return GestureDetector(
                  onTap: () {
                    tapFeedback();
                    setState(() => _rating = starValue);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      _rating >= starValue
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 40,
                      color: _rating >= starValue
                          ? const Color(0xFFFFC107)
                          : Colors.grey[300],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            const Text('Votre commentaire',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Partagez votre expérience avec ce logement...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text('Publier l\'avis',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────

class _BookingSheet extends ConsumerStatefulWidget {
  final Property property;
  final DateTime? startDate;
  final DateTime? endDate;
  final int guests;
  final TextEditingController messageController;
  final Function(DateTime) onStartDateSelected;
  final Function(DateTime) onEndDateSelected;
  final Function(int) onGuestsChanged;
  final Future<void> Function() onBook;

  const _BookingSheet({
    required this.property,
    required this.startDate,
    required this.endDate,
    required this.guests,
    required this.messageController,
    required this.onStartDateSelected,
    required this.onEndDateSelected,
    required this.onGuestsChanged,
    required this.onBook,
  });

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  late DateTime _focusedDay;
  late TextEditingController _localMessageController;
  bool _isLoading = false;
  List<Booking> _propertyBookings = [];
  Set<String> _blockedDates = {};
  bool _loadingBookings = true;
  final AvailabilityService _availabilityService = AvailabilityService();

  // Helper pour normaliser les dates (sans heure)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _dateKey(DateTime date) {
    final d = _normalizeDate(date);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // Check if a date is blocked by owner (unavailable)
  bool _isDateBlocked(DateTime date) => _blockedDates.contains(_dateKey(date));

  // Check if a date is booked (within any accepted or pending booking)
  bool _isDateBooked(DateTime date) {
    final normalizedDate = _normalizeDate(date);
    return _propertyBookings.any((booking) {
      final start = _normalizeDate(booking.startDate);
      final end = _normalizeDate(booking.endDate);
      // Check if date is within booking range (inclusive)
      return (normalizedDate.isAtSameMomentAs(start) || 
              normalizedDate.isAfter(start)) &&
             (normalizedDate.isAtSameMomentAs(end) || 
              normalizedDate.isBefore(end));
    });
  }

  // Get all booked dates as a set for quick lookup
  Set<DateTime> _getBookedDates() {
    final bookedDates = <DateTime>{};
    for (final booking in _propertyBookings) {
      final start = _normalizeDate(booking.startDate);
      final end = _normalizeDate(booking.endDate);
      var current = start;
      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        bookedDates.add(current);
        current = current.add(const Duration(days: 1));
      }
    }
    return bookedDates;
  }

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.startDate ?? DateTime.now();
    _localMessageController = TextEditingController(text: widget.messageController.text);
    _localMessageController.addListener(_onMessageChanged);
    _loadPropertyBookings();
  }

  Future<void> _loadPropertyBookings() async {
    try {
      final bookingService = ref.read(bookingServiceProvider);
      final bookings = await bookingService.getPropertyBookings(widget.property.id);
      if (mounted) setState(() => _propertyBookings = bookings);
    } catch (_) {}
    try {
      final dates = await _availabilityService.getBlockedDates(widget.property.id);
      if (mounted) setState(() => _blockedDates = Set<String>.from(dates));
    } catch (_) {}
    if (mounted) setState(() => _loadingBookings = false);
  }

  @override
  void didUpdateWidget(_BookingSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mettre à jour _focusedDay si les dates ont changé
    if (widget.startDate != oldWidget.startDate || widget.endDate != oldWidget.endDate) {
      if (widget.startDate != null) {
        _focusedDay = widget.startDate!;
      }
      // Forcer un rebuild pour mettre à jour le calendrier
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _onMessageChanged() {
    widget.messageController.text = _localMessageController.text;
  }

  @override
  void dispose() {
    _localMessageController.removeListener(_onMessageChanged);
    _localMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nights = widget.startDate != null && widget.endDate != null
        ? widget.endDate!.difference(widget.startDate!).inDays
        : 0;
    final totalPrice = nights * widget.property.pricePerNight;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          const Text(
            'Demander une réservation',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Les dates grisées sont réservées ou bloquées par le propriétaire et ne peuvent pas être sélectionnées.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: Opacity(
                opacity: _isLoading ? 0.5 : 1.0,
                child: TableCalendar(
              // Key without start/end so calendar isn't recreated on each tap (avoids extra "highlight" tap)
              key: ValueKey('${_propertyBookings.length}_${_blockedDates.length}'),
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                final normalizedDay = _normalizeDate(day);
                if (widget.startDate != null && widget.endDate != null) {
                  final normalizedStart = _normalizeDate(widget.startDate!);
                  final normalizedEnd = _normalizeDate(widget.endDate!);
                  // Afficher le début, la fin, et tous les jours entre les deux
                  return normalizedDay.isAtSameMomentAs(normalizedStart) ||
                      normalizedDay.isAtSameMomentAs(normalizedEnd) ||
                      (normalizedDay.isAfter(normalizedStart) && normalizedDay.isBefore(normalizedEnd));
                }
                if (widget.startDate != null) {
                  final normalizedStart = _normalizeDate(widget.startDate!);
                  return normalizedDay.isAtSameMomentAs(normalizedStart);
                }
                return false;
              },
              rangeStartDay: widget.startDate != null ? _normalizeDate(widget.startDate!) : null,
              rangeEndDay: widget.endDate != null ? _normalizeDate(widget.endDate!) : null,
              rangeSelectionMode: RangeSelectionMode.toggledOn,
              // Disable past, booked and blocked dates
              enabledDayPredicate: (day) {
                final normalizedDay = _normalizeDate(day);
                final today = _normalizeDate(DateTime.now());
                return !normalizedDay.isBefore(today) &&
                    !_isDateBooked(day) &&
                    !_isDateBlocked(day);
              },
              // Style booked and blocked dates in grey
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, date, _) {
                  if (_isDateBooked(date) || _isDateBlocked(date)) {
                    return Container(
                      margin: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }
                  return null;
                },
                todayBuilder: (context, date, _) {
                  if (_isDateBooked(date) || _isDateBlocked(date)) {
                    return Container(
                      margin: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[600]!, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }
                  return null;
                },
                outsideBuilder: (context, date, _) {
                  if (_isDateBooked(date) || _isDateBlocked(date)) {
                    return Container(
                      margin: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
              onDaySelected: (selectedDay, focusedDay) {
                if (mounted) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                }
                final normalizedSelected = _normalizeDate(selectedDay);
                final today = _normalizeDate(DateTime.now());
                
                // Vérifier que la date sélectionnée n'est pas dans le passé
                if (normalizedSelected.isBefore(today)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ce jour n\'est pas disponible pour la réservation.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                
                // Vérifier que la date n'est pas réservée ou bloquée
                if (_isDateBooked(selectedDay) || _isDateBlocked(selectedDay)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ce jour n\'est pas disponible pour la réservation.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                
                // Logique simplifiée : toujours gérer la sélection manuellement
                // Si aucune date de début n'est sélectionnée, sélectionner comme date de début
                if (widget.startDate == null) {
                  widget.onStartDateSelected(normalizedSelected);
                }
                // Si les deux dates sont déjà sélectionnées, commencer une nouvelle sélection
                else if (widget.endDate != null) {
                  widget.onStartDateSelected(normalizedSelected);
                }
                // Si seule la date de début est sélectionnée
                else {
                  final normalizedStart = _normalizeDate(widget.startDate!);
                  if (normalizedSelected.isAfter(normalizedStart)) {
                    // Si la date sélectionnée est après la date de début, c'est la date de fin
                    widget.onEndDateSelected(normalizedSelected);
                  } else {
                    // Si la date sélectionnée est avant ou égale à la date de début, remplacer la date de début
                    widget.onStartDateSelected(normalizedSelected);
                  }
                }
              },
              onRangeSelected: (start, end, focusedDay) {
                if (mounted) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                }
                // First tap: start set, end null → select start immediately (no extra tap)
                if (start != null) {
                  final normalizedStart = _normalizeDate(start);
                  if (normalizedStart.isBefore(_normalizeDate(DateTime.now()))) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ce jour n\'est pas disponible pour la réservation.'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  if (_isDateBooked(start) || _isDateBlocked(start)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ce jour n\'est pas disponible pour la réservation.'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  widget.onStartDateSelected(normalizedStart);
                }
                // Second tap: both set → validate range and set both (so one callback with full range works)
                if (end != null && start != null) {
                  var current = start;
                  bool hasUnavailableDate = false;
                  while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
                    if (_isDateBooked(current) || _isDateBlocked(current)) {
                      hasUnavailableDate = true;
                      break;
                    }
                    current = current.add(const Duration(days: 1));
                  }
                  if (hasUnavailableDate) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ce jour n\'est pas disponible pour la réservation.'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  widget.onStartDateSelected(_normalizeDate(start));
                  widget.onEndDateSelected(_normalizeDate(end));
                }
              },
              onPageChanged: (focusedDay) {
                if (mounted) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                }
              },
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: const HeaderStyle(formatButtonVisible: false),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Indisponible (réservé ou bloqué par le propriétaire)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Disponible',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          AbsorbPointer(
            absorbing: _isLoading,
            child: Opacity(
              opacity: _isLoading ? 0.5 : 1.0,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Nombre de voyageurs: '),
                      IconButton(
                        icon: const Icon(FontAwesomeIcons.circleMinus),
                        onPressed: widget.guests > 1 ? () { tapFeedback(); widget.onGuestsChanged(widget.guests - 1); } : null,
                      ),
                      Text('${widget.guests}'),
                      IconButton(
                        icon: const Icon(FontAwesomeIcons.circlePlus),
                        onPressed: () { tapFeedback(); widget.onGuestsChanged(widget.guests + 1); },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _localMessageController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Message (optionnel)',
                      border: OutlineInputBorder(),
                      hintText: 'Ajoutez un message pour le propriétaire...',
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.multiline,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (nights > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$nights nuit${nights > 1 ? 's' : ''}'),
                Text(
                  CurrencyFormatter.formatXOF(widget.property.pricePerNight * nights),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  CurrencyFormatter.formatXOF(totalPrice),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_isLoading || widget.startDate == null || widget.endDate == null)
                ? null
                : () async {
                    tapFeedback();
                    // Ensure no day in the selected range is booked or owner-blocked (e.g. owner marked busy after client opened sheet)
                    final start = _normalizeDate(widget.startDate!);
                    final end = _normalizeDate(widget.endDate!);
                    var day = start;
                    while (day.isBefore(end) || day.isAtSameMomentAs(end)) {
                      if (_isDateBooked(day) || _isDateBlocked(day)) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Une ou plusieurs dates de votre séjour sont indisponibles (réservées ou bloquées par le propriétaire). Veuillez choisir d\'autres dates.',
                              ),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                        return;
                      }
                      day = day.add(const Duration(days: 1));
                    }

                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      await widget.onBook();
                      // Le feedback et la fermeture sont gérés dans onBook
                      // Si succès, le popup se ferme donc pas besoin de réinitialiser _isLoading
                    } catch (e) {
                      // En cas d'erreur, réinitialiser le loading pour permettre une nouvelle tentative
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                      // L'erreur est déjà gérée dans onBook
                    }
                  },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Envoyer la demande'),
          ),
              ],
            ),
          ),
        );
      },
    );
  }
}

