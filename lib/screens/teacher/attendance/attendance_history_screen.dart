import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/attendance_utils.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/attendance_status_chip.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/attendance_model.dart';

/// Attendance history screen for teachers.
class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});
  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.filter_alt), onPressed: _filter),
        ],
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleTeacher,
        userName: 'Teacher',
        userEmail: '',
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _attendanceStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget();
          }
          final allRecords = (snapshot.data?.docs ?? [])
              .map(AttendanceModel.fromFirestore)
              .toList();
          final records = filterAttendanceRecords(
            allRecords,
            from: _fromDate,
            through: _toDate,
            status: _selectedStatus,
          );
          final summary = AttendanceSummary.fromRecords(
            filterAttendanceRecords(
              allRecords,
              from: _fromDate,
              through: _toDate,
            ),
          );
          final dateLabel = _fromDate == null
              ? 'Last 30 days'
              : DateTimeUtils.formatDateRange(
                  _fromDate!,
                  _toDate ?? _fromDate!,
                );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _filter,
                      icon: const Icon(Icons.date_range),
                      label: Text(dateLabel),
                    ),
                    Text('Total ${summary.total}'),
                    Text(
                      'Present ${summary.present}',
                      style: const TextStyle(color: AppColors.presentColor),
                    ),
                    Text(
                      'Absent ${summary.absent}',
                      style: const TextStyle(color: AppColors.absentColor),
                    ),
                    Text(
                      'Late ${summary.late}',
                      style: const TextStyle(color: AppColors.lateColor),
                    ),
                    Text(
                      'Excused ${summary.excused}',
                      style: const TextStyle(color: AppColors.excusedColor),
                    ),
                    Text('Rate ${summary.attendanceRate.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _statusChip('All', null),
                    _statusChip('Present', AttendanceStatus.present),
                    _statusChip('Absent', AttendanceStatus.absent),
                    _statusChip('Late', AttendanceStatus.late),
                    _statusChip('Excused', AttendanceStatus.excused),
                  ],
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? const Center(
                        child: Text(
                          'No attendance records match these filters.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return Card(
                            child: ListTile(
                              title: Text(record.studentName),
                              subtitle: Text(
                                '${DateTimeUtils.formatDate(record.date)} • ${record.className} • ${record.time}',
                              ),
                              trailing: AttendanceStatusChip(
                                status: record.status,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Unable to load attendance: ${snapshot.error}'),
                ),
            ],
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _attendanceStream() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      AppConstants.colAttendance,
    );
    if (_fromDate == null) {
      final today = DateTime.now();
      final start = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 29));
      final end = DateTime(
        today.year,
        today.month,
        today.day,
      ).add(const Duration(days: 1));
      query = query
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThan: end);
    } else {
      final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      final end = DateTime(
        (_toDate ?? _fromDate!).year,
        (_toDate ?? _fromDate!).month,
        (_toDate ?? _fromDate!).day,
      ).add(const Duration(days: 1));
      query = query
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThan: end);
    }
    return query.orderBy('date', descending: true).snapshots();
  }

  Widget _statusChip(String label, String? status) => FilterChip(
    label: Text(label),
    selected: _selectedStatus == status,
    onSelected: (_) => setState(() => _selectedStatus = status),
  );

  void _filter() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
    );
    if (result != null) {
      setState(() {
        _fromDate = result.start;
        _toDate = result.end;
      });
    }
  }
}
