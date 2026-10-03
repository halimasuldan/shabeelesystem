import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/student_model.dart';
import '../../../models/notification_model.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/student_card.dart';
import '../../../providers/notification_provider.dart';

/// Parent dashboard showing children, attendance, and bus status.
class ParentDashboard extends ConsumerStatefulWidget {
  const ParentDashboard({super.key});

  @override
  ConsumerState<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends ConsumerState<ParentDashboard> {
  String _parentName = 'Parent';
  String _parentEmail = '';
  String? _parentId;

  @override
  void initState() {
    super.initState();
    _loadParentData();
  }

  Future<void> _loadParentData() async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      // Resolve the PARENT PROFILE id - student.parentIds stores this,
      // NOT the auth uid.
      String profileId = '';
      final pSnap = await FirebaseFirestore.instance
          .collection(AppConstants.colParents)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (pSnap.docs.isNotEmpty) {
        profileId = pSnap.docs.first.id;
      }
      if (!mounted) return;
      setState(() {
        _parentName = data['name'] as String? ?? 'Parent';
        _parentEmail = user.email ?? '';
        _parentId = profileId.isEmpty ? null : profileId;
      });
    }
  }

    @override
  Widget build(BuildContext context) {
    final childrenAsync = _parentId == null
        ? const AsyncData(<StudentModel>[])
        : ref.watch(parentStudentsProvider(_parentId!));
    final notificationsAsync = _parentId == null
        ? const AsyncData(<AppNotificationModel>[])
      : ref.watch(userNotificationsProvider(
        ref.read(authServiceProvider).currentUser?.uid ?? ''));
    final unreadCount =
        notificationsAsync.asData?.value.where((n) => !n.isRead).length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: RoleBasedDrawer(
        role: AppConstants.roleParent,
        userName: _parentName,
        userEmail: _parentEmail,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_parentId != null) {
            ref.invalidate(parentStudentsProvider(_parentId!));
          }
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile header
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.primary,
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 36),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_parentName,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600)),
                          Text(_parentEmail,
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    Badge(
                      backgroundColor: AppColors.error,
                      label: Text('$unreadCount',
                          style: TextStyle(color: Colors.white, fontSize: 10)),
                      child: const Icon(Icons.notifications,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Children section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('My Children',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              childrenAsync.when(
                data: (students) {
                  if (students.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No children linked.')),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: students.take(2).map((student) {
                      return StudentCard(
                        student: student,
                        onTap: () =>
                            context.go('/parent/child/${student.id}'),
                      );
                    }).toList(),
                  );
                },
                loading: () => const LoadingWidget(),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
              // Quick action buttons
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                                        Expanded(
                      child: _buildQuickActionButton(
                        Icons.child_care,
                        'My Children',
                        () => context.go('/parent/children'),
                        AppColors.parentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickActionButton(
                        Icons.map,
                        'Track Bus',
                        () => context.go('/parent/bus/tracking'),
                        AppColors.schoolBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickActionButton(
                        Icons.swap_vert_rounded,
                        'Bus Activity',
                        () => context.go('/parent/bus-activity'),
                        AppColors.schoolTeal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickActionButton(
                        Icons.notifications,
                        'Notifications',
                        () => context.go('/parent/notifications'),
                        AppColors.schoolOrange,
                      ),
                    ),
                  ],
                ),
              ),
              // Recent notifications
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('Recent Notifications',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              notificationsAsync.when(
                data: (notifications) {
                  final recent = notifications.take(5).toList();
                  if (recent.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: Text('No recent notifications.')),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recent.length,
                    itemBuilder: (context, index) {
                      final notification = recent[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.schoolBlue.withValues(alpha: 0.1),
                          child: Icon(
                            notification.isRead
                                ? Icons.notifications_none
                                : Icons.notifications,
                            color: AppColors.schoolBlue,
                            size: 20,
                          ),
                        ),
                        title: Text(notification.title,
                            style: TextStyle(
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.w600)),
                        subtitle: Text(notification.message,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Text(
                          '${notification.createdAt.hour}:${notification.createdAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textSecondary),
                        ),
                        onTap: () => ref
                            .read(notificationControllerProvider.notifier)
                            .markAsRead(notification.id),
                      );
                    },
                  );
                },
                loading: () => const LoadingWidget(),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
      IconData icon, String label, VoidCallback onTap, Color color) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
