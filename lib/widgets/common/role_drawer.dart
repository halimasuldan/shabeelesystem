import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import 'school_brand.dart';

/// Width of the navigation panel on wide layouts.
const double kSideMenuWidth = 288;

/// Width at which the menu switches from a drawer to a persistent side panel.
const double kSideMenuBreakpoint = 1000;

/// A labelled group of destinations inside the side menu.
class SideMenuSection {
  const SideMenuSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// A navigation entry, optionally holding nested entries.
class SideMenuEntry {
  const SideMenuEntry(
    this.icon,
    this.label,
    this.route, {
    this.children = const <SideMenuEntry>[],
  });

  final IconData icon;
  final String label;
  final String route;
  final List<SideMenuEntry> children;
}

/// A section together with the entries it groups.
class SideMenuGroup {
  const SideMenuGroup(this.section, this.entries);

  final SideMenuSection section;
  final List<SideMenuEntry> entries;
}

/// True when the screen is wide enough for a persistent side menu.
bool useSideMenu(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kSideMenuBreakpoint;

/// Navigation structure for the administrator role.
const List<SideMenuGroup> kAdminMenu = <SideMenuGroup>[
  SideMenuGroup(
    SideMenuSection('Overview', Icons.space_dashboard_outlined),
    <SideMenuEntry>[
      SideMenuEntry(Icons.dashboard_rounded, 'Dashboard', '/admin/dashboard'),
      SideMenuEntry(
        Icons.notifications_active_outlined,
        'Notifications',
        '/admin/notifications',
      ),
    ],
  ),
  SideMenuGroup(
    SideMenuSection('People', Icons.groups_outlined),
    <SideMenuEntry>[
      SideMenuEntry(Icons.school_rounded, 'Students', '/admin/students'),
      SideMenuEntry(Icons.family_restroom_rounded, 'Parents', '/admin/parents'),
      SideMenuEntry(Icons.co_present_rounded, 'Teachers', '/admin/teachers'),
      SideMenuEntry(
        Icons.badge_outlined,
        'Drivers',
        '/admin/drivers',
        children: <SideMenuEntry>[
          SideMenuEntry(
            Icons.person_add_alt_rounded,
            'Register Driver',
            '/admin/drivers/register',
          ),
          SideMenuEntry(
            Icons.verified_outlined,
            'Pending Verification',
            '/admin/drivers/pending',
          ),
        ],
      ),
      SideMenuEntry(
        Icons.manage_accounts_outlined,
        'User Accounts',
        '/admin/users',
      ),
    ],
  ),
  SideMenuGroup(
    SideMenuSection('Transport', Icons.directions_bus_outlined),
    <SideMenuEntry>[
      SideMenuEntry(Icons.airport_shuttle_rounded, 'Buses', '/admin/buses'),
      SideMenuEntry(Icons.alt_route_rounded, 'Routes', '/admin/routes'),
      SideMenuEntry(
        Icons.assignment_ind_outlined,
        'Bus Assignment',
        '/admin/bus-assignment',
      ),
    ],
  ),
  SideMenuGroup(SideMenuSection('Academics', Icons.menu_book_outlined), <
    SideMenuEntry
  >[
    SideMenuEntry(Icons.class_rounded, 'Classes', '/admin/classes'),
    SideMenuEntry(Icons.library_books_rounded, 'Subjects', '/admin/subjects'),
    SideMenuEntry(Icons.quiz_outlined, 'Exam Setup', '/admin/exams'),
    SideMenuEntry(
      Icons.assessment_outlined,
      'Exam Gradebook',
      '/admin/exam-results',
    ),
    SideMenuEntry(Icons.fact_check_outlined, 'Attendance', '/admin/attendance'),
  ]),
  SideMenuGroup(SideMenuSection('Administration', Icons.settings_outlined), <
    SideMenuEntry
  >[
    SideMenuEntry(Icons.link_rounded, 'Parent-Student Link', '/admin/linking'),
    SideMenuEntry(Icons.tune_rounded, 'Settings', '/admin/settings'),
    SideMenuEntry(
      Icons.lock_reset_outlined,
      'Change Password',
      '/account/password',
    ),
  ]),
];

/// Navigation structure for the teacher role.
const List<SideMenuGroup> kTeacherMenu = <SideMenuGroup>[
  SideMenuGroup(
    SideMenuSection('Overview', Icons.space_dashboard_outlined),
    <SideMenuEntry>[
      SideMenuEntry(Icons.dashboard_rounded, 'Dashboard', '/teacher/dashboard'),
    ],
  ),
  SideMenuGroup(
    SideMenuSection('Attendance', Icons.fact_check_outlined),
    <SideMenuEntry>[
      SideMenuEntry(
        Icons.school_rounded,
        'My Classes',
        '/teacher/mark-attendance',
      ),
      SideMenuEntry(
        Icons.analytics_outlined,
        'Attendance History',
        '/teacher/attendance/history',
      ),
    ],
  ),
  SideMenuGroup(
    SideMenuSection('Examinations', Icons.quiz_outlined),
    <SideMenuEntry>[
      SideMenuEntry(
        Icons.menu_book_rounded,
        'Enter Exam Results',
        '/teacher/exam-results',
      ),
      SideMenuEntry(Icons.quiz_outlined, 'Manage Exams', '/teacher/exams'),
      SideMenuEntry(
        Icons.assessment_outlined,
        'Exam Gradebook',
        '/teacher/exam-results/entered',
      ),
      SideMenuEntry(
        Icons.lock_reset_outlined,
        'Change Password',
        '/account/password',
      ),
    ],
  ),
];

/// Navigation structure for the parent role.
const List<SideMenuGroup> kParentMenu = <SideMenuGroup>[
  SideMenuGroup(
    SideMenuSection('Overview', Icons.space_dashboard_outlined),
    <SideMenuEntry>[
      SideMenuEntry(Icons.dashboard_rounded, 'Dashboard', '/parent/dashboard'),
      SideMenuEntry(
        Icons.notifications_active_outlined,
        'Notifications',
        '/parent/notifications',
      ),
    ],
  ),
  SideMenuGroup(SideMenuSection('My Family', Icons.family_restroom_outlined), <
    SideMenuEntry
  >[
    SideMenuEntry(Icons.child_care_rounded, 'My Children', '/parent/children'),
    SideMenuEntry(
      Icons.person_outline_rounded,
      'My Profile',
      '/parent/profile',
    ),
  ]),
  SideMenuGroup(
    SideMenuSection('Learning', Icons.school_outlined),
    <SideMenuEntry>[
      SideMenuEntry(
        Icons.assessment_outlined,
        'Exam Gradebook',
        '/parent/exam-results',
      ),
      SideMenuEntry(
        Icons.lock_reset_outlined,
        'Change Password',
        '/account/password',
      ),
    ],
  ),
  SideMenuGroup(
    SideMenuSection('Tracking', Icons.location_on_outlined),
    <SideMenuEntry>[
      SideMenuEntry(
        Icons.directions_bus_rounded,
        'Bus Tracking',
        '/parent/bus/tracking',
        children: <SideMenuEntry>[
          SideMenuEntry(
            Icons.airport_shuttle_rounded,
            'Bus Details',
            '/parent/bus/details',
          ),
        ],
      ),
      SideMenuEntry(
        Icons.fact_check_outlined,
        'Attendance',
        '/parent/attendance/history',
      ),
      SideMenuEntry(
        Icons.swap_vert_rounded,
        'Pickup & Drop-off',
        '/parent/bus-activity',
      ),
    ],
  ),
];

/// Navigation structure for the driver role.
const List<SideMenuGroup> kDriverMenu = <SideMenuGroup>[
  SideMenuGroup(
    SideMenuSection('Overview', Icons.space_dashboard_outlined),
    <SideMenuEntry>[
      SideMenuEntry(Icons.dashboard_rounded, 'Dashboard', '/driver/dashboard'),
    ],
  ),
  SideMenuGroup(
    SideMenuSection('Current Trip', Icons.route_outlined),
    <SideMenuEntry>[
      SideMenuEntry(
        Icons.play_circle_rounded,
        'Start Trip',
        '/driver/start-trip',
      ),
      SideMenuEntry(
        Icons.location_searching_rounded,
        'Live Tracking',
        '/driver/live-tracking',
      ),
      SideMenuEntry(Icons.map_outlined, 'Route Map', '/driver/route/map'),
      SideMenuEntry(
        Icons.history_rounded,
        'Trip History',
        '/driver/trip/history',
      ),
    ],
  ),
  SideMenuGroup(
    SideMenuSection('Students', Icons.groups_outlined),
    <SideMenuEntry>[
      SideMenuEntry(
        Icons.person_add_alt_rounded,
        'Student Pickup',
        '/driver/student/pickup',
      ),
      SideMenuEntry(
        Icons.school_rounded,
        'Student Drop-off',
        '/driver/student/dropoff',
      ),
    ],
  ),
  SideMenuGroup(
    SideMenuSection('Vehicle', Icons.directions_bus_outlined),
    <SideMenuEntry>[
      SideMenuEntry(
        Icons.airport_shuttle_rounded,
        'Bus Details',
        '/driver/bus/details',
      ),
      SideMenuEntry(
        Icons.lock_reset_outlined,
        'Change Password',
        '/account/password',
      ),
    ],
  ),
];

/// Role-aware navigation drawer used by every screen with a hamburger menu.
class RoleBasedDrawer extends ConsumerWidget {
  const RoleBasedDrawer({
    super.key,
    required this.role,
    required this.userName,
    required this.userEmail,
  });

  final String role;
  final String userName;
  final String userEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      width: kSideMenuWidth,
      backgroundColor: AppColors.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SideMenuPanel(
        role: role,
        userName: userName,
        userEmail: userEmail,
        showCloseButton: true,
      ),
    );
  }
}

/// Persistent form of the menu, rendered beside the content on wide layouts.
class RoleBasedSideMenu extends StatelessWidget {
  const RoleBasedSideMenu({
    super.key,
    required this.role,
    required this.userName,
    required this.userEmail,
  });

  final String role;
  final String userName;
  final String userEmail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kSideMenuWidth,
      child: SideMenuPanel(
        role: role,
        userName: userName,
        userEmail: userEmail,
      ),
    );
  }
}

/// Shows [child] next to a persistent side menu on wide layouts. On narrow
/// layouts [child] is returned unchanged so the drawer can be used instead.
class SideMenuLayout extends StatelessWidget {
  const SideMenuLayout({
    super.key,
    required this.role,
    required this.userName,
    required this.userEmail,
    required this.child,
  });

  final String role;
  final String userName;
  final String userEmail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!useSideMenu(context)) return child;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RoleBasedSideMenu(role: role, userName: userName, userEmail: userEmail),
        Expanded(child: child),
      ],
    );
  }
}

/// The shared side-menu UI: a gradient header with the signed-in user, grouped
/// destinations with active highlighting, and sign-out pinned to the bottom.
class SideMenuPanel extends ConsumerStatefulWidget {
  const SideMenuPanel({
    super.key,
    required this.role,
    required this.userName,
    required this.userEmail,
    this.showCloseButton = false,
  });

  final String role;
  final String userName;
  final String userEmail;
  final bool showCloseButton;

  @override
  ConsumerState<SideMenuPanel> createState() => _SideMenuPanelState();
}

class _SideMenuPanelState extends ConsumerState<SideMenuPanel> {
  final Set<String> _expandedRoutes = <String>{};
  bool _isSigningOut = false;

  List<SideMenuGroup> get _groups {
    switch (widget.role) {
      case AppConstants.roleAdmin:
        return kAdminMenu;
      case AppConstants.roleTeacher:
        return kTeacherMenu;
      case AppConstants.roleParent:
        return kParentMenu;
      case AppConstants.roleDriver:
        return kDriverMenu;
      default:
        return const <SideMenuGroup>[];
    }
  }

  String get _roleLabel {
    switch (widget.role) {
      case AppConstants.roleAdmin:
        return 'Administrator';
      case AppConstants.roleTeacher:
        return 'Teacher';
      case AppConstants.roleParent:
        return 'Parent';
      case AppConstants.roleDriver:
        return 'Driver';
      default:
        return 'Member';
    }
  }

  String get _initials {
    final parts = widget.userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Resolves the current route without assuming a GoRouter is above the
  /// context, so the menu can also be rendered in previews or widget tests.
  String? _currentLocation(BuildContext context) {
    return Router.maybeOf(context)?.routeInformationProvider?.value.uri.path;
  }

  bool _isActive(BuildContext context, String route) {
    final location = _currentLocation(context);
    if (location == null) return false;
    return location == route || location.startsWith('$route/');
  }

  /// A parent stays open when it was tapped or when a child is the current page.
  bool _isExpanded(BuildContext context, SideMenuEntry entry) {
    if (_expandedRoutes.contains(entry.route)) return true;
    return entry.children.any((child) => _isActive(context, child.route));
  }

  void _handleTap(SideMenuEntry entry) {
    if (entry.children.isNotEmpty && !_expandedRoutes.contains(entry.route)) {
      setState(() => _expandedRoutes.add(entry.route));
    }
    _navigate(entry.route);
  }

  /// Closes the drawer when the menu is showing inside one, then routes.
  void _navigate(String route) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
    }
    context.go(route);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.logout_rounded, color: AppColors.schoolRed),
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to open your dashboard.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.schoolRed),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSigningOut = true);
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.cardBackground, AppColors.background],
        ),
        border: Border(
          right: BorderSide(color: AppColors.divider.withValues(alpha: 0.7)),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        child: Column(
          children: <Widget>[
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                children: _buildGroupList(context),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: SchoolBrand(compact: true, light: true),
                  ),
                  if (widget.showCloseButton)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                      tooltip: 'Close menu',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  _buildAvatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.userEmail.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            widget.userEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildRoleChip(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.40),
          width: 1.5,
        ),
      ),
      child: Text(
        _initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRoleChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.verified_user_rounded,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            _roleLabel.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupList(BuildContext context) {
    final widgets = <Widget>[];
    for (final group in _groups) {
      widgets.add(_buildSectionLabel(group.section));
      for (final entry in group.entries) {
        widgets.add(_buildTile(context, entry));
        if (entry.children.isNotEmpty && _isExpanded(context, entry)) {
          for (final child in entry.children) {
            widgets.add(_buildTile(context, child, depth: 1));
          }
        }
      }
      widgets.add(const SizedBox(height: 6));
    }
    return widgets;
  }

  Widget _buildSectionLabel(SideMenuSection section) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Row(
        children: <Widget>[
          Icon(section.icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              section.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    SideMenuEntry entry, {
    int depth = 0,
  }) {
    final active = _isActive(context, entry.route);
    final hasChildren = entry.children.isNotEmpty;
    final expanded = hasChildren && _isExpanded(context, entry);
    final radius = BorderRadius.circular(12);

    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, bottom: 2),
      child: Material(
        color: active
            ? AppColors.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => _handleTap(entry),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: depth == 0 ? 11 : 9,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  entry.icon,
                  size: depth == 0 ? 20 : 17,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: depth == 0 ? 13.5 : 12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (hasChildren)
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(color: AppColors.divider.withValues(alpha: 0.8)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: _isSigningOut ? null : _confirmSignOut,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.schoolRed.withValues(alpha: 0.10),
              foregroundColor: AppColors.schoolRed,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isSigningOut
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded, size: 18),
            label: Text(_isSigningOut ? 'Signing out...' : AppStrings.logout),
          ),
        ),
      ),
    );
  }
}
