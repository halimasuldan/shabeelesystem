import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/services/notification_service.dart';
import '../../../models/notification_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notification_provider.dart';

/// Parent notifications screen.
class ParentNotificationsScreen extends ConsumerStatefulWidget {
  const ParentNotificationsScreen({super.key});

  @override
  ConsumerState<ParentNotificationsScreen> createState() =>
      _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState
    extends ConsumerState<ParentNotificationsScreen> {

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationControllerProvider.notifier).markAllAsRead(userId),
            child: const Text('Mark All Read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      drawer: RoleBasedDrawer(
        role: AppConstants.roleParent,
        userName: auth.currentUser?.displayName ?? 'Parent',
        userEmail: auth.currentUser?.email ?? '',
      ),
      body: StreamBuilder<List<AppNotificationModel>>(
        stream: NotificationService.instance.streamNotifications(userId),
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
              setState(() {});
            },
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Dismissible(
                  key: Key(notification.id),
                  background: Container(color: AppColors.error),
                  onDismissed: (_) {
                    NotificationService.instance.deleteNotification(notification.id);
                  },
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getTypeColor(notification.type).withValues(alpha: 0.1),
                        child: Icon(Icons.notifications, color: _getTypeColor(notification.type)),
                      ),
                      title: Text(notification.title,
                          style: TextStyle(
                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification.message),
                          const SizedBox(height: 4),
                          Text(DateTimeUtils.formatDateTime(notification.createdAt),
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                      trailing: notification.isRead
                          ? null
                          : const Icon(Icons.fiber_manual_record, color: AppColors.schoolBlue, size: 12),
                      onTap: () => ref.read(notificationControllerProvider.notifier).markAsRead(notification.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'attendance': return AppColors.schoolOrange;
      case 'bus': return AppColors.schoolBlue;
      case 'admin': return AppColors.schoolPurple;
      default: return AppColors.textSecondary;
    }
  }
}
