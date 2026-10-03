import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/attendance_utils.dart';
import '../../../providers/attendance_provider.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/attendance_status_chip.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Attendance overview screen for admin with filtering and reports.
class AttendanceOverviewScreen extends ConsumerStatefulWidget {
  const AttendanceOverviewScreen({super.key});

  @override
  ConsumerState<AttendanceOverviewScreen> createState() =>
      _AttendanceOverviewScreenState();
}

class _AttendanceOverviewScreenState
    extends ConsumerState<AttendanceOverviewScreen> {
  late DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );
  String? _selectedClass;
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final startOfDay = DateTime(
      _selectedRange.start.year,
      _selectedRange.start.month,
      _selectedRange.start.day,
    );
    final endOfDay = DateTime(
      _selectedRange.end.year,
      _selectedRange.end.month,
      _selectedRange.end.day,
    ).add(const Duration(days: 1));
    final pair = ClassDatePair(
      classId: _selectedClass ?? '',
      dateStart: startOfDay,
      dateEnd: endOfDay,
    );
    final range = DateTimeRange(start: startOfDay, end: endOfDay);

    final attendanceAsync = _selectedClass != null
        ? ref.watch(classAttendanceByDateProvider(pair))
        : ref.watch(attendanceByDateRangeProvider(range));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Overview'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleAdmin,
        userName: 'Admin',
        userEmail: 'admin@school.com',
      ),
      body: Column(
        children: [
          // Date and class filters
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    DateTimeUtils.formatDateRange(
                      _selectedRange.start,
                      _selectedRange.end,
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(AppConstants.colClasses)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final classes = snapshot.data?.docs ?? [];
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedClass,
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All classes'),
                          ),
                          ...classes.map(
                            (doc) => DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(
                                doc.data()['name'] as String? ?? doc.id,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedClass = value),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Status filter
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              children: [
                _buildStatusChip('All', null, AppColors.textSecondary),
                _buildStatusChip(
                  'Present',
                  AppConstants.attendancePresent,
                  AppColors.presentColor,
                ),
                _buildStatusChip(
                  'Absent',
                  AppConstants.attendanceAbsent,
                  AppColors.absentColor,
                ),
                _buildStatusChip(
                  'Late',
                  AppConstants.attendanceLate,
                  AppColors.lateColor,
                ),
                _buildStatusChip(
                  'Excused',
                  AppConstants.attendanceExcused,
                  AppColors.excusedColor,
                ),
              ],
            ),
          ),
          // Attendance list
          Expanded(
            child: attendanceAsync.when(
              data: (records) {
                final summary = AttendanceSummary.fromRecords(records);
                final visibleRecords = filterAttendanceRecords(
                  records,
                  status: _selectedStatus,
                );
                return RefreshIndicator(
                  onRefresh: () async {
                    if (_selectedClass != null) {
                      await ref
                          .refresh(classAttendanceByDateProvider(pair).future)
                          .then<void>((_) {});
                    } else {
                      await ref
                          .refresh(attendanceByDateRangeProvider(range).future)
                          .then<void>((_) {});
                    }
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _summaryRow(summary),
                      if (visibleRecords.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No attendance records match these filters.',
                            ),
                          ),
                        )
                      else
                        ...visibleRecords.map(
                          (record) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  record.studentName.isEmpty
                                      ? '?'
                                      : record.studentName
                                            .substring(0, 1)
                                            .toUpperCase(),
                                ),
                              ),
                              title: Text(record.studentName),
                              subtitle: Text(
                                '${record.className} • ${DateTimeUtils.formatDate(record.date)} • ${record.time}',
                              ),
                              trailing: AttendanceStatusChip(
                                status: record.status,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const LoadingWidget(),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
    );
    if (picked != null) setState(() => _selectedRange = picked);
  }

  Widget _summaryRow(AttendanceSummary summary) => Padding(
    padding: const EdgeInsets.all(12),
    child: Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        _summary('${summary.total}', 'Records', AppColors.primary),
        _summary('${summary.present}', 'Present', AppColors.presentColor),
        _summary('${summary.absent}', 'Absent', AppColors.absentColor),
        _summary('${summary.late}', 'Late', AppColors.lateColor),
        _summary('${summary.excused}', 'Excused', AppColors.excusedColor),
        _summary(
          '${summary.attendanceRate.toStringAsFixed(1)}%',
          'Rate',
          AppColors.schoolTeal,
        ),
      ],
    ),
  );

  Widget _summary(String value, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  Widget _buildStatusChip(String label, String? value, Color color) {
    return FilterChip(
      label: Text(label),
      selected: _selectedStatus == value,
      onSelected: (_) => setState(() => _selectedStatus = value),
      selectedColor: color.withValues(alpha: 0.2),
      backgroundColor: AppColors.surfaceVariant,
      checkmarkColor: color,
    );
  }
}
