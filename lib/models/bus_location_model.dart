import 'package:cloud_firestore/cloud_firestore.dart';

/// Real-time bus location model for GPS tracking.
class BusLocationModel {
  final String id;
  final String busId;
  final String? driverId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String tripStatus; // active, completed, cancelled
  final String? tripId;

  BusLocationModel({
    required this.id,
    required this.busId,
    this.driverId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.tripStatus,
    this.tripId,
  });

  factory BusLocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusLocationModel.fromData(data, doc.id);
  }

  /// Build a location model from a raw data map.
  factory BusLocationModel.fromData(Map<String, dynamic> data, String id) {
    return BusLocationModel(
      id: id,
      busId: data['busId'] as String? ?? '',
      driverId: data['driverId'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tripStatus: data['tripStatus'] as String? ?? 'active',
      tripId: data['tripId'] as String?,
    );
  }

  /// Alias used by screens; same as [fromData].
  factory BusLocationModel.fromMap(
      Map<String, dynamic> data, String id) {
    return BusLocationModel.fromData(data, id);
  }

  Map<String, dynamic> toMap() {
    return {
      'busId': busId,
      'driverId': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'tripStatus': tripStatus,
      'tripId': tripId,
    };
  }
}

/// Bus trip model for tracking driver trips.
class BusTripModel {
  final String id;
  final String busId;
  final String? busNumber;
  final String driverId;
  final String? driverName;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // active, completed, cancelled
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final DateTime createdAt;

  BusTripModel({
    required this.id,
    required this.busId,
    this.busNumber,
    required this.driverId,
    this.driverName,
    required this.startTime,
    this.endTime,
    required this.status,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    required this.createdAt,
  });

  factory BusTripModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusTripModel(
      id: doc.id,
      busId: data['busId'] as String? ?? '',
      busNumber: data['busNumber'] as String?,
      driverId: data['driverId'] as String? ?? '',
      driverName: data['driverName'] as String?,
      startTime:
          (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'active',
      startLatitude: data['startLatitude'] as double?,
      startLongitude: data['startLongitude'] as double?,
      endLatitude: data['endLatitude'] as double?,
      endLongitude: data['endLongitude'] as double?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'busId': busId,
      'busNumber': busNumber,
      'driverId': driverId,
      'driverName': driverName,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'status': status,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'createdAt': createdAt,
    };
  }
}
