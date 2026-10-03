import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/student_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/parent_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/exam_gradebook_list.dart';

class ParentExamResultsScreen extends ConsumerWidget {
  const ParentExamResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.read(authServiceProvider).currentUser?.uid ?? '';
    final parentAsync = ref.watch(parentByUserIdProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Gradebook'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleParent,
        userName: 'Parent',
        userEmail: 'parent@school.com',
      ),
      body: userId.isEmpty
          ? const Center(child: Text('Parent session not found.'))
          : parentAsync.when(
              loading: () => const LoadingWidget(),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (parent) {
                if (parent == null) {
                  return const Center(child: Text('No parent profile found.'));
                }
                final childrenAsync = ref.watch(
                  parentStudentsProvider(parent.id),
                );
                return childrenAsync.when(
                  loading: () => const LoadingWidget(),
                  error: (error, _) => Center(child: Text('Error: $error')),
                  data: (children) => _buildChildrenResults(children),
                );
              },
            ),
    );
  }

  Widget _buildChildrenResults(List<StudentModel> children) {
    if (children.isEmpty) {
      return const Center(child: Text('No children linked to your account.'));
    }
    if (children.length == 1) {
      return _ChildExamResults(student: children.first);
    }
    return DefaultTabController(
      length: children.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [for (final child in children) Tab(text: child.fullName)],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final child in children) _ChildExamResults(student: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildExamResults extends StatelessWidget {
  const _ChildExamResults({required this.student});

  final StudentModel student;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.colExamResults)
          .where('studentId', isEqualTo: student.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load results: ${snapshot.error}'),
          );
        }

        return ExamGradebookList(
          results: [
            for (final doc in snapshot.data?.docs ?? [])
              {...doc.data(), '_resultId': doc.id},
          ],
          emptyMessage: 'No exam results for ${student.fullName} yet.',
        );
      },
    );
  }
}
