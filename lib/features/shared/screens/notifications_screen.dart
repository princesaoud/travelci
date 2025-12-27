import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:travelci/core/models/notification.dart' as app;
import 'package:travelci/core/providers/notification_provider.dart';
import 'package:travelci/core/utils/date_formatter.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure notifications are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notificationState.unreadCount > 0)
            TextButton.icon(
              onPressed: () async {
                await ref.read(notificationProvider.notifier).markAllAsRead();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Toutes les notifications ont été marquées comme lues'),
                    ),
                  );
                }
              },
              icon: const Icon(FontAwesomeIcons.checkDouble, size: 16),
              label: const Text('Tout marquer comme lu'),
            ),
          if (notificationState.notifications.isNotEmpty)
            IconButton(
              icon: const Icon(FontAwesomeIcons.trash),
              onPressed: () => _showDeleteAllDialog(context),
              tooltip: 'Supprimer tout',
            ),
        ],
      ),
      body: notificationState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notificationState.notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FontAwesomeIcons.bellSlash,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune notification',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(notificationProvider.notifier).loadNotifications();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: notificationState.notifications.length,
                    itemBuilder: (context, index) {
                      final notification =
                          notificationState.notifications[index];
                      return _NotificationCard(notification: notification);
                    },
                  ),
                ),
    );
  }

  void _showDeleteAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer toutes les notifications'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer toutes les notifications ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(notificationProvider.notifier).deleteAllNotifications();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Toutes les notifications ont été supprimées'),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final app.AppNotification notification;

  const _NotificationCard({required this.notification});

  IconData _getIcon(app.NotificationType type) {
    switch (type) {
      case app.NotificationType.bookingRequest:
        return FontAwesomeIcons.calendarPlus;
      case app.NotificationType.bookingAccepted:
        return FontAwesomeIcons.circleCheck;
      case app.NotificationType.bookingDeclined:
        return FontAwesomeIcons.circleXmark;
      case app.NotificationType.bookingCancelled:
        return FontAwesomeIcons.calendarXmark;
      case app.NotificationType.message:
        return FontAwesomeIcons.message;
      case app.NotificationType.system:
        return FontAwesomeIcons.bell;
    }
  }

  Color _getIconColor(app.NotificationType type) {
    switch (type) {
      case app.NotificationType.bookingRequest:
        return Colors.orange;
      case app.NotificationType.bookingAccepted:
        return Colors.green;
      case app.NotificationType.bookingDeclined:
        return Colors.red;
      case app.NotificationType.bookingCancelled:
        return Colors.grey;
      case app.NotificationType.message:
        return Colors.blue;
      case app.NotificationType.system:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnread = notification.status == app.NotificationStatus.unread;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(
          FontAwesomeIcons.trash,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) async {
        await ref.read(notificationProvider.notifier).deleteNotification(notification.id);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: isUnread ? Colors.blue.shade50 : null,
        child: InkWell(
          onTap: () async {
            if (isUnread) {
              await ref.read(notificationProvider.notifier).markAsRead(notification.id);
            }
            // TODO: Navigate to relevant screen based on notification type
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getIconColor(notification.type).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIcon(notification.type),
                    color: _getIconColor(notification.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormatter.formatDateTime(notification.createdAt),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

