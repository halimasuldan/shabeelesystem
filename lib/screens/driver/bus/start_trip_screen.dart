import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../providers/driver_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../providers/location_provider.dart';
import '../../../widgets/common/role_drawer.dart';

/// Screen where driver starts and ends a bus trip.
class StartTripScreen extends ConsumerStatefulWidget {
  const StartTripScreen({super.key});
  @override
  ConsumerState<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends ConsumerState<StartTripScreen> {
  bool _isTracking = false;
  bool _isLoadingBus = true;
  bool _isWorking = false;
  String? _busId;

  /// Human readable bus number for the assigned bus, when one is assigned.
  String? _busNumber;
  String? _tripId;

  @override
  void initState() {
    super.initState();
    _loadBus();
  }

  Future<void> _loadBus() async {
    // Resolves `buses/{id}.driverId` as well as `drivers/{uid}.busId`, so a bus
    // the admin attached to this driver is always found.
    try {
      final busId = await ref.read(driverBusIdProvider.future);
      final bus = await ref.read(driverAssignedBusProvider.future);
      QuerySnapshot<Map<String, dynamic>>? activeTrips;
      if (busId != null && busId.isNotEmpty) {
        activeTrips = await FirebaseFirestore.instance
            .collection(AppConstants.colBusTrips)
            .where('busId', isEqualTo: busId)
            .get();
      }
      if (!mounted) return;
      final activeTrip =
          activeTrips?.docs
              .where((doc) => doc.data()['status'] == AppConstants.tripActive)
              .toList()
            ?..sort((a, b) {
              final aStart = a.data()['startTime'] as Timestamp?;
              final bStart = b.data()['startTime'] as Timestamp?;
              return (bStart?.millisecondsSinceEpoch ?? 0).compareTo(
                aStart?.millisecondsSinceEpoch ?? 0,
              );
            });
      final currentTrip = activeTrip?.firstOrNull;
      setState(() {
        _busId = busId;
        _busNumber = bus?.busNumber;
        _isTracking = currentTrip != null;
        _tripId = currentTrip?.id;
        _isLoadingBus = false;
      });
      if (currentTrip != null && busId != null) {
        await ref
            .read(locationControllerProvider.notifier)
            .startTracking(
              busId,
              currentTrip.id,
              driverId: AuthService().currentUser?.uid,
            );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingBus = false);
      _msg('Unable to load your active trip: $error');
    }
  }

  Future<void> _startTrip() async {
    if (_isWorking) return;
    // A trip without a bus id cannot be tracked or queried later, so stop early
    // with an actionable message instead of writing a half-empty trip document.
    if (_busId == null || _busId!.isEmpty) {
      _msg(
        'No bus is assigned to you yet. Ask an administrator to assign one.',
      );
      return;
    }
    final driverId = AuthService().currentUser?.uid;
    if (driverId == null || driverId.isEmpty) {
      _msg('Sign in again before starting a trip.');
      return;
    }
    setState(() => _isWorking = true);
    try {
      final busTrips = await FirebaseFirestore.instance
          .collection(AppConstants.colBusTrips)
          .where('busId', isEqualTo: _busId)
          .get();
      final activeTrips =
          busTrips.docs
              .where((doc) => doc.data()['status'] == AppConstants.tripActive)
              .toList()
            ..sort((a, b) {
              final aStart = a.data()['startTime'] as Timestamp?;
              final bStart = b.data()['startTime'] as Timestamp?;
              return (bStart?.millisecondsSinceEpoch ?? 0).compareTo(
                aStart?.millisecondsSinceEpoch ?? 0,
              );
            });
      if (activeTrips.isNotEmpty) {
        final trip = activeTrips.first;
        await _setBusStatus(AppConstants.busOnRoute);
        if (!mounted) return;
        setState(() {
          _tripId = trip.id;
          _isTracking = true;
        });
        await ref
            .read(locationControllerProvider.notifier)
            .startTracking(_busId!, trip.id, driverId: driverId);
        _msg('Your bus already has an active trip.');
        return;
      }
      final hasPermission = await LocationService.instance.requestPermission();
      final isEnabled = await LocationService.instance.isLocationEnabled();
      if (!hasPermission) {
        _msg('Location permission denied.');
        return;
      }
      if (!isEnabled) {
        _msg('Please enable GPS.');
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.colBusTrips)
          .add({
            'busId': _busId,
            'driverId': driverId,
            'startTime': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'status': AppConstants.tripActive,
          });
      await _setBusStatus(AppConstants.busOnRoute);
      if (!mounted) return;
      setState(() {
        _isTracking = true;
        _tripId = doc.id;
      });
      await ref
          .read(locationControllerProvider.notifier)
          .startTracking(_busId!, _tripId!, driverId: driverId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip started!')));
      // Notify every parent of a student on this bus that the trip has started.
      if (_busId != null) {
        try {
          await NotificationService.instance.notifyBusParents(
            busId: _busId!,
            title: 'Bus Trip Started',
            message: 'Your child\'s bus has started its trip.',
            type: 'bus',
            senderId: driverId,
          );
        } catch (error) {
          debugPrint('Trip started but parent notification failed: $error');
        }
      }
    } catch (error) {
      if (mounted) _msg('Could not start trip: $error');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _endTrip() async {
    if (_isWorking || _tripId == null) return;
    setState(() => _isWorking = true);
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.colBusTrips)
          .doc(_tripId)
          .update({
            'endTime': FieldValue.serverTimestamp(),
            'status': AppConstants.tripCompleted,
          });
      await ref
          .read(locationControllerProvider.notifier)
          .stopTracking(busId: _busId);
      if (_busId != null) {
        try {
          await NotificationService.instance.notifyBusParents(
            busId: _busId!,
            title: 'Bus Trip Ended',
            message: 'Your child\'s bus has arrived and the trip has ended.',
            type: 'bus',
            senderId: AuthService().currentUser?.uid,
          );
        } catch (error) {
          debugPrint('Trip ended but parent notification failed: $error');
        }
      }
      if (!mounted) return;
      setState(() => _isTracking = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip ended.')));
      context.go('/driver/dashboard');
    } catch (error) {
      if (mounted) _msg('Could not end trip: $error');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _setBusStatus(String status) async {
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.colBuses)
          .doc(_busId)
          .update({'status': status});
    } catch (error) {
      debugPrint('Trip is active but bus status was not updated: $error');
    }
  }

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBus) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Start Trip'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Trip'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleDriver,
        userName: 'Driver',
        userEmail: '',
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isTracking ? Icons.location_on : Icons.location_disabled,
                  size: 64,
                  color: _isTracking ? AppColors.schoolGreen : AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _isTracking ? 'Trip Active' : 'Ready to Start',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isTracking
                        ? AppColors.schoolGreen
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bus: ${_busNumber ?? _busId ?? "N/A"}',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedIcon(
                    onPressed: _isWorking
                        ? null
                        : _isTracking
                        ? _endTrip
                        : _startTrip,
                    icon: _isWorking
                        ? Icons.hourglass_top
                        : _isTracking
                        ? Icons.stop
                        : Icons.play_arrow,
                    label: _isWorking
                        ? 'PLEASE WAIT'
                        : _isTracking
                        ? 'END TRIP'
                        : 'START TRIP',
                    color: _isTracking
                        ? AppColors.error
                        : AppColors.schoolGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience button with icon + label.
class ElevatedIcon extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color color;
  const ElevatedIcon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: color),
    );
  }
}
