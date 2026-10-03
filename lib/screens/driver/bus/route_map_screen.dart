import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/route_model.dart';
import '../../../providers/driver_provider.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/role_drawer.dart';

/// Route map screen for driver.
class RouteMapScreen extends ConsumerStatefulWidget {
  const RouteMapScreen({super.key});
  @override
  ConsumerState<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends ConsumerState<RouteMapScreen> {
  static const LatLng _defaultMapCenter = LatLng(9.03, 38.74);

  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  RouteModel? _route;
  bool _loading = true;
  String? _error;
  bool _initialLoadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialLoadStarted) return;
    _initialLoadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRoute();
    });
  }

  /// Resolves the driver's route through `driverRouteProvider`, which checks the
  /// bus document's `routeId`, `routes/{id}.busId` and `routes/{id}.driverId`.
  ///
  /// Reading `drivers/{uid}.busId` then `buses/{id}.routeId` alone left drivers
  /// on "No route data available." whenever the admin created the route on the
  /// Route screen, because that screen stores the link on the route document.
  Future<void> _loadRoute() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      ref.invalidate(driverBusIdProvider);
      ref.invalidate(driverAssignedBusProvider);
      ref.invalidate(driverRouteProvider);
      final route = await ref.read(driverRouteProvider.future);
      if (!mounted) return;
      setState(() {
        _route = route;
        _loading = false;
        _buildMapObjects(route);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load your route: $error';
        });
      }
    }
  }

  /// Turns the route stops into map markers and a polyline.
  void _buildMapObjects(RouteModel? route) {
    _polylines.clear();
    _markers.clear();
    if (route == null) return;
    // Sort by the order the admin entered the stops so the polyline follows the
    // route instead of the raw Firestore list order.
    final stops = List<RouteStop>.from(route.stops)
      ..sort((a, b) => a.order.compareTo(b.order));
    final points = <LatLng>[];
    for (final stop in stops) {
      // Stops can be saved without coordinates, which come through as 0,0 -
      // plotting them would drag the polyline off the map.
      if (stop.name.isEmpty || (stop.latitude == 0 && stop.longitude == 0)) {
        continue;
      }
      points.add(LatLng(stop.latitude, stop.longitude));
      _markers.add(
        Marker(
          markerId: MarkerId('${stop.order}-${stop.name}'),
          position: LatLng(stop.latitude, stop.longitude),
          infoWindow: InfoWindow(title: stop.name, snippet: stop.description),
        ),
      );
    }
    if (points.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: AppColors.schoolBlue,
          width: 5,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Map'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh route assignment',
            onPressed: _loadRoute,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleDriver,
        userName: 'Driver',
        userEmail: '',
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    return Column(
      children: [
        if (_route == null || _markers.isEmpty)
          const MaterialBanner(
            content: Text(
              'Map is ready. A route and stops will appear after an administrator assigns them.',
            ),
            leading: Icon(Icons.info_outline),
            actions: [SizedBox.shrink()],
          )
        else
          ListTile(
            leading: const Icon(Icons.route, color: AppColors.primary),
            title: Text(_route!.name.isEmpty ? 'My Route' : _route!.name),
            subtitle: Text(
              '${_route!.startingPoint} to ${_route!.destination}\n'
              '${_markers.length} stops',
            ),
            isThreeLine: true,
          ),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _markers.isNotEmpty
                  ? _markers.first.position
                  : _defaultMapCenter,
              zoom: _markers.isNotEmpty ? 13 : 11,
            ),
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
        ),
      ],
    );
  }
}
