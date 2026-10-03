import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/attendance_model.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';
import '../class_selector_dropdown.dart';

/// Screen where a teacher marks student attendance.
class MarkAttendanceScreen extends ConsumerStatefulWidget {
  const MarkAttendanceScreen({super.key});
  @override
  ConsumerState<MarkAttendanceScreen> createState() =>
      _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends ConsumerState<MarkAttendanceScreen> {
  String? _selectedClassId;
  DateTime _selectedDate = DateTime.now();
  final Map<String, String> _attendanceMap = {};
  bool _saving = false;
  bool _loadingSavedAttendance = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleTeacher,
        userName: 'Teacher',
        userEmail: '',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ClassSelectorDropdown(
                  value: _selectedClassId,
                  onChanged: (v) {
                    setState(() {
                      _selectedClassId = v;
                      _attendanceMap.clear();
                      _loadingSavedAttendance = v != null;
                    });
                    if (v != null) _loadSavedAttendance();
                  },
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Attendance date',
                      prefixIcon: Icon(Icons.event),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(DateTimeUtils.formatDate(_selectedDate)),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedClassId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _loadingSavedAttendance
                  ? const LinearProgressIndicator()
                  : _attendanceCounts(),
            ),
          Expanded(child: _buildStudentList()),
        ],
      ),
      floatingActionButton: _selectedClassId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _saveAttendance,
              label: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text('Save Attendance'),
              icon: const Icon(Icons.save),
            ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _attendanceMap.clear();
        _loadingSavedAttendance = _selectedClassId != null;
      });
      if (_selectedClassId != null) await _loadSavedAttendance();
    }
  }

  Future<void> _loadSavedAttendance() async {
    final classId = _selectedClassId;
    if (classId == null) return;
    final dateStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dateEnd = dateStart.add(const Duration(days: 1));
    try {
      final saved = await FirebaseFirestore.instance
          .collection(AppConstants.colAttendance)
          .where('classId', isEqualTo: classId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateStart))
          .where('date', isLessThan: Timestamp.fromDate(dateEnd))
          .get();
      if (!mounted || classId != _selectedClassId) return;
      setState(() {
        _attendanceMap
          ..clear()
          ..addEntries(
            saved.docs.map((doc) {
              final data = doc.data();
              return MapEntry(
                data['studentId'] as String? ?? doc.id.split('_').first,
                data['status'] as String? ?? AttendanceStatus.present,
              );
            }),
          );
        _loadingSavedAttendance = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingSavedAttendance = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load saved attendance: $error')),
      );
    }
  }

  Widget _attendanceCounts() {
    int count(String status) =>
        _attendanceMap.values.where((value) => value == status).length;
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        Text('Marked ${_attendanceMap.length}'),
        Text(
          'Present ${count(AttendanceStatus.present)}',
          style: const TextStyle(color: AppColors.presentColor),
        ),
        Text(
          'Absent ${count(AttendanceStatus.absent)}',
          style: const TextStyle(color: AppColors.absentColor),
        ),
        Text(
          'Late ${count(AttendanceStatus.late)}',
          style: const TextStyle(color: AppColors.lateColor),
        ),
        Text(
          'Excused ${count(AttendanceStatus.excused)}',
          style: const TextStyle(color: AppColors.excusedColor),
        ),
      ],
    );
  }

  Widget _buildStudentList() {
    if (_selectedClassId == null) {
      return const Center(child: Text('Select a class to mark attendance.'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.colStudents)
          .where('classId', isEqualTo: _selectedClassId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }
        final students = snapshot.data?.docs ?? [];
        if (students.isEmpty) {
          return const Center(child: Text('No students in this class.'));
        }
        return ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, index) {
            final s = students[index].data() as Map<String, dynamic>;
            final id = students[index].id;
            final name =
                s['fullName'] as String? ?? s['name'] as String? ?? 'Unknown';
            return Card(
              child: ListTile(
                title: Text(name),
                trailing: DropdownButton<String>(
                  value: _attendanceMap[id],
                  hint: const Text('Status'),
                  items: const [
                    DropdownMenuItem(
                      value: AttendanceStatus.present,
                      child: Text('Present'),
                    ),
                    DropdownMenuItem(
                      value: AttendanceStatus.absent,
                      child: Text('Absent'),
                    ),
                    DropdownMenuItem(
                      value: AttendanceStatus.late,
                      child: Text('Late'),
                    ),
                    DropdownMenuItem(
                      value: AttendanceStatus.excused,
                      child: Text('Excused'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _attendanceMap[id] = v ?? AttendanceStatus.present;
                    });
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveAttendance() async {
    if (_selectedClassId == null || _attendanceMap.isEmpty) return;
    setState(() => _saving = true);
    try {
      final auth = AuthService();
      final teacherId = auth.currentUser?.uid ?? '';
      final now = DateTime.now();

      // Fetch the class roster so each record carries full student info.
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.colStudents)
          .where('classId', isEqualTo: _selectedClassId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        final status = _attendanceMap[doc.id];
        if (status == null) continue; // Skip unmarked students.

        final data = doc.data();
        final record = AttendanceModel(
          id: '',
          studentId: doc.id,
          studentName: data['fullName'] as String? ?? '',
          classId: _selectedClassId!,
          className: data['className'] as String? ?? '',
          date: _selectedDate,
          time: DateTimeUtils.formatTime(now),
          status: status,
          teacherId: teacherId,
          createdAt: now,
        );
        // Deterministic ID prevents duplicates when re-saving the same day.
        final dateKey =
            _selectedDate.year.toString().padLeft(4, '0') +
            _selectedDate.month.toString().padLeft(2, '0') +
            _selectedDate.day.toString().padLeft(2, '0');
        batch.set(
          FirebaseFirestore.instance
              .collection(AppConstants.colAttendance)
              .doc('${doc.id}_$dateKey'),
          record.toMap(),
        );
      }

      await batch.commit();
      for (final entry in _attendanceMap.entries) {
        await NotificationService.instance.notifyStudentParents(
          studentId: entry.key,
          title: 'Attendance updated',
          message: 'Your child was marked ${entry.value} today.',
          type: 'attendance',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Attendance saved!')));
        context.go('/teacher/attendance/history');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save attendance: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
