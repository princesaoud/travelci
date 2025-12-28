import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/models/user.dart';
import 'package:travelci/core/providers/auth_provider.dart';
import 'package:travelci/core/providers/booking_provider.dart';
import 'package:travelci/core/providers/property_provider.dart';
import 'package:travelci/core/providers/notification_provider.dart';
import 'package:travelci/core/utils/currency_formatter.dart';

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

            final nights = _selectedEndDate!.difference(_selectedStartDate!).inDays;
            final totalPrice = nights * property.pricePerNight;

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

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demande de réservation envoyée')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: ${e.toString()}')),
                );
              }
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
                      Text(
                        '${property.city}, ${property.address}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
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
                  if (user?.role == UserRole.client)
                    ElevatedButton.icon(
                      onPressed: _showBookingDialog,
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

class _BookingSheet extends StatefulWidget {
  final Property property;
  final DateTime? startDate;
  final DateTime? endDate;
  final int guests;
  final TextEditingController messageController;
  final Function(DateTime) onStartDateSelected;
  final Function(DateTime) onEndDateSelected;
  final Function(int) onGuestsChanged;
  final VoidCallback onBook;

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
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  late DateTime _focusedDay;
  late TextEditingController _localMessageController;

  // Helper pour normaliser les dates (sans heure)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.startDate ?? DateTime.now();
    _localMessageController = TextEditingController(text: widget.messageController.text);
    _localMessageController.addListener(_onMessageChanged);
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
          const SizedBox(height: 24),
          SizedBox(
            height: 350,
            child: TableCalendar(
              key: ValueKey('${widget.startDate}_${widget.endDate}'),
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
                if (start != null) {
                  widget.onStartDateSelected(_normalizeDate(start));
                }
                if (end != null) {
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
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Nombre de voyageurs: '),
              IconButton(
                icon: const Icon(FontAwesomeIcons.circleMinus),
                onPressed: widget.guests > 1 ? () => widget.onGuestsChanged(widget.guests - 1) : null,
              ),
              Text('${widget.guests}'),
              IconButton(
                icon: const Icon(FontAwesomeIcons.circlePlus),
                onPressed: () => widget.onGuestsChanged(widget.guests + 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _localMessageController,
            decoration: const InputDecoration(
              labelText: 'Message (optionnel)',
              border: OutlineInputBorder(),
              hintText: 'Ajoutez un message pour le propriétaire...',
            ),
            maxLines: 3,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.multiline,
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
            onPressed: widget.startDate != null && widget.endDate != null ? widget.onBook : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Envoyer la demande'),
          ),
              ],
            ),
          ),
        );
      },
    );
  }
}

