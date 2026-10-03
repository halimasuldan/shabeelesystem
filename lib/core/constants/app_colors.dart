import 'package:flutter/material.dart';

/// School-themed color palette for Shabelle Primary School.
class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF1A73E8);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF63A4FF);
  static const Color accent = Color(0xFF34A853);

  // School themed
  static const Color schoolBlue = Color(0xFF1A73E8);
  static const Color schoolGreen = Color(0xFF34A853);
  static const Color schoolOrange = Color(0xFFFF9800);
  static const Color schoolRed = Color(0xFFEA4335);
  static const Color schoolPurple = Color(0xFF9C27B0);
  static const Color schoolTeal = Color(0xFF009688);

  // Attendance colors
  static const Color presentColor = Color(0xFF4CAF50);
  static const Color absentColor = Color(0xFFF44336);
  static const Color lateColor = Color(0xFFFF9800);
  static const Color excusedColor = Color(0xFF2196F3);

  // Bus status colors
  static const Color availableColor = Color(0xFF4CAF50);
  static const Color onRouteColor = Color(0xFF1565C0);
  static const Color returningColor = Color(0xFF0D47A1);

  // Neutral colors
  static const Color background = Color(0xFFF5F7FA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE3F2FD);
  static const Color textPrimary = Color(0xFF202124);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color textDisabled = Color(0xFFB0B3B8);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color error = Color(0xFFEA4335);
  static const Color success = Color(0xFF34A853);
  static const Color warning = Color(0xFFFF9800);

  // Role colors
  static const Color adminColor = Color(0xFF5F6368);
  static const Color parentColor = Color(0xFF1A73E8);
  static const Color teacherColor = Color(0xFF34A853);
  static const Color driverColor = Color(0xFFFF9800);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient schoolGradient = LinearGradient(
    colors: [schoolBlue, Color(0xFF42A5F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
