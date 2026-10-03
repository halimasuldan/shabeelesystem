import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';

/// Model for dashboard statistics.
class DashboardStats {
  final int totalStudents;
  final int totalParents;
  final int totalTeachers;
  final int totalBuses;
  final int presentToday;
  final int absentToday;
  final int lateToday;
  final int excusedToday;
  final int activeBuses;
  final int studentsOnBuses;

  DashboardStats({
    this.totalStudents = 0,
    this.totalParents = 0,
    this.totalTeachers = 0,
    this.totalBuses = 0,
    this.presentToday = 0,
    this.absentToday = 0,
    this.lateToday = 0,
    this.excusedToday = 0,
    this.activeBuses = 0,
    this.studentsOnBuses = 0,
  });
}

/// Provider for admin dashboard statistics.
final adminDashboardStatsProvider = StreamProvider.autoDispose<DashboardStats>((
  ref,
) {
  final firestore = FirebaseFirestore.instance;
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);

  return firestore
      .collection(AppConstants.colAttendance)
      .where(
        'date',
        isGreaterThanOrEqualTo: startOfDay,
        isLessThan: startOfDay.add(const Duration(days: 1)),
      )
      .snapshots()
      .asyncMap((attendanceSnapshot) async {
        final attendanceDocs = attendanceSnapshot.docs;
        final attendanceData = attendanceDocs.map((doc) => doc.data()).toList();

        int present = 0, absent = 0, late = 0, excused = 0;
        for (final data in attendanceData) {
          final status = data['status'] as String? ?? '';
          if (status == AppConstants.attendancePresent) {
            present++;
          } else if (status == AppConstants.attendanceAbsent) {
            absent++;
          } else if (status == AppConstants.attendanceLate) {
            late++;
          } else if (status == AppConstants.attendanceExcused) {
            excused++;
          }
        }

        // Get counts for other entities
        final studentsSnapshot = await firestore
            .collection(AppConstants.colStudents)
            .get();
        final parentsSnapshot = await firestore
            .collection(AppConstants.colParents)
            .get();
        final teachersSnapshot = await firestore
            .collection(AppConstants.colTeachers)
            .get();
        final busesSnapshot = await firestore
            .collection(AppConstants.colBuses)
            .get();

        final activeBuses = busesSnapshot.docs.where((doc) {
          final data = doc.data();
          return data['status'] == AppConstants.busOnRoute ||
              data['status'] == AppConstants.busAvailable;
        }).length;

        final studentsOnBuses = busesSnapshot.docs
            .map((doc) => doc.data()['studentIds'] as List? ?? [])
            .fold<int>(0, (total, list) => total + list.length);

        return DashboardStats(
          totalStudents: studentsSnapshot.docs.length,
          totalParents: parentsSnapshot.docs.length,
          totalTeachers: teachersSnapshot.docs.length,
          totalBuses: busesSnapshot.docs.length,
          presentToday: present,
          absentToday: absent,
          lateToday: late,
          excusedToday: excused,
          activeBuses: activeBuses,
          studentsOnBuses: studentsOnBuses,
        );
      });
});
