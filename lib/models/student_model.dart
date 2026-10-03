import 'package:cloud_firestore/cloud_firestore.dart';

/// Student model representing a child enrolled in the school.
class StudentModel {
  final String id;
  final String studentCode;
  final String fullName;
  final String gender;
  final DateTime? dateOfBirth;
  final String classId;
  final String className;
  final String? sectionId;
  final String? sectionName;
  final List<String> parentIds;
  final String? busId;
  final String address;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String? photoUrl;
  final String status; // 'active' or 'inactive'

  /// Latest state of the morning run (home -> school) for this child.
  ///
  /// Mirrored from the newest `pickup_dropoff` event whose `tripType` is
  /// `morning`, so the driver's pickup list and the parent's status card agree
  /// with the timeline without re-reading the event collection.
  final String pickupStatus;

  /// Latest state of the afternoon run (school -> home) for this child.
  final String dropoffStatus;

  final DateTime createdAt;
  final DateTime updatedAt;

  StudentModel({
    required this.id,
    required this.studentCode,
    required this.fullName,
    required this.gender,
    this.dateOfBirth,
    required this.classId,
    required this.className,
    this.sectionId,
    this.sectionName,
    required this.parentIds,
    this.busId,
    required this.address,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.photoUrl,
    required this.status,
    this.pickupStatus = 'waiting',
    this.dropoffStatus = 'waiting',
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentModel(
      id: doc.id,
      studentCode: data['studentCode'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      gender: data['gender'] as String? ?? '',
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate(),
      classId: data['classId'] as String? ?? '',
      className: data['className'] as String? ?? '',
      sectionId: data['sectionId'] as String?,
      sectionName: data['sectionName'] as String?,
      parentIds: List<String>.from(data['parentIds'] as List? ?? []),
      busId: data['busId'] as String?,
      address: data['address'] as String? ?? '',
      emergencyContactName: data['emergencyContactName'] as String? ?? '',
      emergencyContactPhone: data['emergencyContactPhone'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      status: data['status'] as String? ?? 'active',
      pickupStatus: data['pickupStatus'] as String? ?? 'waiting',
      dropoffStatus: data['dropoffStatus'] as String? ?? 'waiting',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Latest run status for [field], i.e. `'pickupStatus'` / `'dropoffStatus'`.
  ///
  /// The driver's run screens are generic over the run, so they read the state
  /// through this rather than branching on the field name.
  String statusForField(String field) =>
      field == 'dropoffStatus' ? dropoffStatus : pickupStatus;

  /// `toMap` deliberately omits [pickupStatus] / [dropoffStatus].
  ///
  /// Those two fields are owned by the driver portal's pickup / drop-off writes
  /// (`PickupDropoffService.recordEvent`). Folding them into the map would let
  /// an unrelated admin edit - which round-trips the whole student document -
  /// silently reset a child's current run status.
  Map<String, dynamic> toMap() {
    return {
      'studentCode': studentCode,
      'fullName': fullName,
      'gender': gender,
      'dateOfBirth': dateOfBirth != null
          ? Timestamp.fromDate(dateOfBirth!)
          : null,
      'classId': classId,
      'className': className,
      'sectionId': sectionId,
      'sectionName': sectionName,
      'parentIds': parentIds,
      'busId': busId,
      'address': address,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'photoUrl': photoUrl,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  StudentModel copyWith({
    String? id,
    String? studentCode,
    String? fullName,
    String? gender,
    DateTime? dateOfBirth,
    String? classId,
    String? className,
    String? sectionId,
    String? sectionName,
    List<String>? parentIds,
    String? busId,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? photoUrl,
    String? status,
    String? pickupStatus,
    String? dropoffStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentModel(
      id: id ?? this.id,
      studentCode: studentCode ?? this.studentCode,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      sectionId: sectionId ?? this.sectionId,
      sectionName: sectionName ?? this.sectionName,
      parentIds: parentIds ?? this.parentIds,
      busId: busId ?? this.busId,
      address: address ?? this.address,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      pickupStatus: pickupStatus ?? this.pickupStatus,
      dropoffStatus: dropoffStatus ?? this.dropoffStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
