import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/common/school_brand.dart';
import '../../../widgets/common/stat_tile.dart';
import '../../../widgets/common/charts.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/driver_provider.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  String _userName = 'Admin';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? user.email ?? 'Admin';
        _userEmail = user.email ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);
    final driversAsync = ref.watch(driversListProvider);
    final isWide = useSideMenu(context);

    return Scaffold(
      appBar: AppBar(
        leading: isWide
            ? null
            : Builder(
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
                AppConstants.appName,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => context.go('/admin/notifications'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isWide
          ? null
          : RoleBasedDrawer(
              role: AppConstants.roleAdmin,
              userName: _userName,
              userEmail: _userEmail,
            ),
      body: SideMenuLayout(
        role: AppConstants.roleAdmin,
        userName: _userName,
        userEmail: _userEmail,
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.refresh(adminDashboardStatsProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeBanner(),
                const SizedBox(height: 18),
                statsAsync.when(
                  data: (stats) => Column(
                    children: [
                      _buildStatGrid(stats),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildAttendanceCard(stats)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDriversCard(driversAsync)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildActivityStrip(stats),
                      const SizedBox(height: 18),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                    ],
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: LoadingWidget(),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.all(32),
                    child: EmptyState(
                      icon: Icons.error_outline,
                      title: 'Unable to load dashboard',
                      subtitle: error.toString(),
                      action: ElevatedButton(
                        onPressed: () =>
                            ref.refresh(adminDashboardStatsProvider.future),
                        child: const Text('Retry'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
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
                Text(
                  'Good ${_timeGreeting()}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'Administrator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Widget _buildStatGrid(DashboardStats stats) {
    final cards = [
      _statCard(
        Icons.school,
        'Total Students',
        stats.totalStudents.toString(),
        AppColors.schoolBlue,
      ),
      _statCard(
        Icons.family_restroom,
        'Parents',
        stats.totalParents.toString(),
        AppColors.parentColor,
      ),
      _statCard(
        Icons.person,
        'Teachers',
        stats.totalTeachers.toString(),
        AppColors.teacherColor,
      ),
      _statCard(
        Icons.directions_bus,
        'Buses',
        stats.totalBuses.toString(),
        AppColors.schoolOrange,
      ),
      _statCard(Icons.directions_car, 'Drivers', '0', AppColors.driverColor),
      _statCard(
        Icons.directions_bus,
        'Active Buses',
        stats.activeBuses.toString(),
        AppColors.schoolTeal,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => cards[index],
          ),
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(DashboardStats stats) {
    final total =
        stats.presentToday +
        stats.absentToday +
        stats.lateToday +
        stats.excusedToday;
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Attendance",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$total students',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
            size: 120,
            strokeWidth: 14,
            centerValue: total.toString(),
            centerLabel: 'total',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _legendRow(
                AppColors.presentColor,
                'Present',
                stats.presentToday.toString(),
              ),
              _legendRow(
                AppColors.absentColor,
                'Absent',
                stats.absentToday.toString(),
              ),
              _legendRow(
                AppColors.lateColor,
                'Late',
                stats.lateToday.toString(),
              ),
              _legendRow(
                AppColors.excusedColor,
                'Excused',
                stats.excusedToday.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDriversCard(AsyncValue<List<dynamic>> driversAsync) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Drivers',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () => context.go('/admin/drivers'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          driversAsync.when(
            data: (drivers) {
              final count = drivers.length;
              return StatTile(
                value: count.toString(),
                label: 'Active drivers registered',
                icon: Icons.directions_car,
                color: AppColors.driverColor,
              );
            },
            loading: () => const StatTile(
              value: '--',
              label: 'Loading drivers...',
              icon: Icons.hourglass_empty,
              color: AppColors.textSecondary,
            ),
            error: (_, __) => const StatTile(
              value: '0',
              label: 'Unable to load drivers',
              icon: Icons.error_outline,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStrip(DashboardStats stats) {
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
            "Today's Snapshot",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _activityItem(
                  Icons.check_circle,
                  '${stats.presentToday}',
                  'Present',
                  AppColors.presentColor,
                ),
              ),
              Container(
                width: 1,
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _activityItem(
                  Icons.cancel,
                  '${stats.absentToday}',
                  'Absent',
                  AppColors.absentColor,
                ),
              ),
              Container(
                width: 1,
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _activityItem(
                  Icons.schedule,
                  '${stats.lateToday}',
                  'Late',
                  AppColors.lateColor,
                ),
              ),
              Container(
                width: 1,
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _activityItem(
                  Icons.directions_bus,
                  '${stats.activeBuses}',
                  'Active buses',
                  AppColors.schoolTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityItem(IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
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
          Text(
            'Quick Actions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _actionChip(
                Icons.person_add,
                'Add Student',
                () => context.go('/admin/students/add'),
              ),
              _actionChip(
                Icons.family_restroom,
                'Add Parent',
                () => context.go('/admin/parents'),
              ),
              _actionChip(
                Icons.person,
                'Add Teacher',
                () => context.go('/admin/teachers'),
              ),
              _actionChip(
                Icons.directions_car,
                'Register Driver',
                () => context.go('/admin/drivers/register'),
              ),
              _actionChip(
                Icons.directions_bus,
                'Add Bus',
                () => context.go('/admin/buses'),
              ),
              _actionChip(
                Icons.route,
                'Add Route',
                () => context.go('/admin/routes'),
              ),
              _actionChip(
                Icons.link,
                'Link Parent-Student',
                () => context.go('/admin/linking'),
              ),
              _actionChip(
                Icons.quiz,
                'Exam Setup',
                () => context.go('/admin/exams'),
              ),
              _actionChip(
                Icons.assignment,
                'Bus Assignment',
                () => context.go('/admin/bus-assignment'),
              ),
              _actionChip(
                Icons.assignment_turned_in,
                'Pending Verification',
                () => context.go('/admin/drivers/pending'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
