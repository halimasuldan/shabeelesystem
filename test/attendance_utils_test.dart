import 'package:flutter_test/flutter_test.dart';
import 'package:shabelle_system/core/utils/attendance_utils.dart';
import 'package:shabelle_system/models/attendance_model.dart';

AttendanceModel attendance(
  String id,
  String status,
  DateTime date, {
  String classId = 'class-1',
}) => AttendanceModel(
  id: id,
  studentId: 'student-$id',
  studentName: 'Student $id',
  classId: classId,
  className: 'Grade 1',
  date: date,
  time: '08:00 AM',
  status: status,
  teacherId: 'teacher-1',
  createdAt: date,
);

void main() {
  final records = [
    attendance('present', AttendanceStatus.present, DateTime(2026, 9, 30)),
    attendance('late', AttendanceStatus.late, DateTime(2026, 10, 1)),
    attendance(
      'absent',
      AttendanceStatus.absent,
      DateTime(2026, 10, 1),
      classId: 'class-2',
    ),
    attendance('excused', AttendanceStatus.excused, DateTime(2026, 10, 2)),
  ];

  test('filters date range inclusively and sorts newest first', () {
    final result = filterAttendanceRecords(
      records,
      from: DateTime(2026, 10, 1),
      through: DateTime(2026, 10, 1),
    );
    expect(result.map((record) => record.id), ['late', 'absent']);
  });

  test('filters class and status together', () {
    final result = filterAttendanceRecords(
      records,
      status: AttendanceStatus.absent,
      classId: 'class-2',
    );
    expect(result.map((record) => record.id), ['absent']);
  });

  test('summarizes all statuses and attendance rate', () {
    final summary = AttendanceSummary.fromRecords(records);
    expect(summary.total, 4);
    expect(summary.present, 1);
    expect(summary.absent, 1);
    expect(summary.late, 1);
    expect(summary.excused, 1);
    expect(summary.attendanceRate, 50);
  });
}
