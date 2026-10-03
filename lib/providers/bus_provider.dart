import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/driver_model.dart';
import '../models/bus_trip_model.dart';

/// Provider for all buses.
final busesProvider = StreamProvider.autoDispose<List<BusModel>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colBuses)
      .orderBy('busNumber')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => BusModel.fromFirestore(doc)).toList(),
      );
});

/// Provider for a single bus by ID.
final busProvider = StreamProvider.autoDispose.family<BusModel?, String>((
  ref,
  busId,
) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colBuses)
      .doc(busId)
      .snapshots()
      .map((doc) => doc.exists ? BusModel.fromFirestore(doc) : null);
});

/// Provider for all routes.
final routesProvider = StreamProvider.autoDispose<List<RouteModel>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colRoutes)
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList(),
      );
});

/// Provider for a single route by ID.
final routeProvider = StreamProvider.autoDispose.family<RouteModel?, String>((
  ref,
  routeId,
) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colRoutes)
      .doc(routeId)
      .snapshots()
      .map((doc) => doc.exists ? RouteModel.fromFirestore(doc) : null);
});

/// Provider for a bus assigned to a specific driver.
final driverBusProvider = StreamProvider.autoDispose.family<BusModel?, String>((
  ref,
  driverId,
) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colBuses)
      .where('driverId', isEqualTo: driverId)
      .limit(1)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.isNotEmpty
            ? BusModel.fromFirestore(snapshot.docs.first)
            : null,
      );
});

/// Provider for all drivers available for assignment.
final driversProvider = StreamProvider.autoDispose<List<DriverModel>>((ref) {
  // NOTE: no `.orderBy()` and no server-side `where('isActive')` here on
  // purpose - combining them needs a composite index, and without it this
  // query fails and the bus screen's "Assign Driver" dropdown stays empty, so
  // no driver could ever be attached to a bus. Filtering runs client-side so
  // the DriverModel default applies: a driver record created outside the app
  // without an `isActive` field still appears, while deactivated drivers
  // (`isActive: false`) do not. Sort client-side as well (same approach as
  // `driversListProvider`).
  return FirebaseFirestore.instance
      .collection(AppConstants.colDrivers)
      .snapshots()
      .map((snapshot) {
        final drivers = snapshot.docs
            .map((doc) => DriverModel.fromFirestore(doc))
            .where((driver) => driver.isActive)
            .toList();
        drivers.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return drivers;
      });
});

/// Provider for the bus CRUD controller.
final busCrudProvider =
    StateNotifierProvider<BusCrudNotifier, AsyncValue<void>>((ref) {
      return BusCrudNotifier();
    });

/// Controller for bus and route CRUD operations.
class BusCrudNotifier extends StateNotifier<AsyncValue<void>> {
  BusCrudNotifier() : super(const AsyncData(null));

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createBus(BusModel bus) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colBuses)
          .doc(bus.id)
          .set(bus.toMap());
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateBus(BusModel bus) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colBuses)
          .doc(bus.id)
          .update(bus.toMap());
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deleteBus(String busId) async {
    state = const AsyncLoading();
    try {
      await _firestore.collection(AppConstants.colBuses).doc(busId).delete();
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> assignDriverToBus(
    String busId,
    String driverId,
    String driverName,
    String driverPhone, {
    String? driverUid,
  }) async {
    try {
      await _firestore.collection(AppConstants.colBuses).doc(busId).update({
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        // `driverId` is the /drivers document id. Legacy driver records use a
        // non-uid document id, so the auth uid is recorded separately in
        // `currentDriverId`; the driver portal resolves its bus from either
        // field (see `driverBusIdProvider`).
        if (driverUid != null && driverUid.isNotEmpty)
          'currentDriverId': driverUid,
      });
      // Mirror the link onto the driver document as well: the driver portal
      // reads `drivers/{id}.busId` when it exists, and admins expect the driver
      // record to show the bus they were attached to.
      await _syncDriverReverseLink(driverId, busId);
      if (driverUid != null && driverUid.isNotEmpty) {
        await _syncDriverReverseLink(driverUid, busId);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Assign a driver and/or a route to a bus, writing both directions of each
  /// link.
  ///
  /// `buses/{id}.driverId` is the assignment of record, but the driver portal
  /// also resolves `drivers/{driverId}.busId`, so the reverse link is mirrored
  /// here. Leaving it out is what made an assigned driver see no bus, no
  /// students and no route.
  Future<void> assignBusResources({
    required String busId,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverUid,
    String? routeId,
  }) async {
    await _firestore.collection(AppConstants.colBuses).doc(busId).update({
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      if (driverUid != null && driverUid.isNotEmpty)
        'currentDriverId': driverUid,
      'routeId': routeId,
    });
    if (driverId != null && driverId.isNotEmpty) {
      await _syncDriverReverseLink(driverId, busId);
    }
    if (driverUid != null && driverUid.isNotEmpty && driverUid != driverId) {
      await _syncDriverReverseLink(driverUid, busId);
    }
    if (routeId != null && routeId.isNotEmpty) {
      await _syncRouteReverseLink(routeId, busId);
    }
  }

  /// Link a route to a bus from the route side, mirroring `buses/{id}.routeId`.
  Future<void> linkRouteToBus(String routeId, String busId) async {
    await _syncRouteReverseLink(routeId, busId);
    await _firestore.collection(AppConstants.colBuses).doc(busId).update({
      'routeId': routeId,
    });
  }

  /// Mirror `buses/{busId}.driverId` onto the driver document.
  ///
  /// Best effort: a legacy driver record is keyed by an arbitrary document id
  /// and `update` throws when the document is missing, which must not abort the
  /// assignment itself.
  Future<void> _syncDriverReverseLink(String driverId, String busId) async {
    try {
      await _firestore.collection(AppConstants.colDrivers).doc(driverId).update(
        {'busId': busId},
      );
    } catch (e) {
      debugPrint('Reverse driver link skipped for $driverId: $e');
    }
  }

  /// Mirror `buses/{busId}.routeId` onto the route document.
  Future<void> _syncRouteReverseLink(String routeId, String busId) async {
    try {
      await _firestore.collection(AppConstants.colRoutes).doc(routeId).update({
        'busId': busId,
      });
    } catch (e) {
      debugPrint('Reverse route link skipped for $routeId: $e');
    }
  }

  Future<void> assignStudentToBus(String busId, String studentId) async {
    try {
      await _firestore.collection(AppConstants.colBuses).doc(busId).update({
        'studentIds': FieldValue.arrayUnion([studentId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createRoute(RouteModel route) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colRoutes)
          .doc(route.id)
          .set(route.toMap());
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateRoute(RouteModel route) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colRoutes)
          .doc(route.id)
          .update(route.toMap());
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> assignRouteToBus(String busId, String routeId) async {
    try {
      await _firestore.collection(AppConstants.colBuses).doc(busId).update({
        'routeId': routeId,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> startTrip(BusTripModel trip) async {
    state = const AsyncLoading();
    try {
      final ref = await _firestore
          .collection(AppConstants.colBusTrips)
          .add(trip.toMap());
      await _firestore.collection(AppConstants.colBuses).doc(trip.busId).update(
        {'tripId': ref.id, 'status': AppConstants.busOnRoute},
      );
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> endTrip(String tripId, String busId) async {
    state = const AsyncLoading();
    try {
      await _firestore.collection(AppConstants.colBusTrips).doc(tripId).update({
        'status': AppConstants.tripCompleted,
        'endTime': FieldValue.serverTimestamp(),
      });
      await _firestore.collection(AppConstants.colBuses).doc(busId).update({
        'tripId': null,
        'status': AppConstants.busAvailable,
      });
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }
}
