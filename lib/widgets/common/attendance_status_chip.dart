import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/attendance_model.dart';

/// Chip showing an attendance status.
class AttendanceStatusChip extends StatelessWidget {
  final String status;
  const AttendanceStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status.toUpperCase(),
        style: TextStyle(color: color,
            fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case AttendanceStatus.present: return AppColors.presentColor;
      case AttendanceStatus.absent: return AppColors.absentColor;
      case AttendanceStatus.late: return AppColors.lateColor;
      case AttendanceStatus.excused: return AppColors.excusedColor;
      default: return AppColors.textSecondary;
    }
  }
}
