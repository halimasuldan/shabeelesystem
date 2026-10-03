import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../providers/bus_provider.dart';
import '../../../models/bus_model.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';

class BusDetailsScreen extends ConsumerStatefulWidget {
  const BusDetailsScreen({super.key});
  @override
  ConsumerState<BusDetailsScreen> createState() => _BusDetailsScreenState();
}

class _BusDetailsScreenState extends ConsumerState<BusDetailsScreen> {
  String? _busId;

  @override
  void initState() {
    super.initState();
    _loadBusId();
  }

  Future<void> _loadBusId() async {
    final auth = AuthService();
    final userId = auth.currentUser?.uid ?? '';
    final parentDoc = await FirebaseFirestore.instance
        .collection(AppConstants.colParents)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (parentDoc.docs.isNotEmpty) {
      final data = parentDoc.docs.first.data();
      final studentIds = List<String>.from(data['studentIds'] as List? ?? []);
      if (studentIds.isNotEmpty) {
        final studentDoc = await FirebaseFirestore.instance
            .collection(AppConstants.colStudents)
            .doc(studentIds.first)
            .get();
        if (studentDoc.exists) {
          final s = studentDoc.data()!;
          setState(() => _busId = s['busId'] as String?);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busAsync = _busId != null
        ? ref.watch(busProvider(_busId!))
        : const AsyncData(null);
    return Scaffold(
      appBar: AppBar(title: const Text('Bus Details'),
          backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      drawer: const RoleBasedDrawer(role: AppConstants.roleParent,
          userName: 'Parent', userEmail: 'parent@school.com'),
      body: busAsync.when(
        data: _buildBody,
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(BusModel? bus) {
    if (bus == null) {
      return const Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus, size: 64, color: AppColors.textDisabled),
            SizedBox(height: 16),
            Text('No bus assigned to your child.'),
          ]));
    }
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(busProvider(_busId!).future),
      child: SingleChildScrollView(
        child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(16),
              color: AppColors.primary.withValues(alpha: 0.05),
              child: Column(children: [
                Text(bus.busNumber,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Plate: ${bus.plateNumber}',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: _getStatusColor(bus.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16)),
                    child: Text(bus.status.toUpperCase(),
                        style: TextStyle(color: _getStatusColor(bus.status),
                            fontWeight: FontWeight.w600))),
              ])),
          _buildInfoSection('Driver Information', [
            _buildInfoRow('Name', bus.driverName ?? 'N/A'),
            _buildInfoRow('Phone', bus.driverPhone ?? 'N/A'),
          ]),
          _buildInfoSection('Route Information', [
            _buildInfoRow('Status', bus.status),
            _buildInfoRow('Capacity', '${bus.capacity} students'),
            _buildInfoRow('Students Assigned', '${bus.studentIds.length}'),
          ]),
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                      onPressed: () => context.go('/parent/bus/tracking'),
                      icon: const Icon(Icons.map, color: Colors.white),
                      label: const Text('Track Bus on Map')))),
        ]),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Card(margin: const EdgeInsets.all(12),
        child: Padding(padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12), ...children])));
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(flex: 2,
              child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14))),
          Expanded(flex: 3,
              child: Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14))),
        ]));
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.busAvailable: return AppColors.availableColor;
      case AppConstants.busOnRoute: return AppColors.onRouteColor;
      case AppConstants.busReturning: return AppColors.returningColor;
      case AppConstants.busMaintenance: return AppColors.schoolOrange;
      case AppConstants.busOffline: return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }
}
