import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../models/bus_location_model.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';

/// Live bus tracking map screen for parents.
class BusTrackingMapScreen extends ConsumerStatefulWidget {
  const BusTrackingMapScreen({super.key});
  @override
  ConsumerState<BusTrackingMapScreen> createState() =>
      _BusTrackingMapScreenState();
}

class _BusTrackingMapScreenState extends ConsumerState<BusTrackingMapScreen> {
  GoogleMapController? _mapController;
  String? _busId;
  String? _message;
  bool _loading = true;
  BusLocationModel? _latestLocation;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _locationStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tripStream;
  String? _activeTripId;
  bool _tripStatusLoaded = false;
  Timer? _staleLocationTimer;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = const [];

  @override
  void initState() {
    super.initState();
    _loadBusAssignment();
    _staleLocationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final location = _latestLocation;
      if (location != null) {
        _addBusMarker(location.latitude, location.longitude);
      }
    });
  }

  Future<void> _loadBusAssignment() async {
    try {
      final userId = AuthService().currentUser?.uid ?? '';
      final parentDoc = await FirebaseFirestore.instance
          .collection(AppConstants.colParents)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (parentDoc.docs.isEmpty) {
        _setMessage('No parent profile found.');
        return;
      }
      final data = parentDoc.docs.first.data();
      final studentIds = List<String>.from(data['studentIds'] as List? ?? []);
      if (studentIds.isEmpty) {
        _setMessage('No children linked to this account.');
        return;
      }

      String? busId;
      for (final studentId in studentIds) {
        final studentDoc = await FirebaseFirestore.instance
            .collection(AppConstants.colStudents)
            .doc(studentId)
            .get();
        final candidate = studentDoc.data()?['busId'] as String?;
        if (candidate != null && candidate.isNotEmpty) {
          busId = candidate;
          break;
        }
      }
      if (busId == null) {
        _setMessage('No bus is assigned to your children.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _busId = busId;
        _loading = false;
      });
      _startLocationStream();
      _startTripStream();
      _loadRoute();
    } catch (error) {
      _setMessage('Unable to load bus tracking: $error');
    }
  }

  void _setMessage(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = message;
    });
  }

  void _startLocationStream() {
    if (_busId == null) return;
    _locationStream = FirebaseFirestore.instance
        .collection(AppConstants.colBusLocations)
        .doc(_busId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final loc = BusLocationModel.fromMap(
                snapshot.data() as Map<String, dynamic>,
                snapshot.id,
              );
              if (loc.latitude < -90 ||
                  loc.latitude > 90 ||
                  loc.longitude < -180 ||
                  loc.longitude > 180 ||
                  (loc.latitude == 0 && loc.longitude == 0)) {
                _setMessage('The bus has shared an invalid location.');
                return;
              }
              _latestLocation = loc;
              _updateCamera(loc.latitude, loc.longitude);
              _addBusMarker(loc.latitude, loc.longitude);
            } else if (mounted) {
              setState(() => _latestLocation = null);
            }
          },
          onError: (Object error) {
            _setMessage('Unable to load live bus location: $error');
          },
        );
  }

  void _startTripStream() {
    final busId = _busId;
    if (busId == null) return;
    _tripStream = FirebaseFirestore.instance
        .collection(AppConstants.colBusTrips)
        .where('busId', isEqualTo: busId)
        .snapshots()
        .listen(
          (snapshot) {
            final activeTrips =
                snapshot.docs
                    .where(
                      (doc) => doc.data()['status'] == AppConstants.tripActive,
                    )
                    .toList()
                  ..sort((a, b) {
                    return (_tripStart(b.data())?.millisecondsSinceEpoch ?? 0)
                        .compareTo(
                          _tripStart(a.data())?.millisecondsSinceEpoch ?? 0,
                        );
                  });
            if (!mounted) return;
            setState(() {
              _activeTripId = activeTrips.firstOrNull?.id;
              _tripStatusLoaded = true;
            });
            final location = _latestLocation;
            if (location != null) {
              _addBusMarker(location.latitude, location.longitude);
              if (!_locationBelongsToActiveTrip) _focusRoute();
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _tripStatusLoaded = true;
              _message = 'Unable to load trip status: $error';
            });
          },
        );
  }

  DateTime? _tripStart(Map<String, dynamic> trip) {
    final value = trip['startTime'] ?? trip['createdAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool get _hasActiveTrip => _activeTripId != null;

  bool get _locationBelongsToActiveTrip =>
      _latestLocation != null &&
      _activeTripId != null &&
      _latestLocation!.tripId == _activeTripId;

  bool get _locationIsStale =>
      _latestLocation != null &&
      (DateTime.now().difference(_latestLocation!.timestamp) >
              const Duration(minutes: 2) ||
          (_activeTripId != null && _latestLocation!.tripId != _activeTripId));

  Future<void> _loadRoute() async {
    if (_busId == null) return;
    try {
      final busDoc = await FirebaseFirestore.instance
          .collection(AppConstants.colBuses)
          .doc(_busId)
          .get();
      var loadedRoute = false;
      if (busDoc.exists) {
        final data = busDoc.data() as Map<String, dynamic>;
        final routeId = data['routeId'] as String?;
        if (routeId != null && routeId.isNotEmpty) {
          final routeDoc = await FirebaseFirestore.instance
              .collection(AppConstants.colRoutes)
              .doc(routeId)
              .get();
          if (routeDoc.exists) {
            final r = routeDoc.data() as Map<String, dynamic>;
            final stops = r['stops'] as List? ?? [];
            _addRoutePolylines(stops);
            loadedRoute = true;
          }
        }
      }
      if (!loadedRoute) {
        final routes = await FirebaseFirestore.instance
            .collection(AppConstants.colRoutes)
            .where('busId', isEqualTo: _busId)
            .limit(1)
            .get();
        if (routes.docs.isNotEmpty) {
          final stops = routes.docs.first.data()['stops'] as List? ?? [];
          _addRoutePolylines(stops);
        }
      }
    } catch (error) {
      _setMessage('Unable to load the bus route: $error');
    }
  }

  void _addRoutePolylines(List stops) {
    final orderedStops = List<dynamic>.from(stops)
      ..sort((a, b) {
        final aOrder = a is Map ? (a['order'] as num?)?.toInt() ?? 0 : 0;
        final bOrder = b is Map ? (b['order'] as num?)?.toInt() ?? 0 : 0;
        return aOrder.compareTo(bOrder);
      });
    final List<LatLng> points = [];
    for (var stop in orderedStops) {
      if (stop is! Map<String, dynamic>) continue;
      final s = stop;
      final latitude = (s['latitude'] as num?)?.toDouble();
      final longitude = (s['longitude'] as num?)?.toDouble();
      if (latitude == null ||
          longitude == null ||
          (latitude == 0 && longitude == 0)) {
        continue;
      }
      points.add(LatLng(latitude, longitude));
    }
    _routePoints = points;
    if (points.length > 1) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: AppColors.schoolBlue,
          width: 4,
        ),
      );
    }
    if (points.isNotEmpty) {
      _addMarker(
        LatLng(points.first.latitude, points.first.longitude),
        'Start',
        Icons.location_on,
      );
      _addMarker(
        LatLng(points.last.latitude, points.last.longitude),
        'School',
        Icons.school,
      );
    }
    if (mounted) {
      setState(() {});
      if (_latestLocation == null) _focusRoute();
    }
  }

  void _addBusMarker(double lat, double lng) {
    _markers.removeWhere((marker) => marker.markerId.value == 'bus');
    final location = _latestLocation;
    final isStale = location != null && _locationIsStale;
    _markers.add(
      Marker(
        markerId: const MarkerId('bus'),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(
          title: _hasActiveTrip && _locationBelongsToActiveTrip && !isStale
              ? 'Live school bus'
              : 'Last known bus location',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
    if (mounted) setState(() {});
  }

  void _addMarker(LatLng pos, String title, IconData icon) {
    _markers.add(
      Marker(
        markerId: MarkerId(title),
        position: pos,
        infoWindow: InfoWindow(title: title),
      ),
    );
  }

  void _updateCamera(double lat, double lng) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 15),
      ),
    );
  }

  void _focusRoute() {
    final controller = _mapController;
    if (controller == null ||
        _routePoints.isEmpty ||
        (_latestLocation != null &&
            (!_hasActiveTrip || _locationBelongsToActiveTrip))) {
      return;
    }
    if (_routePoints.length == 1) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_routePoints.first, 14),
      );
      return;
    }

    final latitudes = _routePoints.map((point) => point.latitude);
    final longitudes = _routePoints.map((point) => point.longitude);
    var south = latitudes.reduce((a, b) => a < b ? a : b);
    var north = latitudes.reduce((a, b) => a > b ? a : b);
    var west = longitudes.reduce((a, b) => a < b ? a : b);
    var east = longitudes.reduce((a, b) => a > b ? a : b);
    if (south == north) {
      south -= 0.001;
      north += 0.001;
    }
    if (west == east) {
      west -= 0.001;
      east += 0.001;
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        48,
      ),
    );
  }

  @override
  void dispose() {
    _locationStream?.cancel();
    _tripStream?.cancel();
    _staleLocationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canFocusBusLocation =
        _latestLocation != null &&
        (!_hasActiveTrip || _locationBelongsToActiveTrip);
    final initialTarget = canFocusBusLocation
        ? LatLng(_latestLocation!.latitude, _latestLocation!.longitude)
        : _polylines.isNotEmpty && _polylines.first.points.isNotEmpty
        ? _polylines.first.points.first
        : _markers.isNotEmpty
        ? _markers.first.position
        : const LatLng(9.03, 38.74);
    final locationIsStale = _locationIsStale;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Bus Tracking'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: RoleBasedDrawer(
        role: AppConstants.roleParent,
        userName: 'Parent',
        userEmail: '',
      ),
      body: _loading
          ? const LoadingWidget()
          : Column(
              children: [
                if (!_tripStatusLoaded)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.schoolBlue.withValues(alpha: 0.1),
                    child: const Text(
                      'Checking the current bus trip...',
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (_message != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.error.withValues(alpha: 0.1),
                    child: Text(_message!, textAlign: TextAlign.center),
                  )
                else if (_hasActiveTrip && !_locationBelongsToActiveTrip)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.schoolOrange.withValues(alpha: 0.12),
                    child: const Text(
                      'Trip is active. Waiting for this trip’s first GPS location.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (_hasActiveTrip && locationIsStale)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.schoolOrange.withValues(alpha: 0.12),
                    child: Text(
                      'Trip is active, but the last GPS update was '
                      '${_latestLocation!.timestamp}. Showing the last known location.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (_hasActiveTrip)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.schoolGreen.withValues(alpha: 0.1),
                    child: const Text(
                      'Trip is active. Showing the live bus location.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (_latestLocation != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.schoolOrange.withValues(alpha: 0.12),
                    child: const Text(
                      'No active trip. Showing the last reported location.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.schoolBlue.withValues(alpha: 0.1),
                    child: const Text(
                      'Bus has not started a trip or shared a location yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: initialTarget,
                      zoom: canFocusBusLocation ? 15 : 13,
                    ),
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (canFocusBusLocation) {
                        _updateCamera(
                          _latestLocation!.latitude,
                          _latestLocation!.longitude,
                        );
                      } else if (_routePoints.isNotEmpty) {
                        _focusRoute();
                      } else {
                        _updateCamera(
                          initialTarget.latitude,
                          initialTarget.longitude,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
