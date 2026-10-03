import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/role_drawer.dart';
import '../../widgets/common/exam_gradebook_list.dart';

class ExamResultManagementScreen extends StatelessWidget {
  final String role;

  const ExamResultManagementScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == AppConstants.roleAdmin;
    final userId = AuthService().currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Gradebook'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: RoleBasedDrawer(
        role: role,
        userName: isAdmin ? 'Admin' : 'Teacher',
        userEmail: isAdmin ? 'admin@school.com' : '',
      ),
      body: isAdmin
          ? _buildResultsStream(context, null)
          : FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection(AppConstants.colTeachers)
                  .where('userId', isEqualTo: userId)
                  .limit(1)
                  .get(),
              builder: (context, teacherSnap) {
                if (teacherSnap.connectionState == ConnectionState.waiting) {
                  return const LoadingWidget();
                }
                final teacherId = teacherSnap.data?.docs.isNotEmpty == true
                    ? teacherSnap.data!.docs.first.id
                    : null;
                return _buildResultsStream(context, teacherId);
              },
            ),
    );
  }

  Widget _buildResultsStream(BuildContext context, String? teacherId) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      AppConstants.colExamResults,
    );
    if (teacherId != null) {
      query = query.where('teacherId', isEqualTo: teacherId);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading results: ${snapshot.error}'),
          );
        }

        return ExamGradebookList(
          results: [
            for (final doc in snapshot.data?.docs ?? [])
              {...doc.data(), '_resultId': doc.id},
          ],
          emptyMessage: 'No exam results have been entered yet.',
          onDeleteSubject: (resultIds) => _deleteResults(context, resultIds),
        );
      },
    );
  }

  Future<void> _deleteResults(
    BuildContext context,
    List<String> resultIds,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete subject marks?'),
        content: const Text(
          'All marks currently grouped for this subject will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final resultId in resultIds) {
      batch.delete(
        FirebaseFirestore.instance
            .collection(AppConstants.colExamResults)
            .doc(resultId),
      );
    }
    await batch.commit();
  }
}
