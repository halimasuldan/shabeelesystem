import 'package:flutter/material.dart';

import '../../../models/pickup_dropoff_model.dart';
import 'bus_run_status_screen.dart';

/// Mark student pickup status - the driver's **morning run** (home → school).
///
/// Thin wrapper over the shared [BusRunStatusScreen]: it opens on the morning
/// run (children waiting at home → picked up → on bus → at school), while the
/// selector on top still lets the driver jump to the afternoon run here.
/// The old revision of this screen queried `students` with its own inline
/// stream and showed a bare "No students assigned." when the bus was still
/// resolving; both are now handled by the shared screen.
class StudentPickupScreen extends StatelessWidget {
  const StudentPickupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BusRunStatusScreen(
      initialTripType: PickupDropoffModel.tripMorning,
      appBarColor: Color.fromARGB(255, 68, 175, 241),
    );
  }
}
