import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_constants.dart';
import '../../models/student_model.dart';

/// Card widget for displaying a student in lists.
class StudentCard extends StatelessWidget {
  final StudentModel student;
  final VoidCallback? onTap;
  final bool showBusInfo;
  final String? parentLabel;

  const StudentCard({
    super.key,
    required this.student,
    this.onTap,
    this.showBusInfo = false,
    this.parentLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: student.photoUrl != null
              ? CachedNetworkImageProvider(student.photoUrl!)
              : null,
          child: student.photoUrl == null
              ? const Icon(Icons.person, size: 24)
              : null,
        ),
        title: Text(
          student.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${student.studentCode} • ${student.className}'),
            if (student.busId != null && showBusInfo)
              Text(
                'Bus: ${student.busId!}',
                style: TextStyle(color: AppColors.schoolBlue),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(student.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                student.status.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'active') return AppColors.presentColor;
    return AppColors.absentColor;
  }
}

/// Chip widget for attendance status display.
class AttendanceStatusChip extends StatelessWidget {
  final String status;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const AttendanceStatusChip({
    super.key,
    required this.status,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (status) {
      case AppConstants.attendancePresent:
        color = AppColors.presentColor;
        icon = Icons.check_circle;
        break;
      case AppConstants.attendanceAbsent:
        color = AppColors.absentColor;
        icon = Icons.cancel;
        break;
      case AppConstants.attendanceLate:
        color = AppColors.lateColor;
        icon = Icons.access_time;
        break;
      case AppConstants.attendanceExcused:
        color = AppColors.excusedColor;
        icon = Icons.info;
        break;
      default:
        color = AppColors.textSecondary;
        icon = Icons.help_outline;
    }

    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            _getStatusText(status),
            style: TextStyle(
              color: color,
              fontSize: fontSize ?? 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case AppConstants.attendancePresent:
        return AppStrings.present;
      case AppConstants.attendanceAbsent:
        return AppStrings.absent;
      case AppConstants.attendanceLate:
        return AppStrings.late;
      case AppConstants.attendanceExcused:
        return AppStrings.excused;
      default:
        return status;
    }
  }
}
