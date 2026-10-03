import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';

/// Service handling GPS location operations and real-time tracking.
class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();

  LocationService._();

  /// Active GPS position subscription (kept so it can be cancelled on stop).
  StreamSubscription<Position>? _positionSubscription;

  /// Whether location updates are currently streaming.
  bool get isTracking => _positionSubscription != null;

  /// Check if location services are enabled.
  Future<bool> isLocationEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check and request location permissions, returning whether granted.
  Future<bool> requestPermission() async {
    final permission = await checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Check if location services are enabled.
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check and request location permissions.
  Future<LocationPermission> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermission.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermission.deniedForever;
    }

    return permission;
  }

  /// Get the current position.
  Future<Position?> getCurrentPosition() async {
    try {
      final permission = await checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      debugPrint('Get current position error: $e');
      return null;
    }
  }

  /// Get the current address from coordinates.
  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // This would use geocoding package in a real implementation
    return '$latitude, $longitude';
  }

  /// Start sending location updates for a bus.
  /// Called when a driver starts a trip.
  Future<void> startLocationUpdates({
    required String busId,
    String? driverId,
    required String tripId,
  }) async {
    final permission = await checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // Remember the bus so `stopLocationUpdates()` can close the trip out even
    // when it is called without an explicit bus id.
    _lastBusId = busId;

    // Cancel any previous stream so we never double-stream.
    await _positionSubscription?.cancel();

    // Listen to position updates and keep the subscription so it can be
    // cancelled when the trip is ended.
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            distanceFilter: 10, // Update every 10 meters
            accuracy: LocationAccuracy.high,
          ),
        ).listen(
          (Position position) {
            _saveLocationToFirestore(
              busId: busId,
              driverId: driverId,
              tripId: tripId,
              latitude: position.latitude,
              longitude: position.longitude,
            );
          },
          onError: (Object error) {
            debugPrint('Location stream error: $error');
          },
        );

    final initialPosition = await getCurrentPosition();
    if (initialPosition != null) {
      await _saveLocationToFirestore(
        busId: busId,
        driverId: driverId,
        tripId: tripId,
        latitude: initialPosition.latitude,
        longitude: initialPosition.longitude,
      );
    }
  }

  /// Stop location updates.
  /// Called when a driver ends a trip. Cancels the GPS stream and marks the
  /// stored bus location as completed so parents stop seeing a live trip.
  Future<void> stopLocationUpdates({String? busId}) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    final id = busId ?? _lastBusId;
    if (id == null || id.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.colBusLocations)
          .doc(id)
          .set({
            'tripStatus': AppConstants.tripCompleted,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection(AppConstants.colBuses)
          .doc(id)
          .update({'status': AppConstants.busAvailable});
    } catch (e) {
      debugPrint('Stop location updates error: $e');
    }
  }

  /// Remembers the last bus id so [stopLocationUpdates] can close it out
  /// even when called without an explicit bus id.
  String? _lastBusId;

  /// Save location to Firestore for real-time tracking.
  Future<void> _saveLocationToFirestore({
    required String busId,
    required String? driverId,
    required String? tripId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.colBusLocations)
          .doc(busId)
          .set({
            'busId': busId,
            'driverId': driverId,
            'latitude': latitude,
            'longitude': longitude,
            'timestamp': FieldValue.serverTimestamp(),
            'tripId': tripId,
            'tripStatus': 'active',
          }, SetOptions(merge: true));

      // Also update bus document with current location
      await FirebaseFirestore.instance
          .collection(AppConstants.colBuses)
          .doc(busId)
          .update({
            'currentLatitude': latitude,
            'currentLongitude': longitude,
            'lastLocationUpdate': FieldValue.serverTimestamp(),
            'status': AppConstants.busOnRoute,
          });
    } catch (e) {
      debugPrint('Save location error: $e');
    }
  }

  /// Calculate distance between two coordinates.
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Open app settings to enable location.
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Open location settings.
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}
