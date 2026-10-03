import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/parent_provider.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/student_card.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';

/// Screen listing all children linked to the current parent.
class ChildrenListScreen extends ConsumerWidget {
  const ChildrenListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.uid ?? '';
    // Step 1: resolve this user's PARENT PROFILE (its id is what
    // student.parentIds stores - NOT the auth uid).
    final parentAsync = ref.watch(parentByUserIdProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Children'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: RoleBasedDrawer(
        role: AppConstants.roleParent,
        userName: auth.currentUser?.displayName ?? 'Parent',
        userEmail: auth.currentUser?.email ?? '',
      ),
      body: parentAsync.when(
        data: (parent) {
          if (parent == null) {
            return const Center(
                child: Text('No parent profile found for this account.'));
          }
          final pid = parent.id;
          // Step 2: query students linked to that profile id.
          final studentsAsync = ref.watch(parentStudentsProvider(pid));
          return studentsAsync.when(
            data: (students) {
              if (students.isEmpty) {
                return const Center(
                  child: Text('No children linked to your account.',
                      style: TextStyle(fontSize: 16)),
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(parentStudentsProvider(pid).future),
                child: ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return StudentCard(
                      student: student,
                      showBusInfo: true,
                      onTap: () => context.go('/parent/child/${student.id}'),
                    );
                  },
                ),
              );
            },
            loading: () => const LoadingWidget(),
            error: (error, _) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}