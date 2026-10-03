import '../../models/attendance_model.dart';

class AttendanceSummary {
  const AttendanceSummary({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
  });

  final int total;
  final int present;
  final int absent;
  final int late;
  final int excused;

  double get attendanceRate => total == 0 ? 0 : (present + late) / total * 100;

  factory AttendanceSummary.fromRecords(Iterable<AttendanceModel> records) {
    var present = 0;
    var absent = 0;
    var late = 0;
    var excused = 0;
    var total = 0;
    for (final record in records) {
      total++;
      switch (record.status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.late:
          late++;
        case AttendanceStatus.excused:
          excused++;
      }
    }
    return AttendanceSummary(
      total: total,
      present: present,
      absent: absent,
      late: late,
      excused: excused,
    );
  }
}

List<AttendanceModel> filterAttendanceRecords(
  Iterable<AttendanceModel> records, {
  DateTime? from,
  DateTime? through,
  String? status,
  String? classId,
}) {
  final start = from == null ? null : DateTime(from.year, from.month, from.day);
  final endExclusive = through == null
      ? null
      : DateTime(
          through.year,
          through.month,
          through.day,
        ).add(const Duration(days: 1));
  final filtered = records.where((record) {
    if (start != null && record.date.isBefore(start)) return false;
    if (endExclusive != null && !record.date.isBefore(endExclusive)) {
      return false;
    }
    if (status != null && record.status != status) return false;
    if (classId != null && record.classId != classId) return false;
    return true;
  }).toList()..sort((a, b) => b.date.compareTo(a.date));
  return filtered;
}
