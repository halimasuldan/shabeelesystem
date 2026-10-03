import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pickup_dropoff_service.dart';
import '../../../models/pickup_dropoff_model.dart';
import '../../../models/student_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/driver_provider.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/role_drawer.dart';

/// One of the driver's two daily bus runs, shown as a student list with a
/// status dropdown per child.
///
/// Shared by the Student Pickup and Student Drop-off screens: both used to
/// duplicate the bus/student query, so fixes (like explaining *why* no
/// students appear) could drift apart. Each screen picks its starting run and
/// the selector at the top lets the driver flip between runs in place:
///
/// * **Home → school** (morning): waiting → picked up → on bus → at school
/// * **School → home** (afternoon): waiting → picked up → on bus → dropped off
///
/// The list comes from the keep-alive `driverStudentsProvider`, so navigating
/// between screens never restarts the query into an empty "No students
/// assigned." state.
class BusRunStatusScreen extends ConsumerStatefulWidget {
  const BusRunStatusScreen({
    super.key,
    required this.initialTripType,
    required this.appBarColor,
  });

  /// Run this screen opens on (`PickupDropoffModel.tripMorning` or
  /// `tripAfternoon`); the driver can switch runs with the selector.
  final String initialTripType;

  /// AppBar colour, kept distinct per screen so the driver can tell whether
  /// they came from the dashboard's "Home → School" or "School → Home" tile.
  final Color appBarColor;

  @override
  ConsumerState<BusRunStatusScreen> createState() => _BusRunStatusScreenState();
}

class _BusRunStatusScreenState extends ConsumerState<BusRunStatusScreen> {
  late String _tripType = widget.initialTripType;

  /// Status pipeline for the morning run (home → school).
  static const List<String> _morningStatuses = [
    'waiting',
    'picked_up',
    'on_bus',
    'at_school',
    'absent',
  ];

  /// Status pipeline for the afternoon run (school → home).
  static const List<String> _afternoonStatuses = [
    'waiting',
    'picked_up',
    'on_bus',
    'dropped_off',
    'absent',
  ];

  List<String> get _statusOrder => _tripType == PickupDropoffModel.tripMorning
      ? _morningStatuses
      : _afternoonStatuses;

  /// Short dropdown label for a raw status value.
  String _statusLabel(String status) {
    switch (status) {
      case 'waiting':
        return 'Waiting';
      case 'picked_up':
        return 'Picked Up';
      case 'on_bus':
        return 'On Bus';
      case 'at_school':
        return 'Arrived at School';
      case 'dropped_off':
        return 'Dropped Off';
      case 'absent':
        return 'Absent';
      case 'pending':
        return 'Pending';
      default:
        return PickupDropoffModel.labelFor(status);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshAssignments();
    });
  }

  Future<void> _refreshAssignments() async {
    ref.invalidate(driverBusIdProvider);
    ref.invalidate(driverAssignedBusProvider);
    ref.invalidate(driverStudentsProvider);
    await ref.read(driverBusIdProvider.future);
    await ref.read(driverStudentsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(authServiceProvider).currentUser;
    return Scaffold(
      appBar: AppBar(
        // The title follows the selected run so it can never disagree with
        // the statuses being edited underneath it.
        title: Text(
          _tripType == PickupDropoffModel.tripMorning
              ? 'Home → School Run'
              : 'School → Home Run',
        ),
        backgroundColor: widget.appBarColor,
        foregroundColor: Colors.white,
      ),
      drawer: RoleBasedDrawer(
        role: AppConstants.roleDriver,
        userName: user?.displayName ?? 'Driver',
        userEmail: user?.email ?? '',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: PickupDropoffModel.tripMorning,
                  label: Text('Home → School'),
                  icon: Icon(Icons.home),
                ),
                ButtonSegment(
                  value: PickupDropoffModel.tripAfternoon,
                  label: Text('School → Home'),
                  icon: Icon(Icons.school),
                ),
              ],
              selected: {_tripType},
              onSelectionChanged: (selection) =>
                  setState(() => _tripType = selection.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAssignments,
              child: _buildRunBody(),
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves the bus first (to keep the old diagnostics for "no bus") and
  /// then renders the shared student list for the selected run.
  Widget _buildRunBody() {
    final busAsync = ref.watch(driverBusIdProvider);
    return busAsync.when(
      // Keep the last resolved bus on screen while it re-resolves so the list
      // does not flash back to a full-screen loader on unrelated rebuilds.
      skipLoadingOnReload: true,
      loading: () => const LoadingWidget(),
      error: (error, _) =>
          _refreshableMessage('Unable to load your bus: $error'),
      data: (busId) {
        if (busId == null || busId.isEmpty) {
          // Say what is actually missing: without a bus there is nothing to
          // list, and the fix lives on the admin Bus Management screen.
          return _diagnostic(
            icon: Icons.directions_bus_outlined,
            heading: 'No bus is assigned to you yet.',
            detail:
                'The chain that links you to your students is:\n'
                'driver account → driver profile → bus → students.\n\n'
                'It stops at “bus”: an administrator must assign you a '
                'bus on the Bus Management screen before your students '
                'appear here.',
          );
        }
        // One shared, keep-alive query for the dashboard and both run
        // screens - never a fresh inline stream that starts empty.
        return ref
            .watch(driverStudentsProvider)
            .when(
              skipLoadingOnReload: true,
              loading: () => const LoadingWidget(),
              error: (error, _) =>
                  _refreshableMessage('Unable to load students: $error'),
              data: (students) {
                if (students.isEmpty) {
                  return _diagnostic(
                    icon: Icons.people_outline,
                    heading:
                        'Bus $busId is assigned to you, but no students '
                        'are linked to it.',
                    detail:
                        'The chain that links you to your students is:\n'
                        'driver account → driver profile → bus → students.\n\n'
                        'It stops at “students”: an administrator must '
                        'assign students to bus $busId (Admin → Student Bus '
                        'Assignment). Then pull down to refresh.',
                  );
                }
                return _buildStudentList(busId, students);
              },
            );
      },
    );
  }

  /// Full-screen explanation used for both broken-chain states, so the driver
  /// knows exactly which link is missing instead of a bare "No students
  /// assigned."
  Widget _diagnostic({
    required IconData icon,
    required String heading,
    required String detail,
  }) {
    final uid = ref.read(authServiceProvider).currentUser?.uid ?? 'unknown';
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(
              heading,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Signed in as: $uid',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _refreshableMessage(String message) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentList(String busId, List<StudentModel> students) {
    // Which of the two mirrors the selected run writes to:
    // morning → `pickupStatus`, afternoon → `dropoffStatus`.
    final mirrorField = PickupDropoffService.statusFieldForTrip(_tripType);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final status = student.statusForField(mirrorField);
        // A stored status from the other run's pipeline (or an unknown
        // legacy value) must still appear in the dropdown, otherwise
        // DropdownButton asserts on a value outside its items.
        final statuses = <String>[..._statusOrder];
        if (!statuses.contains(status)) statuses.insert(0, status);
        return Card(
          child: ListTile(
            title: Text(
              student.fullName.isEmpty ? 'Student' : student.fullName,
            ),
            subtitle: Text(
              '${PickupDropoffModel.labelForTrip(_tripType)} · '
              'Status: ${_statusLabel(status)}',
            ),
            trailing: DropdownButton<String>(
              value: status,
              items: [
                for (final s in statuses)
                  DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
              ],
              onChanged: (v) => _updateStatus(student, v),
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(StudentModel student, String? status) async {
    if (status == null) return;
    final messenger = ScaffoldMessenger.of(context);
    // The bus comes from the same resolver the list was built from, so the
    // event can never be recorded against a stale or empty bus id.
    final busId = ref.read(driverBusIdProvider).valueOrNull ?? '';
    if (busId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No bus is assigned to you yet.')),
      );
      return;
    }
    try {
      // Writes the timestamped `pickup_dropoff` event (tagged with this run)
      // the parent timeline reads, mirrors the status onto the matching run
      // field of the student document, and notifies the child's parents with
      // the child's name, the time and which run it happened on.
      await PickupDropoffService.instance.recordEvent(
        studentId: student.id,
        studentName: student.fullName,
        status: status,
        // Derive what happened from the status so the timeline reads
        // correctly on either run (arrival = drop-off, boarding = pickup).
        eventType: PickupDropoffModel.eventTypeForStatus(status),
        tripType: _tripType,
        busId: busId,
        driverId: ref.read(authServiceProvider).currentUser?.uid,
      );
    } catch (e) {
      // Surfaced because the security rules restrict which students a driver
      // may edit; a silent failure here looks like the app ignored the tap.
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update status: $e')),
      );
    }
  }
}
