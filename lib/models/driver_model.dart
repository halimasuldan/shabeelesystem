import 'package:cloud_firestore/cloud_firestore.dart';

/// Driver model assigned to buses.
class DriverModel {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String? licenseNumber;
  final String? licenseExpiry;
  final String? photoUrl;
  final bool isActive;
  final DateTime createdAt;

  /// Verification status set by admin during registration review.
  /// Values: 'pending', 'verified', 'rejected'
  final String status;

  /// Emergency contact name (next of kin).
  final String? emergencyContact;

  /// Emergency contact phone number.
  final String? emergencyContactPhone;

  /// Driver's home address.
  final String? address;

  /// Admin notes about this driver.
  final String? notes;

  DriverModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    this.licenseNumber,
    this.licenseExpiry,
    this.photoUrl,
    this.isActive = true,
    required this.createdAt,
    this.status = 'pending',
    this.emergencyContact,
    this.emergencyContactPhone,
    this.address,
    this.notes,
  });

  /// Authentication UID written onto a bus when this driver is assigned.
  /// Older profiles can have an empty `userId`; those profiles are normally
  /// keyed by the auth UID, so their document ID is the correct fallback.
  String get assignmentUserId => userId.trim().isNotEmpty ? userId.trim() : id;

  factory DriverModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DriverModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      licenseNumber: data['licenseNumber'] as String?,
      licenseExpiry: data['licenseExpiry'] as String?,
      photoUrl: data['photoUrl'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'pending',
      emergencyContact: data['emergencyContact'] as String?,
      emergencyContactPhone: data['emergencyContactPhone'] as String?,
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'licenseNumber': licenseNumber,
      'licenseExpiry': licenseExpiry,
      'photoUrl': photoUrl,
      'isActive': isActive,
      'createdAt': createdAt,
      'status': status,
      'emergencyContact': emergencyContact,
      'emergencyContactPhone': emergencyContactPhone,
      'address': address,
      'notes': notes,
    };
  }

  DriverModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? licenseNumber,
    String? licenseExpiry,
    String? photoUrl,
    bool? isActive,
    DateTime? createdAt,
    String? status,
    String? emergencyContact,
    String? emergencyContactPhone,
    String? address,
    String? notes,
  }) {
    return DriverModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
    );
  }
}
