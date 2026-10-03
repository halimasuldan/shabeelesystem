import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/services/notification_service.dart';
import '../../../models/notification_model.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../providers/notification_provider.dart';

/// Admin notifications management screen.
class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            onPressed: () => _markAllAsRead(ref),
          ),
        ],
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleAdmin,
        userName: 'Admin',
        userEmail: 'admin@school.com',
      ),
      body: Column(
        children: [
          // Send notification form
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const Text('Send Announcement',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          // Notification list
          Expanded(
            child: StreamBuilder<List<AppNotificationModel>>(
              stream: NotificationService.instance.streamNotifications('admin'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingWidget();
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final notifications = snapshot.data ?? [];
                if (notifications.isEmpty) {
                  return const Center(child: Text('No notifications yet.'));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(userNotificationsProvider('admin'));
                    return;
                  },
                  child: ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return Dismissible(
                        key: Key(notification.id),
                        background: Container(color: AppColors.error),
                        onDismissed: (_) {
                          NotificationService.instance
                              .deleteNotification(notification.id);
                        },
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getTypeColor(notification.type),
                              child: const Icon(Icons.notifications,
                                  color: Colors.white),
                            ),
                            title: Text(notification.title,
                                style: TextStyle(
                                    fontWeight: notification.isRead
                                        ? FontWeight.normal
                                        : FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(notification.message),
                                const SizedBox(height: 4),
                                Text(
                                  DateTimeUtils.formatDateTime(
                                      notification.createdAt),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            trailing: notification.isRead
                                ? null
                                : Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppColors.schoolBlue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
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

  Color _getTypeColor(String type) {
    switch (type) {
      case 'attendance':
        return AppColors.schoolOrange;
      case 'bus':
        return AppColors.schoolBlue;
      case 'admin':
        return AppColors.schoolPurple;
      default:
        return AppColors.textSecondary;
    }
  }

  void _markAllAsRead(WidgetRef ref) {
    // Mark all admin notifications as read
    NotificationService.instance.markAllAsRead('admin');
  }
}

