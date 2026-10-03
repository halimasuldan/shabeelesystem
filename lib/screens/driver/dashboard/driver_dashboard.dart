import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/dashboard_card.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/driver_provider.dart';
import '../../../models/student_model.dart';

/// Driver dashboard screen.
///
/// Stability notes (this screen used to flicker / "come and go"):
/// * auth is watched reactively via [authStateProvider] instead of being read
///   once per build from `authServiceProvider.currentUser`, so the signed-out
///   placeholder only appears when the session is actually gone;
/// * the driver profile comes from the keep-alive `driverByUserIdProvider`
///   rather than an inline `StreamBuilder` - the old code built a *new*
///   stream on every rebuild, which made `StreamBuilder` re-subscribe and
///   flash the full-screen loading widget on unrelated state changes;
/// * bus and student data come from the keep-alive provider chain in
///   `driver_provider.dart`, so a re-resolve keeps the previous value on
///   screen instead of snapping back to `N/A` / `0`.
class DriverDashboard extends ConsumerWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One reactive gate: while Firebase restores the session we show a single
    // loading state; only a confirmed sign-out shows the signed-out message.
    final authAsync = ref.watch(authStateProvider);
    final user = authAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: user == null
          ? null
          : RoleBasedDrawer(
              role: AppConstants.roleDriver,
              userName: user.displayName ?? 'Driver',
              userEmail: user.email ?? '',
            ),
      body: _buildBody(context, ref, user, authAsync.isLoading),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    bool authLoading,
  ) {
    if (user == null) {
      // Distinguish "still restoring" from "really signed out" so the
      // dashboard does not flash the sign-out message on every session check.
      if (authLoading) return const LoadingWidget();
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'You are signed out. Please sign in again to view your driver dashboard.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final uid = user.uid as String;
    final driverAsync = ref.watch(driverByUserIdProvider(uid));
    final driverName =
        driverAsync.valueOrNull?.name ??
        (user.displayName as String?) ??
        (user.email as String?)?.split('@').first ??
        'Driver';

    // Bus and student assignments are resolved from the authenticated uid and
    // bus documents; an unavailable profile document must not hide them.
    return _buildDashboard(context, ref, driverName);
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    String driverName,
  ) {
    // The bus assignment of record lives on `buses/{id}.driverId`, so use the
    // resolver provider instead of the driver document's `busId` mirror -
    // which the admin screens never set, leaving this dashboard on
    // 'No bus assigned' / 'N/A' even when a bus was assigned.
    final assignedBus = ref.watch(driverAssignedBusProvider).valueOrNull;
    final busLabel = assignedBus == null
        ? null
        : (assignedBus.busNumber.isEmpty
              ? assignedBus.id
              : assignedBus.busNumber);
    // Count from the same students query the run screens use. The keep-alive
    // provider keeps its previous value during a re-resolve, so neither the
    // student count nor the run progress cards blink during refreshes.
    final driverStudentsAsync = ref.watch(driverStudentsProvider);
    final driverStudents = driverStudentsAsync.valueOrNull;
    final students = driverStudents ?? const [];
    final totalStudents =
        driverStudents?.length ?? assignedBus?.studentIds.length ?? 0;
    // Progress of the day's two runs: the morning run ends with every child
    // at school, the afternoon run ends with every child dropped back home.
    final morningDone = students
        .where((s) => s.pickupStatus == AppConstants.statusAtSchool)
        .length;
    final afternoonDone = students
        .where((s) => s.dropoffStatus == AppConstants.statusDroppedOff)
        .length;

    return RefreshIndicator(
      // Force the keep-alive chain to re-resolve: after an administrator
      // assigns a bus/route while the driver app is open, this is what picks
      // the change up without a restart.
      onRefresh: () async {
        ref.invalidate(driverByUserIdProvider);
        ref.invalidate(driverBusIdProvider);
        ref.invalidate(driverAssignedBusProvider);
        ref.invalidate(driverStudentsProvider);
        ref.invalidate(driverRouteProvider);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildWelcomeHeader(context, busLabel, driverName),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              DashboardCard(
                title: 'Assigned Bus',
                value: busLabel ?? 'N/A',
                icon: Icons.directions_bus,
                color: AppColors.schoolBlue,
              ),
              DashboardCard(
                title: 'Students',
                value: '$totalStudents',
                icon: Icons.people,
                color: AppColors.schoolOrange,
              ),
              DashboardCard(
                title: 'Home → School',
                value: totalStudents == 0 ? '—' : '$morningDone/$totalStudents',
                icon: Icons.school,
                color: AppColors.schoolGreen,
              ),
              DashboardCard(
                title: 'School → Home',
                value: totalStudents == 0
                    ? '—'
                    : '$afternoonDone/$totalStudents',
                icon: Icons.home,
                color: AppColors.schoolPurple,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Assigned Students',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _buildAssignedStudents(driverStudentsAsync),
          const SizedBox(height: 20),
          Text(
            'Bus Operations',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _buildActionGrid(context),
        ],
      ),
    );
  }

  Widget _buildAssignedStudents(AsyncValue<List<StudentModel>> studentsAsync) {
    return studentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline, color: AppColors.error),
          title: const Text('Could not load assigned students'),
          subtitle: Text(error.toString()),
        ),
      ),
      data: (students) {
        if (students.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.people_outline),
              title: Text('No students assigned to this bus yet.'),
            ),
          );
        }
        return Card(
          child: Column(
            children: [
              for (var index = 0; index < students.length; index++) ...[
                ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      students[index].fullName.isEmpty
                          ? '?'
                          : students[index].fullName[0].toUpperCase(),
                    ),
                  ),
                  title: Text(students[index].fullName),
                  subtitle: Text(
                    students[index].className.isEmpty
                        ? students[index].studentCode
                        : '${students[index].className} · ${students[index].studentCode}',
                  ),
                ),
                if (index < students.length - 1)
                  const Divider(height: 1, indent: 72),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader(
    BuildContext context,
    String? busId,
    String driverName,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.schoolGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(Icons.directions_bus, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName.isEmpty ? 'Driver Operations' : driverName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  busId == null ? 'No bus assigned' : 'Bus $busId is ready',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        _action(context, Icons.play_circle, 'Start Trip', '/driver/start-trip'),
        // Each tile opens one of the driver's two daily runs; the screen
        // itself also has a run selector for switching without going back.
        _action(
          context,
          Icons.person_add,
          'Home → School Run',
          '/driver/student/pickup',
        ),
        _action(
          context,
          Icons.school,
          'School → Home Run',
          '/driver/student/dropoff',
        ),
        _action(
          context,
          Icons.location_on,
          'Live GPS',
          '/driver/live-tracking',
        ),
        _action(context, Icons.route, 'Route Map', '/driver/route/map'),
        _action(
          context,
          Icons.directions_bus,
          'Bus Details',
          '/driver/bus/details',
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    return Card(
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
