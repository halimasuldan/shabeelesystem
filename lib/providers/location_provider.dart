import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants/app_constants.dart';
import '../core/services/location_service.dart';
import '../models/bus_location_model.dart';

/// Provider for the real-time bus location stream.
final busLocationProvider = StreamProvider.autoDispose
    .family<BusLocationModel?, String>((ref, busId) {
      return FirebaseFirestore.instance
          .collection(AppConstants.colBusLocations)
          .doc(busId)
          .snapshots()
          .map(
            (doc) => doc.exists ? BusLocationModel.fromFirestore(doc) : null,
          );
    });

/// Provider for all active buses on the map.
final activeBusesLocationProvider =
    StreamProvider.autoDispose<List<BusLocationModel>>((ref) {
      return FirebaseFirestore.instance
          .collection(AppConstants.colBusLocations)
          .where('tripStatus', isEqualTo: AppConstants.tripActive)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => BusLocationModel.fromFirestore(doc))
                .toList(),
          );
    });

/// Provider for the location service.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService.instance;
});

/// State provider for tracking if location updates are active.
final isTrackingProvider = StateProvider<bool>((ref) => false);

/// Provider for the current position (used by driver during trip).
final currentPositionProvider = FutureProvider.autoDispose<Position?>((
  ref,
) async {
  final service = ref.watch(locationServiceProvider);
  return await service.getCurrentPosition();
});

/// Provider for the location tracking controller.
final locationControllerProvider =
    StateNotifierProvider<LocationController, bool>((ref) {
      return LocationController(ref.watch(locationServiceProvider));
    });

/// Controller that starts/stops GPS tracking for a bus trip.
class LocationController extends StateNotifier<bool> {
  LocationController(this._service) : super(false);

  final LocationService _service;

  /// Start streaming location updates for the given bus trip.
  Future<void> startTracking(
    String busId,
    String tripId, {
    String? driverId,
  }) async {
    await _service.startLocationUpdates(
      busId: busId,
      driverId: driverId,
      tripId: tripId,
    );
    state = true;
  }

  /// Stop location tracking and close out the trip.
  ///
  /// Passing [busId] ensures the stored bus location is marked completed so
  /// parents stop seeing a live trip even if tracking started elsewhere.
  Future<void> stopTracking({String? busId}) async {
    await _service.stopLocationUpdates(busId: busId);
    state = false;
  }
}
