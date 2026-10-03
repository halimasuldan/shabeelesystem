import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/bus_model.dart';
import '../../../providers/bus_provider.dart';
import '../../../providers/driver_provider.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';

/// Driver's assigned bus details screen.
class DriverBusDetailsScreen extends ConsumerStatefulWidget {
  const DriverBusDetailsScreen({super.key});
  @override
  ConsumerState<DriverBusDetailsScreen> createState() =>
      _DriverBusDetailsScreenState();
}

class _DriverBusDetailsScreenState
    extends ConsumerState<DriverBusDetailsScreen> {
  String? _busId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBus();
  }

  Future<void> _loadBus() async {
    // Resolves `buses/{id}.driverId` as well as `drivers/{uid}.busId`, so a bus
    // the admin attached to this driver is always found - previously only the
    // driver document's mirror field was read, which is usually absent.
    final busId = await ref.read(driverBusIdProvider.future);
    if (!mounted) return;
    setState(() {
      _busId = busId;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bus'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const RoleBasedDrawer(
          role: AppConstants.roleDriver,
          userName: 'Driver', userEmail: ''),
        body: _loading
          ? const LoadingWidget()
          : _busId == null || _busId!.isEmpty
            ? const Center(child: Text('No bus assigned to this driver.'))
          : ref.watch(busProvider(_busId!)).when(
              data: _buildBody,
              loading: () => const LoadingWidget(),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
    );
  }

  Widget _buildBody(BusModel? bus) {
    if (bus == null) {
      return const Center(child: Text('No bus assigned.'));
    }
    return ListView(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AppColors.primary.withValues(alpha: 0.05),
        child: Column(children: [
          Text(bus.busNumber,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Plate: ${bus.plateNumber}',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor(bus.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(bus.status.toUpperCase(),
                style: TextStyle(
                    color: _statusColor(bus.status),
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      _infoRow('Driver', bus.driverName ?? 'N/A'),
      _infoRow('Phone', bus.driverPhone ?? 'N/A'),
      _infoRow('Capacity', '${bus.capacity}'),
      _infoRow('Students Assigned', '${bus.studentIds.length}'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.route),
          label: const Text('View Route'),
        ),
      ),
    ]);
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Expanded(flex: 2, child: Text(label,
            style: TextStyle(color: AppColors.textSecondary))),
        Expanded(flex: 3, child: Text(value,
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case AppConstants.busAvailable: return AppColors.availableColor;
      case AppConstants.busOnRoute: return AppColors.onRouteColor;
      case AppConstants.busReturning: return AppColors.returningColor;
      default: return AppColors.textSecondary;
    }
  }
}
