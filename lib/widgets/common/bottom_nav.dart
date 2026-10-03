import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Bottom navigation bar that adapts to each role's available screens.
class RoleBottomNavBar extends StatelessWidget {
  final String role;
  final int currentIndex;
  final Function(int) onTap;

  const RoleBottomNavBar({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 12,
      unselectedFontSize: 11,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      items: _buildItems(),
    );
  }

  List<BottomNavigationBarItem> _buildItems() {
    switch (role) {
      case AppConstants.roleAdmin:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Students'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'Buses'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notices'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ];
      case AppConstants.roleParent:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
                     BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Children'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Bus Map'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notices'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];
      case AppConstants.roleTeacher:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Classes'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Results'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Attendance'),
        ];
      case AppConstants.roleDriver:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'Bus'),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Route'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Tracking'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Trips'),
        ];
      default:
        return const [];
    }
  }
}
