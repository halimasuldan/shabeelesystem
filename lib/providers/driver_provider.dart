import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase/options.dart';
import '../core/constants/app_constants.dart';
import '../models/bus_model.dart';
import '../models/driver_model.dart';
import '../models/route_model.dart';
import '../models/student_model.dart';
import '../core/utils/driver_roster_utils.dart';
import 'auth_provider.dart';

/// Provider for all drivers.
final driversListProvider = StreamProvider.autoDispose<List<DriverModel>>((
  ref,
) {
  // NOTE: no `.orderBy()` and no server-side `where('isActive')` here on
  // purpose - the pair needs a Firestore composite index, and without it the
  // Drivers list silently fails to load. Filtering runs client-side instead,
  // which also honours the DriverModel default: records created outside the
  // app may not carry `isActive` at all and count as active, while explicitly
  // deactivated drivers (`isActive: false`) still stay hidden. Sorting by name
  // happens here too.
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

/// Provider for pending driver registrations awaiting admin verification.
final pendingDriversProvider = StreamProvider.autoDispose<List<DriverModel>>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colDrivers)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snapshot) {
        final drivers = snapshot.docs
            .map((doc) => DriverModel.fromFirestore(doc))
            .toList();
        drivers.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return drivers;
      });
});

/// Provider for a single driver by user ID.
///
/// Keep-alive on purpose: the driver dashboard watches this on every rebuild.
/// Querying `userId` supports both uid-keyed profiles and older profiles whose
/// document ids differ from the authentication uid. The constrained query is
/// permitted by the driver read rules.
///
/// An `autoDispose` version re-subscribed to the Firestore stream each time a
/// widget re-entered or rebuilt, which flashed the full-screen loading state
/// ("the dashboard comes and goes"). While the provider stays alive the
/// subscription - and the last known data - survive rebuilds.
final driverByUserIdProvider = StreamProvider.family<DriverModel?, String>((
  ref,
  userId,
) {
  final firestore = FirebaseFirestore.instance;
  // Most profiles are keyed directly by the auth uid. Reading that document
  // first avoids depending on a collection-list permission for the dashboard.
  return firestore
      .collection(AppConstants.colDrivers)
      .doc(userId)
      .snapshots()
      .asyncMap((doc) async {
        if (doc.exists) return DriverModel.fromFirestore(doc);

        // Older profiles may use another document id and carry the auth uid
        // in userId. The query is constrained to that uid by the rules.
        final snapshot = await firestore
            .collection(AppConstants.colDrivers)
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();
        return snapshot.docs.isNotEmpty
            ? DriverModel.fromFirestore(snapshot.docs.first)
            : null;
      });
});

/// Every document id the signed-in driver could be referenced by.
///
/// Driver records created by this app are keyed by the auth uid, but legacy
/// records use an arbitrary document id with the auth uid stored in `userId`.
/// A bus may point at either form, so anything that matches a bus to the
/// current driver has to consider both ids.
Future<Set<String>> _driverReferenceIds(String uid) async {
  final ids = <String>{uid};
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.colDrivers)
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) ids.add(snapshot.docs.first.id);
  } catch (e) {
    // Best effort: listing /drivers is admin-only, so this query can be denied
    // for a driver. Falling back to the uid keeps resolution working.
    debugPrint('driverReferenceIds: drivers.userId lookup skipped ($e)');
  }
  return ids;
}

/// The bus currently assigned to the signed-in driver, or null when none is.
///
/// The assignment of record lives on the bus document
/// (`buses/{busId}.driverId`) - that is the field the admin bus screen writes.
/// Driver documents only mirror the reverse link (`drivers/{id}.busId`) when a
/// bus was created with a driver already selected, so resolving
/// `drivers/{uid}.busId` alone left drivers on "No students assigned." even
/// though a bus was assigned to them.
///
/// Each read tolerates a missing document or a denied rule and reports null
/// instead of throwing, so driver screens show a plain empty state rather than
/// a crash.
///
/// Keep-alive (not `autoDispose`): every driver screen awaits this provider,
/// and an auto-disposing one returned to the loading state each time the last
/// listener unmounted - so the dashboard flickered to "N/A" and the student
/// lists flashed "No students assigned" between rebuilds. While it stays
/// alive, Riverpod keeps the previous value attached during a re-resolve, so
/// screens keep showing real data. Use `ref.invalidate(driverBusIdProvider)`
/// (the dashboard's pull-to-refresh does) to force a re-resolution.
final driverBusIdProvider = FutureProvider<String?>((ref) async {
  // Re-resolve when the signed-in account changes, so a driver who signs in
  // after someone else always resolves their own bus.
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final uid = authUser?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';
  if (uid.isEmpty) return null;

  final firestore = FirebaseFirestore.instance;
  final ids = await _driverReferenceIds(uid);

  // The bus assignment is authoritative. Check it before driver.busId, which
  // can be stale when an administrator moves a driver to another bus.
  for (final driverId in ids) {
    try {
      final snapshot = await firestore
          .collection(AppConstants.colBuses)
          .where('driverId', isEqualTo: driverId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first.id;
    } catch (e) {
      debugPrint('driverBusId: buses.driverId lookup failed ($e)');
    }
  }

  // The admin assign dialog mirrors the auth uid onto the bus, which
  //     resolves legacy driver records whose document id is not the uid.
  try {
    final snapshot = await firestore
        .collection(AppConstants.colBuses)
        .where('driverUserId', isEqualTo: uid)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) return snapshot.docs.first.id;
  } catch (e) {
    debugPrint('driverBusId: buses.driverUserId lookup failed ($e)');
  }

  // Buses also record the driver who signed the bus out for the day.
  for (final driverId in ids) {
    try {
      final snapshot = await firestore
          .collection(AppConstants.colBuses)
          .where('currentDriverId', isEqualTo: driverId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first.id;
    } catch (e) {
      debugPrint('driverBusId: buses.currentDriverId lookup failed ($e)');
    }
  }

  // Fall back to the driver's reverse link only when no bus points back to
  // this driver. This supports older assignments without preferring stale data.
  for (final driverId in ids) {
    try {
      final doc = await firestore
          .collection(AppConstants.colDrivers)
          .doc(driverId)
          .get();
      final busId = doc.data()?['busId'] as String?;
      if (busId != null && busId.isNotEmpty) return busId;
    } catch (e) {
      debugPrint('driverBusId: drivers/$driverId read failed ($e)');
    }
  }

  return null;
});

/// The bus document assigned to the signed-in driver, or null when none is.
///
/// Keep-alive so the dashboard's bus card does not flip back to `N/A` while
/// the id is being re-resolved (see [driverBusIdProvider]).
final driverAssignedBusProvider = FutureProvider<BusModel?>((ref) async {
  final busId = await ref.watch(driverBusIdProvider.future);
  if (busId == null || busId.isEmpty) return null;
  try {
    final doc = await FirebaseFirestore.instance
        .collection(AppConstants.colBuses)
        .doc(busId)
        .get();
    if (!doc.exists) return null;
    return BusModel.fromFirestore(doc);
  } catch (e) {
    debugPrint('driverAssignedBus: buses/$busId read failed ($e)');
    return null;
  }
});

/// The students currently riding with the signed-in driver.
///
/// Students carry their bus in `students/{id}.busId`, which is the link the
/// pickup and drop-off screens query. The bus document keeps a separate
/// `studentIds` mirror that only the admin assignment screen writes, so
/// counting from the students collection keeps the dashboard number in step
/// with the list the driver actually sees.
///
/// Keep-alive: this is the shared source of truth for the dashboard and both
/// run screens. As an `autoDispose` provider it restarted every time the
/// screen changed, briefly yielding an empty list that rendered as "No
/// students assigned" even though the query was about to return data.
final driverStudentsProvider = StreamProvider<List<StudentModel>>((ref) async* {
  final busId = await ref.watch(driverBusIdProvider.future);
  if (busId == null || busId.isEmpty) {
    yield const [];
    return;
  }
  final firestore = FirebaseFirestore.instance;
  yield* FirebaseFirestore.instance
      .collection(AppConstants.colStudents)
      .where('busId', isEqualTo: busId)
      .snapshots()
      .asyncMap((snapshot) async {
        final studentsById = <String, StudentModel>{
          for (final doc in snapshot.docs)
            doc.id: StudentModel.fromFirestore(doc),
        };

        // Older assignment flows sometimes updated buses.studentIds without
        // updating students.busId. Include those roster entries, but do not
        // resurrect stale mirror entries already assigned to another bus.
        final busDoc = await firestore
            .collection(AppConstants.colBuses)
            .doc(busId)
            .get();
        final assignedIds = List<String>.from(
          busDoc.data()?['studentIds'] as List? ?? const <String>[],
        );
        final missingIds = assignedIds
            .where((studentId) => !studentsById.containsKey(studentId))
            .toSet();
        final missingDocs = await Future.wait(
          missingIds.map(
            (studentId) => firestore
                .collection(AppConstants.colStudents)
                .doc(studentId)
                .get(),
          ),
        );
        for (final doc in missingDocs) {
          if (!doc.exists) continue;
          final student = StudentModel.fromFirestore(doc);
          if (student.status == 'active' &&
              (student.busId == null ||
                  student.busId!.isEmpty ||
                  student.busId == busId)) {
            studentsById[student.id] = student;
          }
        }

        return resolveDriverRoster(
          busId: busId,
          studentsByBusId: studentsById.values,
          mirroredStudents: const <StudentModel>[],
        );
      });
});

/// The route the signed-in driver is currently operating, or null.
///
/// The bus link is stored in either direction depending on which admin screen
/// created it: the Route screen writes `routes/{id}.busId` and
/// `routes/{id}.driverId`, while the Bus screen writes `buses/{id}.routeId`.
/// Reading only one of the two left the driver with "No route data available",
/// so both are tried, then a match by driver id.
///
/// Keep-alive so reopening the route map does not flash its loading state
/// while the bus/route chain re-resolves.
final driverRouteProvider = FutureProvider<RouteModel?>((ref) async {
  final firestore = FirebaseFirestore.instance;
  final bus = await ref.watch(driverAssignedBusProvider.future);
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // 1. Link stored on the bus document.
  final routeId = bus?.routeId;
  if (routeId != null && routeId.isNotEmpty) {
    try {
      final doc = await firestore
          .collection(AppConstants.colRoutes)
          .doc(routeId)
          .get();
      if (doc.exists) return RouteModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('driverRoute: routes/$routeId read failed ($e)');
    }
  }

  // 2. Link stored on the route document, by bus...
  final busId = bus?.id;
  if (busId != null && busId.isNotEmpty) {
    try {
      final snapshot = await firestore
          .collection(AppConstants.colRoutes)
          .where('busId', isEqualTo: busId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return RouteModel.fromFirestore(snapshot.docs.first);
      }
    } catch (e) {
      debugPrint('driverRoute: routes.busId lookup failed ($e)');
    }
  }

  // 3. ...or by the driver the route is assigned to.
  if (uid.isNotEmpty) {
    for (final driverId in await _driverReferenceIds(uid)) {
      try {
        final snapshot = await firestore
            .collection(AppConstants.colRoutes)
            .where('driverId', isEqualTo: driverId)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty) {
          return RouteModel.fromFirestore(snapshot.docs.first);
        }
      } catch (e) {
        debugPrint('driverRoute: routes.driverId lookup failed ($e)');
      }
    }
  }

  return null;
});

/// Provider for the driver CRUD controller.
final driverCrudProvider =
    StateNotifierProvider<DriverCrudNotifier, AsyncValue<void>>((ref) {
      return DriverCrudNotifier();
    });

/// Provider for driver registration (creates auth account + Firestore doc with status='pending').
final driverProvider =
    StateNotifierProvider<DriverRegistrationNotifier, AsyncValue<void>>(
      (ref) => DriverRegistrationNotifier(),
    );

class DriverRegistrationNotifier extends StateNotifier<AsyncValue<void>> {
  DriverRegistrationNotifier() : super(const AsyncData(null));

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> registerDriver({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? licenseNumber,
    String? licenseExpiry,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? address,
  }) async {
    state = const AsyncLoading();
    FirebaseApp? secondaryApp;
    try {
      // Do not replace the administrator's primary Firebase Auth session.
      secondaryApp = await Firebase.initializeApp(
        name: 'driverRegistration-${DateTime.now().microsecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final credential = await FirebaseAuth.instanceFor(
        app: secondaryApp,
      ).createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid;

      final now = DateTime.now();
      final driver = DriverModel(
        id: uid,
        userId: uid,
        name: name,
        email: email,
        phone: phone,
        licenseNumber: licenseNumber,
        licenseExpiry: licenseExpiry,
        address: address,
        isActive: true,
        createdAt: now,
        status: 'pending',
        emergencyContact: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
      );

      await _firestore
          .collection(AppConstants.colDrivers)
          .doc(uid)
          .set(driver.toMap());

      // Also create the /users doc so role resolution (userRoleProvider) and
      // the router's redirect can see this driver after sign-in.
      await _firestore.collection(AppConstants.colUsers).doc(uid).set({
        'name': name,
        'email': email,
        'role': AppConstants.roleDriver,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      state = const AsyncData(null);
    } on FirebaseAuthException catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    } finally {
      await secondaryApp?.delete();
    }
  }
}

class DriverCrudNotifier extends StateNotifier<AsyncValue<void>> {
  DriverCrudNotifier() : super(const AsyncData(null));

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createDriver(DriverModel driver) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colDrivers)
          .doc(driver.id)
          .set(driver.toMap());
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateDriver(DriverModel driver) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colDrivers)
          .doc(driver.id)
          .update(driver.toMap());
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deleteDriver(String driverId) async {
    state = const AsyncLoading();
    try {
      await _firestore.collection(AppConstants.colDrivers).doc(driverId).update(
        {'isActive': false},
      );
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Update a driver's verification status (pending/verified/rejected).
  Future<void> updateDriverStatus(
    String driverId,
    String status, {
    String? notes,
  }) async {
    state = const AsyncLoading();
    try {
      await _firestore.collection(AppConstants.colDrivers).doc(driverId).update(
        {'status': status, if (notes != null) 'notes': notes},
      );
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }
}
