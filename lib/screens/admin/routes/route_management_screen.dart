import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../models/route_model.dart';
import '../../../providers/bus_provider.dart';
import '../../../widgets/forms/form_fields.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';

/// Route management screen for admin.
class RouteManagementScreen extends ConsumerStatefulWidget {
  const RouteManagementScreen({super.key});

  @override
  ConsumerState<RouteManagementScreen> createState() =>
      _RouteManagementScreenState();
}

class _RouteManagementScreenState extends ConsumerState<RouteManagementScreen> {
  final _nameController = TextEditingController();
  final _startingPointController = TextEditingController();
  final _destinationController = TextEditingController();
  final _stopNameController = TextEditingController();
  final _stopLatitudeController = TextEditingController();
  final _stopLongitudeController = TextEditingController();

  String? _selectedBusId;
  String? _selectedDriverId;
  final List<RouteStop> _stops = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _startingPointController.dispose();
    _destinationController.dispose();
    _stopNameController.dispose();
    _stopLatitudeController.dispose();
    _stopLongitudeController.dispose();
    super.dispose();
  }

  void _addStop() {
    if (_stopNameController.text.trim().isEmpty) return;
    final latitude = double.tryParse(_stopLatitudeController.text.trim());
    final longitude = double.tryParse(_stopLongitudeController.text.trim());
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid latitude and longitude for the stop.'),
        ),
      );
      return;
    }
    setState(() {
      _stops.add(
        RouteStop(
          order: _stops.length + 1,
          name: _stopNameController.text.trim(),
          latitude: latitude,
          longitude: longitude,
        ),
      );
      _stopNameController.clear();
      _stopLatitudeController.clear();
      _stopLongitudeController.clear();
    });
  }

  void _removeStop(int index) {
    setState(() {
      _stops.removeAt(index);
      for (int i = 0; i < _stops.length; i++) {
        _stops[i] = RouteStop(
          order: i + 1,
          name: _stops[i].name,
          latitude: _stops[i].latitude,
          longitude: _stops[i].longitude,
        );
      }
    });
  }

  Future<void> _createRoute() async {
    if (_nameController.text.trim().isEmpty ||
        _startingPointController.text.trim().isEmpty ||
        _destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final route = RouteModel(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        startingPoint: _startingPointController.text.trim(),
        destination: _destinationController.text.trim(),
        stops: _stops,
        busId: _selectedBusId,
        driverId: _selectedDriverId,
        studentIds: [],
        createdAt: DateTime.now(),
      );
      await ref.read(busCrudProvider.notifier).createRoute(route);
      if (_selectedBusId != null && _selectedBusId!.isNotEmpty) {
        await ref
            .read(busCrudProvider.notifier)
            .linkRouteToBus(route.id, _selectedBusId!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route created!'),
          backgroundColor: AppColors.presentColor,
        ),
      );
      context.go('/admin/routes');
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
    final routesAsync = ref.watch(routesProvider);
    final busesAsync = ref.watch(busesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Management'),
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
              title: const Text('Add New Route'),
              leading: const Icon(Icons.add, color: AppColors.primary),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Route Name',
                        hint: 'E.g., Route A',
                        controller: _nameController,
                        validator: (v) =>
                            Validators.validateRequired(v, 'Route Name'),
                        prefixIcon: Icons.label,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Starting Point',
                        hint: 'Enter starting point',
                        controller: _startingPointController,
                        validator: (v) =>
                            Validators.validateRequired(v, 'Starting Point'),
                        prefixIcon: Icons.trip_origin,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Destination',
                        hint: 'Enter destination',
                        controller: _destinationController,
                        validator: (v) =>
                            Validators.validateRequired(v, 'Destination'),
                        prefixIcon: Icons.flag,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: 'Stop Name',
                              hint: 'Home stop',
                              controller: _stopNameController,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppTextField(
                              label: 'Latitude',
                              hint: '9.03',
                              controller: _stopLatitudeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppTextField(
                              label: 'Longitude',
                              hint: '38.74',
                              controller: _stopLongitudeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.add,
                              color: AppColors.primary,
                            ),
                            onPressed: _addStop,
                          ),
                        ],
                      ),
                      if (_stops.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            spacing: 8,
                            children: List.generate(_stops.length, (i) {
                              final stop = _stops[i];
                              return Chip(
                                label: Text(stop.name),
                                onDeleted: () => _removeStop(i),
                                deleteIcon: const Icon(Icons.close, size: 18),
                              );
                            }),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      busesAsync.when(
                        data: (buses) => AppDropdownField<String>(
                          label: 'Assign Bus',
                          hint: 'Select bus (optional)',
                          value: _selectedBusId,
                          items: buses
                              .map(
                                (b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text(
                                    '${b.busNumber} (${b.plateNumber})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedBusId = value),
                        ),
                        loading: () => const LoadingWidget(),
                        error: (error, _) => Text('Error: $error'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createRoute,
                          child: _isLoading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Create Route'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: routesAsync.when(
              data: (routes) {
                if (routes.isEmpty) {
                  return const Center(child: Text('No routes found.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(routesProvider.future),
                  child: ListView.builder(
                    itemCount: routes.length,
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.route,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            route.name,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${route.startingPoint} ? ${route.destination}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${route.stops.length} stops',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: AppColors.schoolBlue,
                                ),
                                onPressed: () => _editRoute(route),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: AppColors.schoolRed,
                                ),
                                onPressed: () => _deleteRoute(route),
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

  Future<void> _editRoute(RouteModel route) async {
    final nameCtrl = TextEditingController(text: route.name);
    final startCtrl = TextEditingController(text: route.startingPoint);
    final destCtrl = TextEditingController(text: route.destination);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Route Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: startCtrl,
              decoration: const InputDecoration(labelText: 'Starting Point'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: destCtrl,
              decoration: const InputDecoration(labelText: 'Destination'),
            ),
          ],
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
    );
    if (ok != true || !mounted) return;
    await ref
        .read(busCrudProvider.notifier)
        .updateRoute(
          RouteModel(
            id: route.id,
            name: nameCtrl.text.trim(),
            startingPoint: startCtrl.text.trim(),
            destination: destCtrl.text.trim(),
            stops: route.stops,
            busId: route.busId,
            driverId: route.driverId,
            studentIds: route.studentIds,
            createdAt: route.createdAt,
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route updated!'),
          backgroundColor: AppColors.presentColor,
        ),
      );
    }
  }

  Future<void> _deleteRoute(RouteModel route) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.colRoutes)
        .doc(route.id)
        .delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route deleted.'),
          backgroundColor: AppColors.schoolRed,
        ),
      );
    }
  }
}
