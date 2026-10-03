import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/pickup_dropoff_model.dart';
import 'bus_run_status_screen.dart';

/// Mark student drop-off status - the driver's **afternoon run**
/// (school → home).
///
/// Thin wrapper over the shared [BusRunStatusScreen]: it opens on the
/// afternoon run (children waiting at school → picked up → on bus → dropped
/// off at home), while the selector on top still lets the driver jump to the
/// morning run here. The old revision of this screen queried `students` with
/// its own inline stream and showed a bare "No students assigned." when the
/// bus was still resolving; both are now handled by the shared screen.
class StudentDropoffScreen extends StatelessWidget {
  const StudentDropoffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BusRunStatusScreen(
      initialTripType: PickupDropoffModel.tripAfternoon,
      appBarColor: AppColors.primary,
    );
  }
}
