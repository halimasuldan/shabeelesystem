import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/attendance_model.dart';

/// Provider for attendance records filtered by date range.
final attendanceByDateRangeProvider = StreamProvider.autoDispose
    .family<List<AttendanceModel>, DateTimeRange>((ref, range) {
      return FirebaseFirestore.instance
          .collection(AppConstants.colAttendance)
          .where(
            'date',
            isGreaterThanOrEqualTo: range.start,
            isLessThan: range.end,
          )
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => AttendanceModel.fromFirestore(doc))
                .toList(),
          );
    });

/// Provider for attendance records for a specific student.
final studentAttendanceProvider = StreamProvider.autoDispose
    .family<List<AttendanceModel>, String>((ref, studentId) {
      return FirebaseFirestore.instance
          .collection(AppConstants.colAttendance)
          .where('studentId', isEqualTo: studentId)
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => AttendanceModel.fromFirestore(doc))
                .toList(),
          );
    });

/// Helper class for class+date attendance queries.
class ClassDatePair {
  final String classId;
  final DateTime dateStart;
  final DateTime dateEnd;

  ClassDatePair({
    required this.classId,
    required this.dateStart,
    required this.dateEnd,
  });
}

/// Provider for attendance records for a specific class and date.
final classAttendanceByDateProvider = StreamProvider.autoDispose
    .family<List<AttendanceModel>, ClassDatePair>((ref, pair) {
      return FirebaseFirestore.instance
          .collection(AppConstants.colAttendance)
          .where('classId', isEqualTo: pair.classId)
          .where(
            'date',
            isGreaterThanOrEqualTo: pair.dateStart,
            isLessThan: pair.dateEnd,
          )
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => AttendanceModel.fromFirestore(doc))
                .toList(),
          );
    });

/// Provider for the attendance CRUD controller.
final attendanceCrudProvider =
    StateNotifierProvider<AttendanceCrudNotifier, AsyncValue<void>>((ref) {
      return AttendanceCrudNotifier();
    });

/// Controller for attendance create/update operations.
class AttendanceCrudNotifier extends StateNotifier<AsyncValue<void>> {
  AttendanceCrudNotifier() : super(const AsyncData(null));

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mark attendance for a single student.
  Future<void> markAttendance(AttendanceModel attendance) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colAttendance)
          .add(attendance.toMap());
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Update an existing attendance record.
  Future<void> updateAttendance(
    String attendanceId,
    AttendanceModel attendance,
  ) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colAttendance)
          .doc(attendanceId)
          .update(attendance.toMap());
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Get today's attendance for a specific class.
  Future<List<AttendanceModel>> getTodayAttendance(String classId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final snapshot = await _firestore
          .collection(AppConstants.colAttendance)
          .where('classId', isEqualTo: classId)
          .where(
            'date',
            isGreaterThanOrEqualTo: startOfDay,
            isLessThan: endOfDay,
          )
          .get();

      return snapshot.docs
          .map((doc) => AttendanceModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Calculate attendance percentage for a student.
  Future<Map<String, dynamic>> getStudentAttendanceStats(
    String studentId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.colAttendance)
          .where('studentId', isEqualTo: studentId)
          .get();

      int present = 0, absent = 0, late = 0, excused = 0;
      int total = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        total++;
        switch (status) {
          case 'present':
            present++;
            break;
          case 'absent':
            absent++;
            break;
          case 'late':
            late++;
            break;
          case 'excused':
            excused++;
            break;
        }
      }

      final percentage = total > 0 ? (present / total) * 100 : 0.0;

      return {
        'total': total,
        'present': present,
        'absent': absent,
        'late': late,
        'excused': excused,
        'percentage': percentage,
      };
    } catch (e) {
      return {
        'total': 0,
        'present': 0,
        'absent': 0,
        'late': 0,
        'excused': 0,
        'percentage': 0.0,
      };
    }
  }
}
