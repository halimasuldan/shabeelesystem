import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/driver_model.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/driver_provider.dart';
import '../../../widgets/common/charts.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/school_brand.dart';
import '../../../widgets/common/stat_tile.dart';

/// Admin reports hub - attendance, transport and driver verification reports.
class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);
    final driversAsync = ref.watch(driversListProvider);

    return Scaffold(
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
                'Reports',
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
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(adminDashboardStatsProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBanner(),
              const SizedBox(height: 16),
              statsAsync.when(
                data: (stats) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAttendanceReport(context, stats),
                    const SizedBox(height: 16),
                    _buildTransportReport(context, stats),
                    const SizedBox(height: 16),
                    _buildDriverReport(context, driversAsync),
                    const SizedBox(height: 16),
                    _buildSummaryStrip(context, stats),
                    const SizedBox(height: 24),
                  ],
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: LoadingWidget(),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: EmptyState(
                    icon: Icons.error_outline,
                    title: 'Unable to load reports',
                    subtitle: error.toString(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
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
              children: const [
                Text(
                  'School Reports',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Attendance, transport and driver insights',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.insights, color: Colors.white, size: 30),
        ],
      ),
    );
  }

  Widget _buildAttendanceReport(BuildContext context, DashboardStats stats) {
    final total =
        stats.presentToday +
        stats.absentToday +
        stats.lateToday +
        stats.excusedToday;
    final rate = total > 0 ? (stats.presentToday / total * 100) : 0.0;
    return _reportCard(
      context,
      title: "Today's Attendance Report",
      icon: Icons.fact_check,
      color: AppColors.schoolBlue,
      trailing: _rateBadge(rate),
      child: Column(
        children: [
          DonutChart(
            slices: [
              ChartSlice(
                label: 'Present',
                value: stats.presentToday.toDouble(),
                color: AppColors.presentColor,
              ),
              ChartSlice(
                label: 'Absent',
                value: stats.absentToday.toDouble(),
                color: AppColors.absentColor,
              ),
              ChartSlice(
                label: 'Late',
                value: stats.lateToday.toDouble(),
                color: AppColors.lateColor,
              ),
              ChartSlice(
                label: 'Excused',
                value: stats.excusedToday.toDouble(),
                color: AppColors.excusedColor,
              ),
            ],
            size: 130,
            centerValue: '$rate%',
            centerLabel: 'attendance',
          ),
          const SizedBox(height: 12),
          ChartLegend(
            slices: [
              ChartSlice(
                label: 'Present',
                value: stats.presentToday.toDouble(),
                color: AppColors.presentColor,
              ),
              ChartSlice(
                label: 'Absent',
                value: stats.absentToday.toDouble(),
                color: AppColors.absentColor,
              ),
              ChartSlice(
                label: 'Late',
                value: stats.lateToday.toDouble(),
                color: AppColors.lateColor,
              ),
              ChartSlice(
                label: 'Excused',
                value: stats.excusedToday.toDouble(),
                color: AppColors.excusedColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.go('/admin/attendance'),
              icon: const Icon(Icons.filter_alt),
              label: const Text('Open filtered attendance report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportReport(BuildContext context, DashboardStats stats) {
    return _reportCard(
      context,
      title: 'Transport Report',
      icon: Icons.directions_bus,
      color: AppColors.schoolOrange,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  value: '${stats.totalBuses}',
                  label: 'Total buses',
                  icon: Icons.directions_bus,
                  color: AppColors.schoolOrange,
                ),
              ),
              Expanded(
                child: StatTile(
                  value: '${stats.activeBuses}',
                  label: 'Buses on route',
                  icon: Icons.route,
                  color: AppColors.schoolTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HorizontalBarChart(
            slices: [
              ChartSlice(
                label: 'Students assigned to buses',
                value: stats.studentsOnBuses.toDouble(),
                color: AppColors.schoolBlue,
              ),
              ChartSlice(
                label: 'Students not assigned',
                value: (stats.totalStudents - stats.studentsOnBuses)
                    .clamp(0, stats.totalStudents)
                    .toDouble(),
                color: AppColors.lateColor,
              ),
            ],
            valueSuffix: ' students',
          ),
        ],
      ),
    );
  }

  Widget _buildDriverReport(
    BuildContext context,
    AsyncValue<List<DriverModel>> driversAsync,
  ) {
    return _reportCard(
      context,
      title: 'Driver Verification Report',
      icon: Icons.badge,
      color: AppColors.driverColor,
      child: driversAsync.when(
        data: (drivers) {
          final pending = drivers.where((d) => d.status == 'pending').length;
          final verified = drivers.where((d) => d.status == 'verified').length;
          final rejected = drivers.where((d) => d.status == 'rejected').length;
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      value: '${drivers.length}',
                      label: 'Total drivers',
                      icon: Icons.directions_car,
                      color: AppColors.driverColor,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      value: '$verified',
                      label: 'Verified',
                      icon: Icons.verified,
                      color: AppColors.presentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      value: '$pending',
                      label: 'Pending review',
                      icon: Icons.hourglass_top,
                      color: AppColors.warning,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      value: '$rejected',
                      label: 'Rejected',
                      icon: Icons.block,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              HorizontalBarChart(
                slices: [
                  ChartSlice(
                    label: 'Verified',
                    value: verified.toDouble(),
                    color: AppColors.presentColor,
                  ),
                  ChartSlice(
                    label: 'Pending',
                    value: pending.toDouble(),
                    color: AppColors.warning,
                  ),
                  ChartSlice(
                    label: 'Rejected',
                    value: rejected.toDouble(),
                    color: AppColors.error,
                  ),
                ],
                valueSuffix: ' drivers',
              ),
              if (pending > 0) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.go('/admin/drivers/pending'),
                  icon: const Icon(Icons.assignment_turned_in, size: 16),
                  label: const Text('Review pending drivers'),
                ),
              ],
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
        error: (_, __) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Unable to load driver data',
        ),
      ),
    );
  }

  Widget _buildSummaryStrip(BuildContext context, DashboardStats stats) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surfaceVariant, AppColors.cardBackground],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Figures',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  '${stats.totalStudents}',
                  'Students',
                  AppColors.schoolBlue,
                ),
              ),
              Container(
                width: 1,
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _summaryItem(
                  '${stats.totalParents}',
                  'Parents',
                  AppColors.parentColor,
                ),
              ),
              Container(
                width: 1,
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _summaryItem(
                  '${stats.totalTeachers}',
                  'Teachers',
                  AppColors.teacherColor,
                ),
              ),
              Container(
                width: 1,
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _summaryItem(
                  '${stats.totalBuses}',
                  'Buses',
                  AppColors.schoolOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String label, Color color) {
    return Column(
      children: [
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
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _rateBadge(double rate) {
    final color = rate >= 90
        ? AppColors.presentColor
        : (rate >= 75 ? AppColors.warning : AppColors.error);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${rate.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _reportCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.divider.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
