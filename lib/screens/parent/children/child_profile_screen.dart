import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/exam_gradebook_list.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/pickup_dropoff_timeline.dart';

/// Detailed view of a child/student profile.
class ChildProfileScreen extends ConsumerWidget {
  final String studentId;

  const ChildProfileScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleParent,
        userName: 'Parent',
        userEmail: 'parent@school.com',
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null) {
            return const Center(child: Text('Student not found.'));
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.refresh(studentProvider(studentId).future),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    color: AppColors.primary.withValues(alpha: 0.05),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundImage: student.photoUrl != null
                              ? CachedNetworkImageProvider(student.photoUrl!)
                              : null,
                          child: student.photoUrl == null
                              ? const Icon(Icons.person, size: 56)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          student.fullName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          student.studentCode,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.go('/parent/child/attendance/$studentId'),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('View Attendance'),
                      ),
                    ),
                  ),
                  // Details
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                              'Gender',
                              _formatGender(student.gender),
                            ),
                            _buildDetailRow(
                              'Date of Birth',
                              student.dateOfBirth != null
                                  ? DateTimeUtils.formatDate(
                                      student.dateOfBirth!,
                                    )
                                  : 'N/A',
                            ),
                            _buildDetailRow('Grade/Class', student.className),
                            _buildDetailRow(
                              'Section',
                              student.sectionName ?? 'N/A',
                            ),
                            _buildDetailRow('Student ID', student.studentCode),
                            _buildDetailRow(
                              'Enrollment Status',
                              student.status.toUpperCase(),
                            ),
                            _buildDetailRow(
                              'Bus Assignment',
                              student.busId ?? 'Not assigned',
                            ),
                            _buildDetailRow('Address', student.address),
                            _buildDetailRow(
                              'Emergency Contact',
                              student.emergencyContactName,
                            ),
                            _buildDetailRow(
                              'Emergency Phone',
                              student.emergencyContactPhone,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Linked Parents
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Linked Parents',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<
                              List<DocumentSnapshot<Map<String, dynamic>>>
                            >(
                              future: Future.wait(
                                student.parentIds
                                    .map(
                                      (pid) => FirebaseFirestore.instance
                                          .collection(AppConstants.colParents)
                                          .doc(pid)
                                          .get(),
                                    )
                                    .toList(),
                              ),
                              builder: (context, pSnap) {
                                if (pSnap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const LinearProgressIndicator();
                                }
                                final parents =
                                    pSnap.data
                                        ?.where((d) => d.exists)
                                        .map(
                                          (d) =>
                                              d.data() as Map<String, dynamic>,
                                        )
                                        .toList() ??
                                    [];
                                if (parents.isEmpty) {
                                  return const Text('No parents linked yet.');
                                }
                                return Column(
                                  children: parents
                                      .map(
                                        (pd) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(
                                            Icons.person,
                                            color: AppColors.primary,
                                          ),
                                          title: Text(pd['name'] ?? ''),
                                          subtitle: Text(
                                            '${pd['phone'] ?? ''}  ${pd['email'] ?? ''}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bus activity - when the child was picked up / dropped off
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Bus Activity',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.go(
                                    '/parent/bus-activity?child=$studentId',
                                  ),
                                  child: const Text('View all'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            PickupDropoffTimeline(
                              studentId: studentId,
                              maxItems: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Exam gradebook
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exam Gradebook',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection(AppConstants.colExamResults)
                              .where('studentId', isEqualTo: studentId)
                              .snapshots(),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const LinearProgressIndicator();
                            }
                            if (snap.hasError) {
                              return Text(
                                'Unable to load results: ${snap.error}',
                              );
                            }
                            return ExamGradebookList(
                              results: [
                                for (final doc in snap.data?.docs ?? [])
                                  {
                                    ...(doc.data() as Map<String, dynamic>),
                                    '_resultId': doc.id,
                                  },
                              ],
                              emptyMessage: 'No exam results yet.',
                              shrinkWrap: true,
                              useCards: false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatGender(String gender) {
    switch (gender) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return gender;
    }
  }
}
