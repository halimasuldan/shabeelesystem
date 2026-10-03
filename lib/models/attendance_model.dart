import 'package:cloud_firestore/cloud_firestore.dart';

/// Constants for attendance status values.
class AttendanceStatus {
  static const String present = 'present';
  static const String absent = 'absent';
  static const String late = 'late';
  static const String excused = 'excused';
}

/// Attendance model for student presence tracking.
class AttendanceModel {
  final String id;
  final String studentId;
  final String studentName;
  final String classId;
  final String className;
  final String? sectionId;
  final DateTime date;
  final String time;
  final String status; // present, absent, late, excused
  final String teacherId;
  final String? teacherName;
  final String? note;
  final DateTime createdAt;

  AttendanceModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    this.sectionId,
    required this.date,
    required this.time,
    required this.status,
    required this.teacherId,
    this.teacherName,
    this.note,
    required this.createdAt,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      className: data['className'] as String? ?? '',
      sectionId: data['sectionId'] as String?,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      time: data['time'] as String? ?? '',
      status: data['status'] as String? ?? 'present',
      teacherId: data['teacherId'] as String? ?? '',
      teacherName: data['teacherName'] as String?,
      note: data['note'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'className': className,
      'sectionId': sectionId,
      'date': Timestamp.fromDate(date),
      'time': time,
      'status': status,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'note': note,
      'createdAt': createdAt,
    };
  }

  AttendanceModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? classId,
    String? className,
    String? sectionId,
    DateTime? date,
    String? time,
    String? status,
    String? teacherId,
    String? teacherName,
    String? note,
    DateTime? createdAt,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      sectionId: sectionId ?? this.sectionId,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
