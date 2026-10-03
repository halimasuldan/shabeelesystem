import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/bus_model.dart';
import '../../../models/driver_model.dart';
import '../../../models/student_model.dart';
import '../../../providers/bus_provider.dart';
import '../../../providers/driver_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/stat_tile.dart';
import '../../../widgets/common/school_brand.dart';
import '../../../widgets/common/role_drawer.dart';

/// Driver management screen for admin.
class DriverManagementScreen extends ConsumerStatefulWidget {
  const DriverManagementScreen({super.key});

  @override
  ConsumerState<DriverManagementScreen> createState() =>
      _DriverManagementScreenState();
}

class _DriverManagementScreenState
    extends ConsumerState<DriverManagementScreen> {
  @override
  void initState() {
    super.initState();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'verified':
        return AppColors.presentColor;
      case 'rejected':
        return AppColors.absentColor;
      default:
        return AppColors.warning;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'verified':
        return Icons.verified_user;
      case 'rejected':
        return Icons.gpp_bad;
      default:
        return Icons.hourglass_empty;
    }
  }

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(driversListProvider);
    final buses = ref.watch(busesProvider).valueOrNull ?? const <BusModel>[];
    final students =
        ref.watch(studentsProvider).valueOrNull ?? const <StudentModel>[];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SchoolBrand(compact: true, light: true, showName: false),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Driver Management',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleAdmin,
        userName: 'Admin',
        userEmail: 'admin@school.com',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/admin/drivers/register'),
        backgroundColor: AppColors.driverColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text(AppStrings.registerDriver),
      ),
      body: driversAsync.when(
        data: (drivers) => _buildBody(drivers, buses, students),
        loading: () => const LoadingWidget(),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Unable to load drivers',
          subtitle: error.toString(),
        ),
      ),
    );
  }

  Widget _buildBody(
    List<DriverModel> drivers,
    List<BusModel> buses,
    List<StudentModel> students,
  ) {
    final verified = drivers.where((d) => d.status == 'verified').length;
    final pending = drivers.where((d) => d.status == 'pending').length;
    final rejected = drivers.where((d) => d.status == 'rejected').length;

    final filtered = _searchQuery.isEmpty
        ? drivers
        : drivers
              .where(
                (d) =>
                    d.name.toLowerCase().contains(_searchQuery) ||
                    d.email.toLowerCase().contains(_searchQuery) ||
                    d.phone.toLowerCase().contains(_searchQuery),
              )
              .toList();

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(driversListProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(drivers.length),
          const SizedBox(height: 16),
          _buildSummaryRow(drivers.length, verified, pending, rejected),
          const SizedBox(height: 16),
          _buildSearchField(),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: EmptyState(
                icon: Icons.directions_car_outlined,
                title: _searchQuery.isEmpty
                    ? 'No drivers yet'
                    : 'No matching drivers',
                subtitle: _searchQuery.isEmpty
                    ? 'Register your first driver to get started'
                    : 'Try a different search term',
                action: _searchQuery.isEmpty
                    ? ElevatedButton.icon(
                        onPressed: () => context.go('/admin/drivers/register'),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text(AppStrings.registerDriver),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.driverColor,
                          foregroundColor: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
          if (filtered.isNotEmpty)
            ...filtered.map(
              (driver) => _buildDriverCard(driver, buses, students),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(int total) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SchoolBrand(compact: false, light: true, showName: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Drivers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total registered driver${total == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/admin/drivers/pending'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              AppStrings.pendingVerification,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(int total, int verified, int pending, int rejected) {
    return Row(
      children: [
        Expanded(
          child: _summaryTile(
            'Total',
            '$total',
            AppColors.schoolBlue,
            Icons.groups,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryTile(
            'Verified',
            '$verified',
            AppColors.presentColor,
            Icons.verified_user,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryTile(
            'Pending',
            '$pending',
            AppColors.warning,
            Icons.hourglass_empty,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryTile(
            'Rejected',
            '$rejected',
            AppColors.absentColor,
            Icons.gpp_bad,
          ),
        ),
      ],
    );
  }

  Widget _summaryTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.divider.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
      decoration: InputDecoration(
        hintText: AppStrings.searchDrivers,
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
    );
  }

  Widget _buildDriverCard(
    DriverModel driver,
    List<BusModel> buses,
    List<StudentModel> students,
  ) {
    final color = _statusColor(driver.status);
    final icon = _statusIcon(driver.status);
    final assignedBuses = buses.where((bus) {
      return bus.driverId == driver.id || bus.driverId == driver.userId;
    }).toList();
    final assignedStudentNames = students
        .where((student) => assignedBuses.any((bus) => student.busId == bus.id))
        .map((student) => student.fullName)
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.divider.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.driverColor.withValues(alpha: 0.15),
              child: Text(
                driver.name.isNotEmpty ? driver.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.driverColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          driver.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(
                        label: driver.status == 'verified'
                            ? AppStrings.verified
                            : driver.status == 'rejected'
                            ? AppStrings.rejected
                            : 'Pending',
                        color: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    driver.phone,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    driver.licenseNumber == null ||
                            driver.licenseNumber!.isEmpty
                        ? 'No license on file'
                        : 'License: ${driver.licenseNumber}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    assignedBuses.isEmpty
                        ? 'Assigned bus: None'
                        : 'Assigned bus: ${assignedBuses.map((bus) => bus.busNumber).join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.schoolBlue,
                    ),
                  ),
                  Text(
                    assignedStudentNames.isEmpty
                        ? 'Students: None assigned'
                        : 'Students (${assignedStudentNames.length}): ${assignedStudentNames.join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildDriverMenu(driver, color, icon),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverMenu(DriverModel driver, Color color, IconData icon) {
    return PopupMenuButton<String>(
      icon: Icon(icon, color: color),
      onSelected: (value) => _handleAction(value, driver),
      itemBuilder: (context) => [
        if (driver.status != 'verified')
          const PopupMenuItem(
            value: 'verify',
            child: Row(
              children: [
                Icon(
                  Icons.verified_user,
                  color: AppColors.presentColor,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(AppStrings.approve),
              ],
            ),
          ),
        if (driver.status != 'rejected')
          const PopupMenuItem(
            value: 'reject',
            child: Row(
              children: [
                Icon(Icons.gpp_bad, color: AppColors.absentColor, size: 18),
                SizedBox(width: 8),
                Text(AppStrings.reject),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.person_remove, color: AppColors.error, size: 18),
              SizedBox(width: 8),
              Text('Deactivate'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(String action, DriverModel driver) async {
    final crud = ref.read(driverCrudProvider.notifier);
    try {
      switch (action) {
        case 'verify':
          await crud.updateDriverStatus(driver.id, 'verified');
          _showSnack(AppStrings.driverApproved, AppColors.presentColor);
          break;
        case 'reject':
          await crud.updateDriverStatus(driver.id, 'rejected');
          _showSnack(AppStrings.driverRejected, AppColors.absentColor);
          break;
        case 'delete':
          await crud.deleteDriver(driver.id);
          _showSnack('Driver deactivated.', AppColors.textSecondary);
          break;
      }
    } catch (e) {
      _showSnack('Action failed: $e', AppColors.error);
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}
