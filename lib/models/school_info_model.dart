import 'package:cloud_firestore/cloud_firestore.dart';

/// School information model.
class SchoolInfoModel {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final String? email;
  final String? website;
  final String? logoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  SchoolInfoModel({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    this.email,
    this.website,
    this.logoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  factory SchoolInfoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SchoolInfoModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Shabelle Primary School',
      address: data['address'] as String? ?? '',
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      website: data['website'] as String?,
      logoUrl: data['logoUrl'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'logoUrl': logoUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'metadata': metadata,
    };
  }
}

/// Exam result model.
class ExamResultModel {
  final String id;
  final String studentId;
  final String studentName;
  final String classId;
  final String className;
  final String examType; // midterm, final, quarterly
  final String subject;
  final double score;
  final String grade;
  final DateTime date;
  final String teacherId;
  final String? note;

  ExamResultModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.examType,
    required this.subject,
    required this.score,
    required this.grade,
    required this.date,
    required this.teacherId,
    this.note,
  });

  factory ExamResultModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamResultModel(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      className: data['className'] as String? ?? '',
      examType: data['examType'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      score: (data['score'] as num?)?.toDouble() ?? 0.0,
      grade: data['grade'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      teacherId: data['teacherId'] as String? ?? '',
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'className': className,
      'examType': examType,
      'subject': subject,
      'score': score,
      'grade': grade,
      'date': Timestamp.fromDate(date),
      'teacherId': teacherId,
      'note': note,
    };
  }
}

/// Class model.
class ClassModel {
  final String id;
  final String name;
  final String? description;
  final int? capacity;
  final String? teacherId;
  final String? teacherName;

  ClassModel({
    required this.id,
    required this.name,
    this.description,
    this.capacity,
    this.teacherId,
    this.teacherName,
  });

  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      capacity: data['capacity'] as int?,
      teacherId: data['teacherId'] as String?,
      teacherName: data['teacherName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'capacity': capacity,
      'teacherId': teacherId,
      'teacherName': teacherName,
    };
  }
}

/// Section model.
class SectionModel {
  final String id;
  final String name;
  final String classId;
  final String className;
  final String? teacherId;
  final String? teacherName;

  SectionModel({
    required this.id,
    required this.name,
    required this.classId,
    required this.className,
    this.teacherId,
    this.teacherName,
  });

  factory SectionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SectionModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      className: data['className'] as String? ?? '',
      teacherId: data['teacherId'] as String?,
      teacherName: data['teacherName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'classId': classId,
      'className': className,
      'teacherId': teacherId,
      'teacherName': teacherName,
    };
  }
}
