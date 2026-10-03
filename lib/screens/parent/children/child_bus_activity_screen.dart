import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/pickup_dropoff_model.dart';
import '../../../models/student_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/pickup_dropoff_timeline.dart';
import '../../../widgets/common/role_drawer.dart';

/// Bus activity for a parent's children: when each child was picked up and
/// dropped off.
///
/// The driver portal appends a timestamped event per status change, so this
/// screen is the parent-facing "picked in / dropped out" history. It is also
/// reachable with `?child=<studentId>` to open straight on one child.
class ChildBusActivityScreen extends ConsumerStatefulWidget {
  const ChildBusActivityScreen({super.key, this.initialStudentId});

  /// Child to show first, e.g. when opened from a child's profile.
  final String? initialStudentId;

  @override
  ConsumerState<ChildBusActivityScreen> createState() =>
      _ChildBusActivityScreenState();
}

class _ChildBusActivityScreenState
    extends ConsumerState<ChildBusActivityScreen> {
  String? _parentProfileId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadParentProfile();
  }

  /// `students.parentIds` stores the parent *profile* id, not the auth uid, so
  /// the profile has to be resolved before the children can be queried.
  Future<void> _loadParentProfile() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.colParents)
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();
      if (!mounted) return;
      setState(() {
        _parentProfileId = snapshot.docs.isEmpty
            ? null
            : snapshot.docs.first.id;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup & Drop-off'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: RoleBasedDrawer(
        role: AppConstants.roleParent,
        userName: auth.currentUser?.displayName ?? 'Parent',
        userEmail: auth.currentUser?.email ?? '',
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingWidget();
    if (_parentProfileId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No parent profile is linked to your account yet.\n\nPlease '
            'contact the school office.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final childrenAsync = ref.watch(parentStudentsProvider(_parentProfileId!));
    return childrenAsync.when(
      loading: () => const LoadingWidget(),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (children) {
        if (children.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No children are linked to your account yet.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (children.length == 1) {
          return _ChildActivityView(student: children.first);
        }
        var initialIndex = children.indexWhere(
          (c) => c.id == widget.initialStudentId,
        );
        if (initialIndex < 0) initialIndex = 0;
        return DefaultTabController(
          length: children.length,
          initialIndex: initialIndex,
          child: Column(
            children: <Widget>[
              TabBar(
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: <Widget>[
                  for (final child in children) Tab(text: child.fullName),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    for (final child in children)
                      _ChildActivityView(student: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Live status for one child plus the full event timeline.
class _ChildActivityView extends StatelessWidget {
  const _ChildActivityView({required this.student});

  final StudentModel student;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _CurrentStatusCard(
          studentId: student.id,
          studentName: student.fullName,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Activity history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                PickupDropoffTimeline(studentId: student.id),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Latest boarding / drop-off state, read directly from the student document.
///
/// [StudentModel] deliberately does not carry these fields (the admin screens
/// write the whole model back with `update()`, which would clobber them), so
/// the raw snapshot is read here instead.
class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({
    required this.studentId,
    required this.studentName,
  });

  final String studentId;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(AppConstants.colStudents)
              .doc(studentId)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final pickupStatus = data['pickupStatus'] as String? ?? 'waiting';
            final dropoffStatus = data['dropoffStatus'] as String? ?? 'pending';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Now - $studentName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _statusRow(
                  Icons.directions_bus_rounded,
                  'Home → school run',
                  pickupStatus,
                ),
                const SizedBox(height: 8),
                _statusRow(
                  Icons.home_rounded,
                  'School → home run',
                  dropoffStatus,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, String status) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: AppColors.schoolBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Text(
          PickupDropoffModel.labelFor(status),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
