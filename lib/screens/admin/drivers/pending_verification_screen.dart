import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/driver_model.dart';
import '../../../providers/driver_provider.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/school_brand.dart';
import '../../../widgets/common/stat_tile.dart';
import '../../../widgets/common/role_drawer.dart';

/// Admin screen for reviewing pending driver registrations.
class PendingVerificationScreen extends ConsumerStatefulWidget {
  const PendingVerificationScreen({super.key});

  @override
  ConsumerState<PendingVerificationScreen> createState() =>
      _PendingVerificationScreenState();
}

class _PendingVerificationScreenState
    extends ConsumerState<PendingVerificationScreen> {
  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingDriversProvider);
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
            Flexible(
              child: Text(
                AppStrings.pendingVerification,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
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
      body: pendingAsync.when(
        data: (drivers) => drivers.isEmpty
            ? const EmptyState(
                icon: Icons.verified_outlined,
                title: AppStrings.noPendingDrivers,
                subtitle:
                    'All driver registrations have been reviewed.',
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(pendingDriversProvider.future),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: drivers.length,
                  itemBuilder: (context, index) =>
                      _buildRequestCard(drivers[index]),
                ),
              ),
        loading: () => const LoadingWidget(),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Unable to load pending drivers',
          subtitle: error.toString(),
        ),
      ),
    );
  }

  Widget _buildRequestCard(DriverModel driver) {
    final name = driver.name.trim();
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      AppColors.driverColor.withValues(alpha: 0.15),
                  backgroundImage: driver.photoUrl != null
                      ? NetworkImage(driver.photoUrl!)
                      : null,
                  child: driver.photoUrl == null
                      ? Text(
                          initials,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.driverColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        driver.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              children: [
                _detailRow(Icons.phone_outlined, 'Phone', driver.phone),
                if (driver.licenseNumber?.isNotEmpty ?? false)
                  _detailRow(
                      Icons.badge_outlined, 'License', driver.licenseNumber!),
                if (driver.licenseExpiry?.isNotEmpty ?? false)
                  _detailRow(Icons.event_outlined, 'License expiry',
                      driver.licenseExpiry!),
                if (driver.emergencyContact?.isNotEmpty ?? false)
                  _detailRow(
                      Icons.contact_emergency_outlined,
                      'Emergency',
                      '${driver.emergencyContact}'
                      '${driver.emergencyContactPhone?.isNotEmpty ?? false ? ' · ${driver.emergencyContactPhone}' : ''}'),
                if (driver.address?.isNotEmpty ?? false)
                  _detailRow(
                      Icons.location_on_outlined, 'Address', driver.address!),
              ],
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _review(driver, 'rejected', AppColors.absentColor),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text(AppStrings.reject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.absentColor,
                      side: BorderSide(
                          color:
                              AppColors.absentColor.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _review(driver, 'verified', AppColors.presentColor),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(AppStrings.verifyDriver),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.presentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _review(
      DriverModel driver, String status, Color color) async {
    final crud = ref.read(driverCrudProvider.notifier);
    try {
      await crud.updateDriverStatus(driver.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'verified'
                ? '${driver.name} approved and activated.'
                : '${driver.name} registration rejected.',
          ),
          backgroundColor: color,
        ),
      );
      ref.invalidate(pendingDriversProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
