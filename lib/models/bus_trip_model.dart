import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a bus trip (morning/afternoon route run).
class BusTripModel {
  final String id;
  final String busId;
  final String driverId;
  final String? routeId;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // active, completed, cancelled

  BusTripModel({
    required this.id,
    required this.busId,
    required this.driverId,
    this.routeId,
    required this.startTime,
    this.endTime,
    required this.status,
  });

  factory BusTripModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusTripModel(
      id: doc.id,
      busId: data['busId'] as String? ?? '',
      driverId: data['driverId'] as String? ?? '',
      routeId: data['routeId'] as String?,
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'active',
    );
  }

  factory BusTripModel.fromMap(Map<String, dynamic> data, String id) {
    return BusTripModel(
      id: id,
      busId: data['busId'] as String? ?? '',
      driverId: data['driverId'] as String? ?? '',
      routeId: data['routeId'] as String?,
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'busId': busId,
      'driverId': driverId,
      'routeId': routeId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'status': status,
    };
  }

  /// Duration of the trip, or running duration if still active.
  Duration get duration =>
      (endTime ?? DateTime.now()).difference(startTime);

  bool get isActive => status == 'active';

  BusTripModel copyWith({
    String? id,
    String? busId,
    String? driverId,
    String? routeId,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
  }) {
    return BusTripModel(
      id: id ?? this.id,
      busId: busId ?? this.busId,
      driverId: driverId ?? this.driverId,
      routeId: routeId ?? this.routeId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
    );
  }
}