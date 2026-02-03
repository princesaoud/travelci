import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:travelci/core/models/property.dart';
import 'package:travelci/core/services/availability_service.dart';
import 'package:travelci/core/utils/feedback.dart';

class PropertyAvailabilityScreen extends ConsumerStatefulWidget {
  final Property property;

  const PropertyAvailabilityScreen({super.key, required this.property});

  @override
  ConsumerState<PropertyAvailabilityScreen> createState() => _PropertyAvailabilityScreenState();
}

class _PropertyAvailabilityScreenState extends ConsumerState<PropertyAvailabilityScreen> {
  final AvailabilityService _availabilityService = AvailabilityService();
  final Set<String> _blockedDates = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;
  String? _error;
  bool _isSaving = false;

  String _dateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadBlockedDates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dates = await _availabilityService.getBlockedDates(widget.property.id);
      if (mounted) {
        setState(() {
          _blockedDates.clear();
          _blockedDates.addAll(dates);
          _isLoading = false;
          _error = null; // Success: show calendar (all dates free when dates is empty)
        });
      }
    } catch (e) {
      if (mounted) {
        // 404 or API not deployed: show calendar with empty blocked list so screen is still usable
        setState(() {
          _blockedDates.clear();
          _isLoading = false;
          final msg = e.toString().toLowerCase();
          if (msg.contains('404') ||
              msg.contains('not found') ||
              msg.contains('non trouvée') ||
              msg.contains('route non trouvée')) {
            _error = null; // Route not implemented: show calendar with no blocked dates
          } else {
            _error = e.toString().replaceFirst('Exception: ', '');
          }
        });
      }
    }
  }

  Future<void> _toggleDate(DateTime day) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (day.isBefore(today)) return;
    if (_isSaving) return;

    final key = _dateKey(day);
    setState(() => _isSaving = true);

    try {
      if (_blockedDates.contains(key)) {
        await _availabilityService.removeBlockedDates(widget.property.id, [key]);
        if (mounted) setState(() {
          _blockedDates.remove(key);
          _isSaving = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Date rendue disponible')),
          );
        }
      } else {
        await _availabilityService.addBlockedDates(widget.property.id, [key]);
        if (mounted) setState(() {
          _blockedDates.add(key);
          _isSaving = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Date marquée indisponible')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBlockedDates());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disponibilité'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () { tapFeedback(); context.pop(); },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FontAwesomeIcons.triangleExclamation, size: 48, color: Colors.orange[700]),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () { tapFeedback(); _loadBlockedDates(); },
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.property.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Appuyez sur une date pour la marquer indisponible ou disponible. Les dates passées ne peuvent pas être modifiées.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Les dates marquées indisponibles ne pourront pas être réservées par les clients (sauf si déjà réservées).',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TableCalendar<String>(
                        firstDay: DateTime.now(),
                        lastDay: DateTime(DateTime.now().year + 2, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) => _selectedDay != null && isSameDay(_selectedDay, day),
                        calendarFormat: CalendarFormat.month,
                        onDaySelected: (selected, focused) {
                          _selectedDay = selected;
                          _focusedDay = focused;
                          _toggleDate(selected);
                        },
                        onPageChanged: (focused) => _focusedDay = focused,
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) => _buildDay(context, day, false),
                          selectedBuilder: (context, day, focusedDay) => _buildDay(context, day, true),
                          todayBuilder: (context, day, focusedDay) => _buildDay(context, day, false, isToday: true),
                        ),
                        eventLoader: (day) {
                          final key = _dateKey(day);
                          return _blockedDates.contains(key) ? ['blocked'] : [];
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Indisponible (bloqué par vous)'),
                        ],
                      ),
                      if (_isSaving)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDay(BuildContext context, DateTime day, bool isSelected, {bool isToday = false}) {
    final key = _dateKey(day);
    final isBlocked = _blockedDates.contains(key);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isPast = day.isBefore(today);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isBlocked ? Colors.red.withOpacity(0.4) : null,
        borderRadius: BorderRadius.circular(8),
        border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: isPast ? Colors.grey : (isBlocked ? Colors.red[900] : null),
            fontWeight: isToday ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }
}
