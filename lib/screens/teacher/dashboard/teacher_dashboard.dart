import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/dashboard_card.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../providers/auth_provider.dart';

/// Teacher dashboard screen.
class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: RoleBasedDrawer(
        role: AppConstants.roleTeacher,
        userName: auth.currentUser?.displayName ?? 'Teacher',
        userEmail: auth.currentUser?.email ?? '',
      ),
      body: StreamBuilder<QueryDocumentSnapshot<Map<String, dynamic>>?>(
        stream: FirebaseFirestore.instance
            .collection(AppConstants.colTeachers)
            .where('userId', isEqualTo: userId)
            .limit(1)
            .snapshots()
            .map((q) => q.docs.isNotEmpty ? q.docs.first : null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.data == null) {
            return const LoadingWidget();
          }
          final t = snapshot.data!.data();
          final classIds = List<String>.from(t['classIds'] as List? ?? []);
          final totalStudents = (t['totalStudents'] as int?) ?? 0;
          return RefreshIndicator(
            onRefresh: () async {},
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                                DashboardCard(title: 'Assigned Classes', value: '${classIds.length}',
                    icon: Icons.class_outlined, color: AppColors.schoolBlue),
                DashboardCard(title: 'Total Students', value: '$totalStudents',
                    icon: Icons.people, color: AppColors.schoolOrange),
                DashboardCard(title: 'Today Attendance', value: '--',
                    icon: Icons.check_circle, color: AppColors.schoolGreen),
                DashboardCard(title: 'Rate %', value: '--%',
                    icon: Icons.percent, color: AppColors.schoolPurple),
              ],
            ),
          );
        },
      ),
    );
  }
}
