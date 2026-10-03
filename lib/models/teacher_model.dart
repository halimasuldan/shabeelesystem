import 'package:cloud_firestore/cloud_firestore.dart';

/// Teacher model with assigned classes.
class TeacherModel {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final List<String> classIds;
  final List<String> className;
  final String? photoUrl;
  final bool isActive;
  final DateTime createdAt;

  TeacherModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    required this.classIds,
    required this.className,
    this.photoUrl,
    this.isActive = true,
    required this.createdAt,
  });

  factory TeacherModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeacherModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String?,
      classIds:
          List<String>.from(data['classIds'] as List? ?? []),
      className:
          List<String>.from(data['className'] as List? ?? []),
      photoUrl: data['photoUrl'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'classIds': classIds,
      'className': className,
      'photoUrl': photoUrl,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }
}
