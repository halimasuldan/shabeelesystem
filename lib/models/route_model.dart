import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a route stop with coordinates and order.
class RouteStop {
  final int order;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String? studentId;

  RouteStop({
    required this.order,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    this.studentId,
  });

  factory RouteStop.fromMap(Map<String, dynamic> map) {
    return RouteStop(
      order: map['order'] as int? ?? 0,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      studentId: map['studentId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order': order,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'studentId': studentId,
    };
  }
}

/// Bus route model with ordered stops.
class RouteModel {
  final String id;
  final String name;
  final String startingPoint;
  final String destination;
  final List<RouteStop> stops;
  final String? busId;
  final String? driverId;
  final List<String> studentIds;
  final DateTime createdAt;

  RouteModel({
    required this.id,
    required this.name,
    required this.startingPoint,
    required this.destination,
    required this.stops,
    this.busId,
    this.driverId,
    required this.studentIds,
    required this.createdAt,
  });

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final stopsData = data['stops'] as List? ?? [];
    return RouteModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      startingPoint: data['startingPoint'] as String? ?? '',
      destination: data['destination'] as String? ?? '',
      stops: stopsData
          .map((s) => s is Map<String, dynamic>
              ? RouteStop.fromMap(s)
              : RouteStop(
                  order: stopsData.indexOf(s) + 1,
                  name: s.toString(),
                  latitude: 0,
                  longitude: 0,
                ))
          .toList(),
      busId: data['busId'] as String?,
      driverId: data['driverId'] as String?,
      studentIds:
          List<String>.from(data['studentIds'] as List? ?? []),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startingPoint': startingPoint,
      'destination': destination,
      'stops': stops.map((s) => s.toMap()).toList(),
      'busId': busId,
      'driverId': driverId,
      'studentIds': studentIds,
      'createdAt': createdAt,
    };
  }
}
