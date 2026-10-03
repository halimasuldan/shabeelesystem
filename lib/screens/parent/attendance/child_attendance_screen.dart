import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/attendance_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/attendance_model.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/common/attendance_status_chip.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/role_drawer.dart';

/// Attendance overview for a single child (parent view).
class ChildAttendanceScreen extends ConsumerWidget {
  final String studentId;

  const ChildAttendanceScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentProvider(studentId));
    final attendanceAsync = ref.watch(studentAttendanceProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Attendance'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleParent,
        userName: 'Parent',
        userEmail: 'parent@school.com',
      ),
      body: studentAsync.when(
        data: (student) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: const Icon(Icons.person, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student?.fullName ?? 'Student',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (student != null && student.className.isNotEmpty)
                          Text(
                            student.className,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: attendanceAsync.when(
                data: (records) => _RecordsList(
                  records: records,
                  onRefresh: () =>
                      ref.refresh(studentAttendanceProvider(studentId).future),
                ),
                loading: () => const LoadingWidget(),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
        loading: () => const LoadingWidget(),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

/// Scrollable list of attendance records preceded by a summary card.
class _RecordsList extends StatefulWidget {
  final List<AttendanceModel> records;
  final Future<void> Function() onRefresh;

  const _RecordsList({required this.records, required this.onRefresh});

  @override
  State<_RecordsList> createState() => _RecordsListState();
}

class _RecordsListState extends State<_RecordsList> {
  late DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );
  String? _status;

  @override
  Widget build(BuildContext context) {
    final scopedRecords = filterAttendanceRecords(
      widget.records,
      from: _range.start,
      through: _range.end,
    );
    final visibleRecords = _status == null
        ? scopedRecords
        : scopedRecords.where((record) => record.status == _status).toList();
    final summary = AttendanceSummary.fromRecords(scopedRecords);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range),
            label: Text(
              DateTimeUtils.formatDateRange(_range.start, _range.end),
            ),
          ),
          const SizedBox(height: 8),
          _AttendanceSummaryCard(summary: summary),
          Wrap(
            spacing: 6,
            children: [
              _statusChip('All', null),
              _statusChip('Present', AttendanceStatus.present),
              _statusChip('Absent', AttendanceStatus.absent),
              _statusChip('Late', AttendanceStatus.late),
              _statusChip('Excused', AttendanceStatus.excused),
            ],
          ),
          if (visibleRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No attendance records match this date/status.'),
              ),
            )
          else
            ...visibleRecords.map(
              (record) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.event_note,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(DateTimeUtils.formatDate(record.date)),
                  subtitle: Text('${record.className} • ${record.time}'),
                  trailing: AttendanceStatusChip(status: record.status),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String? value) => FilterChip(
    label: Text(label),
    selected: _status == value,
    onSelected: (_) => setState(() => _status = value),
  );

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _range,
    );
    if (result != null) setState(() => _range = result);
  }
}

class _AttendanceSummaryCard extends StatelessWidget {
  final AttendanceSummary summary;

  const _AttendanceSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${summary.total} records'),
                Text(
                  '${summary.attendanceRate.toStringAsFixed(1)}% attendance',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _tile('Present', summary.present, AppColors.presentColor),
                _tile('Absent', summary.absent, AppColors.absentColor),
                _tile('Late', summary.late, AppColors.lateColor),
                _tile('Excused', summary.excused, AppColors.excusedColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, int value, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    ),
  );
}
