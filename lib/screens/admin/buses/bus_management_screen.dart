import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/driver_assignment_utils.dart';
import '../../../models/bus_model.dart';
import '../../../models/driver_model.dart';
import '../../../providers/bus_provider.dart';
import '../../../providers/driver_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../models/student_model.dart';
import '../../../widgets/forms/form_fields.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';

/// Bus management screen for admin.

class BusManagementScreen extends ConsumerStatefulWidget {
  const BusManagementScreen({super.key});
  @override
  ConsumerState<BusManagementScreen> createState() =>
      _BusManagementScreenState();
}

class _BusManagementScreenState extends ConsumerState<BusManagementScreen> {
  final _busNumberController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _capacityController = TextEditingController();
  String? _selectedDriverId;
  String? _selectedRouteId;
  bool _isLoading = false;
  @override
  void dispose() {
    _busNumberController.dispose();
    _plateNumberController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _createBus() async {
    setState(() => _isLoading = true);
    try {
      DriverModel? driver;
      if (_selectedDriverId != null) {
        final driverDoc = await FirebaseFirestore.instance
            .collection(AppConstants.colDrivers)
            .doc(_selectedDriverId)
            .get();
        if (driverDoc.exists) driver = DriverModel.fromFirestore(driverDoc);
      }
      final bus = BusModel(
        id: const Uuid().v4(),
        busNumber: _busNumberController.text.trim(),
        plateNumber: _plateNumberController.text.trim(),
        driverId: _selectedDriverId,
        driverName: driver?.name,
        driverPhone: driver?.phone,
        routeId: _selectedRouteId,
        status: AppConstants.busAvailable,
        capacity:
            int.tryParse(_capacityController.text) ??
            AppConstants.defaultBusCapacity,
        studentIds: [],
        createdAt: DateTime.now(),
      );
      await ref.read(busCrudProvider.notifier).createBus(bus);
      // Keep the driver and route mirrors in step with the new bus, otherwise a
      // bus created here is invisible to the driver portal.
      await _syncBusLinks(
        busId: bus.id,
        driverId: _selectedDriverId,
        driver: driver,
        routeId: _selectedRouteId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bus created!'),
          backgroundColor: AppColors.presentColor,
        ),
      );
      context.go('/admin/buses');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busesAsync = ref.watch(busesProvider);
    final driversAsync = ref.watch(driversProvider);
    // Rider counts come from `students/busId` - the exact link the driver
    // portal queries - so the admin's "N students" matches the driver's
    // Students card without trusting the buses/studentIds mirror.
    final students =
        ref.watch(studentsProvider).valueOrNull ?? const <StudentModel>[];
    final riderCounts = <String, int>{};
    for (final student in students) {
      final busId = student.busId;
      if (busId != null && busId.isNotEmpty) {
        riderCounts[busId] = (riderCounts[busId] ?? 0) + 1;
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleAdmin,
        userName: 'Admin',
        userEmail: 'admin@school.com',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ExpansionTile(
              title: const Text('Add New Bus'),
              leading: const Icon(Icons.add, color: AppColors.primary),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Bus Number',
                        hint: 'E.g., BUS-001',
                        controller: _busNumberController,
                        validator: (v) =>
                            Validators.validateRequired(v, 'Bus Number'),
                        prefixIcon: Icons.directions_bus,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Plate Number',
                        hint: 'E.g., ABC-1234',
                        controller: _plateNumberController,
                        validator: (v) =>
                            Validators.validateRequired(v, 'Plate Number'),
                        prefixIcon: Icons.pin,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Capacity',
                        hint: 'Number of students',
                        controller: _capacityController,
                        validator: (v) =>
                            Validators.validateNumber(v, 'Capacity'),
                        prefixIcon: Icons.person,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      driversAsync.when(
                        data: (drivers) => AppDropdownField<String>(
                          label: 'Assign Driver',
                          hint: 'Select driver (optional)',
                          value: _selectedDriverId,
                          items: drivers
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedDriverId = value),
                        ),
                        loading: () => const LoadingWidget(),
                        error: (error, _) => Text('Error: $error'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createBus,
                          child: _isLoading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Create Bus'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: busesAsync.when(
              data: (buses) {
                if (buses.isEmpty) {
                  return const Center(child: Text('No buses found.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(busesProvider.future),
                  child: ListView.builder(
                    itemCount: buses.length,
                    itemBuilder: (context, index) {
                      final bus = buses[index];
                      final driverLabel =
                          (bus.driverName == null || bus.driverName!.isEmpty)
                          ? 'No driver'
                          : bus.driverName!;
                      final riderCount = riderCounts[bus.id] ?? 0;
                      return Card(
                        child: ListTile(
                          // Tap a bus to see exactly which students ride it -
                          // the same students.busId link the driver portal uses.
                          onTap: () => _showAssignedStudents(bus, students),
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.driverColor,
                            child: Icon(
                              Icons.directions_bus,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            bus.busNumber,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${bus.plateNumber} · $driverLabel · '
                            '$riderCount students',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.assignment_ind,
                                  color: AppColors.primary,
                                ),
                                tooltip: 'Assign driver & route',
                                onPressed: () => _assignBusResources(bus),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: AppColors.schoolBlue,
                                ),
                                onPressed: () => _editBus(bus),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: AppColors.schoolRed,
                                ),
                                onPressed: () => ref
                                    .read(busCrudProvider.notifier)
                                    .deleteBus(bus.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const LoadingWidget(),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows the students that currently ride [bus], read from their own
  /// `students/busId` field (the same field `driverStudentsProvider` queries),
  /// so the admin sees exactly what the driver portal will show.
  void _showAssignedStudents(BusModel bus, List<StudentModel> allStudents) {
    final riders = allStudents.where((s) => s.busId == bus.id).toList()
      ..sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bus ${bus.busNumber} · Assigned Students'),
        content: SizedBox(
          width: double.maxFinite,
          child: riders.isEmpty
              ? const Text('No students assigned to this bus yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: riders.length,
                  itemBuilder: (context, index) {
                    final student = riders[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.school,
                        color: AppColors.schoolBlue,
                      ),
                      title: Text(student.fullName),
                      subtitle: Text(student.studentCode),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editBus(BusModel bus) async {
    final formKey = GlobalKey<FormState>();
    final numCtrl = TextEditingController(text: bus.busNumber);
    final plateCtrl = TextEditingController(text: bus.plateNumber);
    final capCtrl = TextEditingController(text: bus.capacity.toString());
    try {
      final updated = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Edit Bus'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'Bus Number',
                  hint: 'Enter bus number',
                  controller: numCtrl,
                  validator: (v) =>
                      Validators.validateRequired(v, 'Bus Number'),
                  prefixIcon: Icons.directions_bus,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Plate Number',
                  hint: 'Enter plate number',
                  controller: plateCtrl,
                  validator: (v) =>
                      Validators.validateRequired(v, 'Plate Number'),
                  prefixIcon: Icons.credit_card_outlined,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Capacity',
                  hint: 'Enter passenger capacity',
                  controller: capCtrl,
                  validator: (v) => Validators.validateNumber(v, 'Capacity'),
                  prefixIcon: Icons.event_seat,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (updated != true || !mounted) return;
      await ref
          .read(busCrudProvider.notifier)
          .updateBus(
            bus.copyWith(
              busNumber: numCtrl.text.trim(),
              plateNumber: plateCtrl.text.trim(),
              capacity: int.tryParse(capCtrl.text.trim()) ?? bus.capacity,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bus updated!'),
            backgroundColor: AppColors.presentColor,
          ),
        );
      }
    } finally {
      numCtrl.dispose();
      plateCtrl.dispose();
      capCtrl.dispose();
    }
  }

  /// Assign or change the driver and route of an existing bus.
  ///
  /// Before this existed the only way to link a driver or a route to a bus was
  /// to pick one while the bus was being created, and even then only the bus
  /// document was written - the mirrored `drivers/{id}.busId` and
  /// `routes/{id}.busId` fields the driver portal reads stayed empty, so the
  /// driver kept seeing "No students assigned" / "No route data available".
  Future<void> _assignBusResources(BusModel bus) async {
    try {
      final drivers = await ref.read(driversListProvider.future);
      final routes = await ref.read(routesProvider.future);
      if (!mounted) return;

      String? driverId = bus.driverId;
      String? routeId = bus.routeId;

      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Assign ${bus.busNumber}'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppDropdownField<String>(
                    label: 'Driver',
                    hint: 'Select driver',
                    prefixIcon: Icons.person,
                    value: driverId,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No driver'),
                      ),
                      ...drivers.map(
                        (d) => DropdownMenuItem<String>(
                          value: d.id,
                          child: Text(d.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => driverId = value),
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField<String>(
                    label: 'Route',
                    hint: 'Select route',
                    prefixIcon: Icons.route,
                    value: routeId,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No route'),
                      ),
                      ...routes.map(
                        (r) => DropdownMenuItem<String>(
                          value: r.id,
                          child: Text(r.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() => routeId = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (saved != true || !mounted) return;
      await _applyBusAssignment(bus, drivers, driverId, routeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver and route assigned.'),
          backgroundColor: AppColors.presentColor,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Persist a bus driver/route change across every document that records it.
  ///
  /// The app stores this link in several places: the bus is the source of truth
  /// (`buses/{id}.driverId` / `.routeId`), while `drivers/{id}.busId` and
  /// `routes/{id}.busId` are the mirrors the driver portal and the maps follow.
  /// Writing only the bus left those mirrors stale, which is what hid assigned
  /// students and routes from drivers.
  ///
  /// Thin adapter over [_syncBusLinks] so the assign dialog can hand over the
  /// ids it already resolved from the driver list.
  Future<void> _applyBusAssignment(
    BusModel bus,
    List<DriverModel> drivers,
    String? driverId,
    String? routeId,
  ) async {
    DriverModel? driver;
    for (final d in drivers) {
      if (d.id == driverId) driver = d;
    }
    await _syncBusLinks(
      busId: bus.id,
      driverId: driverId,
      driver: driver,
      routeId: routeId,
      previousDriverId: bus.driverId,
      previousRouteId: bus.routeId,
    );
  }

  /// Write a driver/route assignment to every document that records it.
  Future<void> _syncBusLinks({
    required String busId,
    String? driverId,
    DriverModel? driver,
    String? routeId,
    String? previousDriverId,
    String? previousRouteId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    String? driverUserId;
    if (driver != null) {
      final savedUserId = driver.userId.trim();
      if (savedUserId.isNotEmpty) {
        driverUserId = savedUserId;
      } else if (driver.email.trim().isNotEmpty) {
        final userSnapshot = await firestore
            .collection(AppConstants.colUsers)
            .where('email', isEqualTo: driver.email.trim())
            .limit(1)
            .get();
        driverUserId = userSnapshot.docs.isNotEmpty
            ? userSnapshot.docs.first.id
            : driver.assignmentUserId;
      } else {
        driverUserId = driver.assignmentUserId;
      }
    }

    final driverIds = <String>{
      if (driverId != null && driverId.isNotEmpty) driverId,
      if (driverUserId != null && driverUserId.isNotEmpty) driverUserId,
    };
    final batch = firestore.batch();
    final busCollection = firestore.collection(AppConstants.colBuses);
    final allBuses = await busCollection.get();
    final releasedBusDocs = allBuses.docs.where((doc) {
      if (doc.id == busId || driverIds.isEmpty) return false;
      return busIsAssignedToDriver(
        doc.data(),
        driverIds: driverIds,
        userId: driverUserId,
      );
    }).toList();

    // A driver may own only one bus. Clear older bus-side links before saving
    // the new assignment so the driver's `limit(1)` lookup cannot pick the old
    // bus unpredictably.
    for (final oldBus in releasedBusDocs) {
      final oldData = oldBus.data();
      batch.update(oldBus.reference, {
        'driverId': null,
        'driverUserId': null,
        'driverName': null,
        'driverPhone': null,
        if (driverUserId != null && oldData['currentDriverId'] == driverUserId)
          'currentDriverId': null,
      });

      final oldRouteId = oldData['routeId'] as String?;
      if (oldRouteId != null && oldRouteId.isNotEmpty) {
        final oldRouteRef = firestore
            .collection(AppConstants.colRoutes)
            .doc(oldRouteId);
        final oldRoute = await oldRouteRef.get();
        if (oldRoute.exists &&
            driverIds.contains(oldRoute.data()?['driverId'])) {
          batch.update(oldRouteRef, {'driverId': null});
        }
      }
    }

    // The target bus is the assignment of record. `driverUserId` carries the
    // auth uid alongside the driver document id, including legacy profiles.
    batch.update(busCollection.doc(busId), {
      'driverId': driverId,
      'driverUserId': driverUserId,
      'driverName': driver?.name,
      'driverPhone': driver?.phone,
      'routeId': routeId,
    });

    // Keep the driver-profile reverse link in sync with the authoritative bus.
    if (driverId != null && driverId.isNotEmpty) {
      batch.set(
        firestore.collection(AppConstants.colDrivers).doc(driverId),
        {
          'busId': busId,
          if (driverUserId != null && driverUserId.isNotEmpty)
            'userId': driverUserId,
        },
        SetOptions(merge: true),
      );
    }
    if (previousDriverId != null &&
        previousDriverId.isNotEmpty &&
        previousDriverId != driverId &&
        !driverIds.contains(previousDriverId)) {
      batch.set(
        firestore.collection(AppConstants.colDrivers).doc(previousDriverId),
        {'busId': null},
        SetOptions(merge: true),
      );
    }

    // 4. Mirror onto the route documents, which the driver route map and the
    //    parent tracking map also follow.
    if (previousRouteId != null &&
        previousRouteId.isNotEmpty &&
        previousRouteId != routeId) {
      batch.set(
        firestore.collection(AppConstants.colRoutes).doc(previousRouteId),
        {'busId': null, 'driverId': null},
        SetOptions(merge: true),
      );
    }
    if (routeId != null && routeId.isNotEmpty) {
      batch.set(
        firestore.collection(AppConstants.colRoutes).doc(routeId),
        {
          'busId': busId,
          if (driverId != null && driverId.isNotEmpty) 'driverId': driverId,
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}
