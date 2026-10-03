import 'package:cloud_firestore/cloud_firestore.dart';

/// Bus model for school transportation.
class BusModel {
  final String id;
  final String busNumber;
  final String plateNumber;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? routeId;
  final String status; // available, on_route, returning, maintenance, offline
  final int capacity;
  final List<String> studentIds;
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime? lastLocationUpdate;
  final String? tripId;
  final DateTime createdAt;

  BusModel({
    required this.id,
    required this.busNumber,
    required this.plateNumber,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.routeId,
    required this.status,
    required this.capacity,
    required this.studentIds,
    this.currentLatitude,
    this.currentLongitude,
    this.lastLocationUpdate,
    this.tripId,
    required this.createdAt,
  });

  factory BusModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusModel(
      id: doc.id,
      busNumber: data['busNumber'] as String? ?? '',
      plateNumber: data['plateNumber'] as String? ?? '',
      driverId: data['driverId'] as String?,
      driverName: data['driverName'] as String?,
      driverPhone: data['driverPhone'] as String?,
      routeId: data['routeId'] as String?,
      status: data['status'] as String? ?? 'available',
      capacity: data['capacity'] as int? ?? 40,
      studentIds:
          List<String>.from(data['studentIds'] as List? ?? []),
      currentLatitude: data['currentLatitude'] as double?,
      currentLongitude: data['currentLongitude'] as double?,
      lastLocationUpdate:
          (data['lastLocationUpdate'] as Timestamp?)?.toDate(),
      tripId: data['tripId'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'busNumber': busNumber,
      'plateNumber': plateNumber,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'routeId': routeId,
      'status': status,
      'capacity': capacity,
      'studentIds': studentIds,
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'lastLocationUpdate': lastLocationUpdate != null
          ? Timestamp.fromDate(lastLocationUpdate!)
          : null,
      'tripId': tripId,
      'createdAt': createdAt,
    };
  }

  BusModel copyWith({
    String? id,
    String? busNumber,
    String? plateNumber,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? routeId,
    String? status,
    int? capacity,
    List<String>? studentIds,
    double? currentLatitude,
    double? currentLongitude,
    DateTime? lastLocationUpdate,
    String? tripId,
    DateTime? createdAt,
  }) {
    return BusModel(
      id: id ?? this.id,
      busNumber: busNumber ?? this.busNumber,
      plateNumber: plateNumber ?? this.plateNumber,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      routeId: routeId ?? this.routeId,
      status: status ?? this.status,
      capacity: capacity ?? this.capacity,
      studentIds: studentIds ?? this.studentIds,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      tripId: tripId ?? this.tripId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
