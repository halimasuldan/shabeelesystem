import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/driver_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../widgets/common/role_drawer.dart';

/// Live GPS tracking screen for driver.
class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});
  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  String? _busId;
  bool _loading = true;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadBus();
  }

  /// Resolves the bus assigned to this driver.
  ///
  /// Uses `driverBusIdProvider`, which also reads `buses/{id}.driverId`. The
  /// driver document's mirrored `busId` is usually absent, which left this
  /// screen stuck on "Loading bus info..." even when a bus was assigned.
  Future<void> _loadBus() async {
    final busId = await ref.read(driverBusIdProvider.future);
    if (!mounted) return;
    setState(() {
      _busId = busId;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(locationControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live GPS Tracking'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                tracking ? 'TRACKING' : 'NOT TRACKING',
                style: TextStyle(
                  color: tracking ? AppColors.schoolGreen : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleDriver,
        userName: 'Driver',
        userEmail: '',
      ),
      body: _loading
          ? const Center(child: Text('Loading bus info...'))
          : _busId == null || _busId!.isEmpty
          ? const Center(child: Text('No bus assigned to you yet.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.colBusLocations)
                  .doc(_busId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load bus location: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(
                    child: Text('No location shared yet. Start a trip first.'),
                  );
                }
                final loc = snapshot.data!.data()!;
                final lat = (loc['latitude'] as num?)?.toDouble() ?? 0;
                final lng = (loc['longitude'] as num?)?.toDouble() ?? 0;
                if (lat == 0 && lng == 0) {
                  return const Center(
                    child: Text('Waiting for the first GPS location.'),
                  );
                }
                _markers.clear();
                _markers.add(
                  Marker(
                    markerId: const MarkerId('bus'),
                    position: LatLng(lat, lng),
                    infoWindow: const InfoWindow(title: 'My Bus'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue,
                    ),
                  ),
                );
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: LatLng(lat, lng), zoom: 16),
                  ),
                );
                return GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(lat, lng),
                    zoom: 16,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  onMapCreated: (c) => setState(() => _mapController = c),
                );
              },
            ),
    );
  }
}
