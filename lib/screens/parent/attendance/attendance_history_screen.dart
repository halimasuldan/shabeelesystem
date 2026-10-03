import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/attendance_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/attendance_model.dart';
import '../../../models/student_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/parent_provider.dart';
import '../../../widgets/common/attendance_status_chip.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/role_drawer.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  String? _selectedChildId;
  late DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final userId = ref.read(authServiceProvider).currentUser?.uid ?? '';
    final parentAsync = ref.watch(parentByUserIdProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleParent,
        userName: 'Parent',
        userEmail: 'parent@school.com',
      ),
      body: parentAsync.when(
        data: (parent) {
          if (parent == null) {
            return const Center(child: Text('No parent profile found.'));
          }
          final ids = parent.studentIds.where((id) => id.isNotEmpty).toList();
          if (ids.isEmpty) {
            return const Center(child: Text('No children linked.'));
          }
          return FutureBuilder<List<StudentModel>>(
            future: _loadChildren(ids),
            builder: (context, childSnapshot) {
              if (childSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingWidget();
              }
              final children = childSnapshot.data ?? const <StudentModel>[];
              if (children.isEmpty) {
                return const Center(child: Text('No linked children found.'));
              }
              final validSelectedId =
                  children.any((child) => child.id == _selectedChildId)
                  ? _selectedChildId
                  : null;
              return _attendanceStream(
                ids,
                children,
                validSelectedId,
                _selectedRange,
                _selectedStatus,
              );
            },
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<List<StudentModel>> _loadChildren(List<String> ids) async {
    final snapshots = await Future.wait(
      ids.map(
        (id) => FirebaseFirestore.instance
            .collection(AppConstants.colStudents)
            .doc(id)
            .get(),
      ),
    );
    return snapshots
        .where((snapshot) => snapshot.exists)
        .map(StudentModel.fromFirestore)
        .toList();
  }

  Widget _attendanceStream(
    List<String> childIds,
    List<StudentModel> children,
    String? selectedId,
    DateTimeRange range,
    String? status,
  ) {
    final queryIds = selectedId == null ? childIds : [selectedId];
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.colAttendance)
          .where('studentId', whereIn: queryIds.take(30).toList())
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load attendance: ${snapshot.error}'),
          );
        }
        final allRecords = (snapshot.data?.docs ?? [])
            .map((doc) => AttendanceModel.fromFirestore(doc))
            .toList();
        final records = filterAttendanceRecords(
          allRecords,
          from: range.start,
          through: range.end,
          status: status,
        );
        return _buildContent(children, records, allRecords, selectedId, range);
      },
    );
  }

  Widget _buildContent(
    List<StudentModel> children,
    List<AttendanceModel> records,
    List<AttendanceModel> allRecords,
    String? selectedId,
    DateTimeRange range,
  ) {
    final summary = AttendanceSummary.fromRecords(
      filterAttendanceRecords(
        selectedId == null
            ? allRecords
            : allRecords.where((record) => record.studentId == selectedId),
        from: range.start,
        through: range.end,
      ),
    );
    final grouped = <String, List<AttendanceModel>>{};
    for (final record in records) {
      grouped
          .putIfAbsent(DateTimeUtils.formatForFirestore(record.date), () => [])
          .add(record);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: OutlinedButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range),
            label: Text(DateTimeUtils.formatDateRange(range.start, range.end)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: DropdownButtonFormField<String>(
            initialValue: selectedId,
            decoration: const InputDecoration(
              labelText: 'Filter by child',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All children'),
              ),
              ...children.map(
                (child) => DropdownMenuItem<String>(
                  value: child.id,
                  child: Text(child.fullName),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedChildId = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _count('Total', summary.total, AppColors.primary),
              _count('Present', summary.present, AppColors.presentColor),
              _count('Absent', summary.absent, AppColors.absentColor),
              _count('Late', summary.late, AppColors.lateColor),
              _count('Excused', summary.excused, AppColors.excusedColor),
              _count(
                'Rate',
                '${summary.attendanceRate.toStringAsFixed(1)}%',
                AppColors.schoolTeal,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            children: [
              _statusChip('All', null, AppColors.textSecondary),
              _statusChip(
                'Present',
                AttendanceStatus.present,
                AppColors.presentColor,
              ),
              _statusChip(
                'Absent',
                AttendanceStatus.absent,
                AppColors.absentColor,
              ),
              _statusChip('Late', AttendanceStatus.late, AppColors.lateColor),
              _statusChip(
                'Excused',
                AttendanceStatus.excused,
                AppColors.excusedColor,
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? const Center(child: Text('No attendance records found.'))
              : ListView(
                  children: grouped.entries.map((entry) {
                    final first = entry.value.first;
                    return Card(
                      child: ExpansionTile(
                        title: Text(DateTimeUtils.formatDate(first.date)),
                        subtitle: Text('${entry.value.length} records'),
                        children: entry.value
                            .map(
                              (record) => ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.school),
                                ),
                                title: Text(record.studentName),
                                subtitle: Text(
                                  '${record.className} • ${record.time}',
                                ),
                                trailing: AttendanceStatusChip(
                                  status: record.status,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _count(String label, Object value, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$value',
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 10)),
    ],
  );

  Widget _statusChip(String label, String? status, Color color) => FilterChip(
    label: Text(label),
    selected: _selectedStatus == status,
    selectedColor: color.withValues(alpha: 0.18),
    onSelected: (_) => setState(() => _selectedStatus = status),
  );

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _selectedRange,
    );
    if (range != null) setState(() => _selectedRange = range);
  }
}
