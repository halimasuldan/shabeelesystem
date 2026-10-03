import 'package:cloud_firestore/cloud_firestore.dart';

/// Parent model linking to one or more students.
class ParentModel {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? address;
  final List<String> studentIds;
  final String? photoUrl;
  final DateTime createdAt;

  ParentModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.address,
    required this.studentIds,
    this.photoUrl,
    required this.createdAt,
  });

  factory ParentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParentModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String?,
      address: data['address'] as String?,
      studentIds:
          List<String>.from(data['studentIds'] as List? ?? []),
      photoUrl: data['photoUrl'] as String?,
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
      'address': address,
      'studentIds': studentIds,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
    };
  }

  ParentModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? address,
    List<String>? studentIds,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return ParentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      studentIds: studentIds ?? this.studentIds,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
