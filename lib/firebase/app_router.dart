import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/auth_service.dart';
import '../core/constants/app_constants.dart';

// Auth screens
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
// Admin screens
import '../screens/admin/dashboard/admin_dashboard.dart';
import '../screens/admin/students/student_management_screen.dart';
import '../screens/admin/students/add_student_screen.dart';
import '../screens/admin/students/edit_student_screen.dart';
import '../screens/admin/parents/parent_management_screen.dart';
import '../screens/admin/teachers/teacher_management_screen.dart';
import '../screens/admin/drivers/driver_management_screen.dart';
import '../screens/admin/drivers/driver_registration_screen.dart';
import '../screens/admin/drivers/pending_verification_screen.dart';
import '../screens/admin/buses/bus_management_screen.dart';
import '../screens/admin/routes/route_management_screen.dart';
import '../screens/admin/linking/parent_student_linking_screen.dart';
import '../screens/admin/linking/student_bus_assignment_screen.dart';
import '../screens/admin/attendance/attendance_overview_screen.dart';
import '../screens/admin/notifications/admin_notifications_screen.dart';
import '../screens/admin/settings/settings_screen.dart';
import '../screens/admin/classes/class_management_screen.dart';
import '../screens/admin/exams/exam_management_screen.dart';
import '../screens/common/exam_result_management_screen.dart';
import '../screens/common/change_password_screen.dart';
import '../screens/admin/subjects/subject_management_screen.dart';
import '../screens/admin/users/user_management_screen.dart';
// Parent screens
import '../screens/parent/dashboard/parent_dashboard.dart';
import '../screens/parent/children/children_list_screen.dart';
import '../screens/parent/children/child_profile_screen.dart';
import '../screens/parent/attendance/child_attendance_screen.dart';
import '../screens/parent/attendance/attendance_history_screen.dart'
    as parent_attendance;
import '../screens/parent/bus/bus_tracking_map_screen.dart';
import '../screens/parent/bus/bus_details_screen.dart' as parent_bus;
import '../screens/parent/notifications/parent_notifications_screen.dart';
import '../screens/parent/children/child_bus_activity_screen.dart';
import '../screens/parent/exams/parent_exam_results_screen.dart';
import '../screens/parent/profile/parent_profile_screen.dart';
// Teacher screens
import '../screens/teacher/dashboard/teacher_dashboard.dart';
import '../screens/teacher/classes/class_students_screen.dart';
import '../screens/teacher/attendance/mark_attendance_screen.dart';
import '../screens/teacher/attendance/attendance_history_screen.dart';
import '../screens/teacher/results/exam_results_screen.dart';
// Driver screens
import '../screens/driver/dashboard/driver_dashboard.dart';
import '../screens/driver/bus/bus_details_screen.dart' as driver_bus;
import '../screens/driver/bus/route_map_screen.dart';
import '../screens/driver/bus/start_trip_screen.dart';
import '../screens/driver/bus/live_tracking_screen.dart';
import '../screens/driver/students/student_pickup_screen.dart';
import '../screens/driver/students/student_dropoff_screen.dart';
import '../screens/driver/trips/trip_history_screen.dart';

/// Global router configuration with role-based routing.
// NOTE: `authServiceProvider` is provided by `lib/providers/auth_provider.dart`.
// Previously this file declared its own local copy, which shadowed the shared
// provider and left the `auth_provider.dart` import unused. Use the shared
// provider (imported in consuming screens) to avoid the duplicate.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) => _roleRedirect(state.matchedLocation),
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/account/password',
        name: 'changePassword',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      // ADMIN
      GoRoute(
        path: '/admin/dashboard',
        name: 'adminDashboard',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/admin/students',
        name: 'adminStudents',
        builder: (context, state) => const StudentManagementScreen(),
      ),
      GoRoute(
        path: '/admin/students/add',
        name: 'addStudent',
        builder: (context, state) => const AddStudentScreen(),
      ),
      GoRoute(
        path: '/admin/students/edit/:id',
        name: 'editStudent',
        builder: (context, state) =>
            EditStudentScreen(studentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/parents',
        name: 'adminParents',
        builder: (context, state) => const ParentManagementScreen(),
      ),
      GoRoute(
        path: '/admin/teachers',
        name: 'adminTeachers',
        builder: (context, state) => const TeacherManagementScreen(),
      ),
      GoRoute(
        path: '/admin/drivers',
        name: 'adminDrivers',
        builder: (context, state) => const DriverManagementScreen(),
      ),
      GoRoute(
        path: '/admin/drivers/register',
        name: 'registerDriver',
        builder: (context, state) => const DriverRegistrationScreen(),
      ),
      GoRoute(
        path: '/admin/drivers/pending',
        name: 'pendingDrivers',
        builder: (context, state) => const PendingVerificationScreen(),
      ),
      GoRoute(
        path: '/admin/buses',
        name: 'adminBuses',
        builder: (context, state) => const BusManagementScreen(),
      ),
      GoRoute(
        path: '/admin/routes',
        name: 'adminRoutes',
        builder: (context, state) => const RouteManagementScreen(),
      ),
      GoRoute(
        path: '/admin/classes',
        name: 'adminClasses',
        builder: (context, state) => const ClassManagementScreen(),
      ),
      GoRoute(
        path: '/admin/subjects',
        name: 'adminSubjects',
        builder: (context, state) => const SubjectManagementScreen(),
      ),
      GoRoute(
        path: '/admin/exams',
        name: 'adminExams',
        builder: (context, state) =>
            const ExamManagementScreen(role: AppConstants.roleAdmin),
      ),
      GoRoute(
        path: '/admin/exam-results',
        name: 'adminExamResults',
        builder: (context, state) =>
            const ExamResultManagementScreen(role: AppConstants.roleAdmin),
      ),
      GoRoute(
        path: '/admin/linking',
        name: 'parentStudentLinking',
        builder: (context, state) => const ParentStudentLinkingScreen(),
      ),
      GoRoute(
        path: '/admin/bus-assignment',
        name: 'studentBusAssignment',
        builder: (context, state) => const StudentBusAssignmentScreen(),
      ),
      GoRoute(
        path: '/admin/attendance',
        name: 'adminAttendance',
        builder: (context, state) => const AttendanceOverviewScreen(),
      ),
      GoRoute(
        path: '/admin/notifications',
        name: 'adminNotifications',
        builder: (context, state) => const AdminNotificationsScreen(),
      ),
      GoRoute(
        path: '/admin/settings',
        name: 'adminSettings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        name: 'adminUsers',
        builder: (context, state) => const UserManagementScreen(),
      ),
      // PARENT
      GoRoute(
        path: '/parent/dashboard',
        name: 'parentDashboard',
        builder: (context, state) => const ParentDashboard(),
      ),
      GoRoute(
        path: '/parent/children',
        name: 'childrenList',
        builder: (context, state) => const ChildrenListScreen(),
      ),
      GoRoute(
        path: '/parent/child/:id',
        name: 'childProfile',
        builder: (context, state) =>
            ChildProfileScreen(studentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/parent/child/attendance/:id',
        name: 'childAttendance',
        builder: (context, state) =>
            ChildAttendanceScreen(studentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/parent/attendance/history',
        name: 'attendanceHistory',
        builder: (context, state) =>
            const parent_attendance.AttendanceHistoryScreen(),
      ),
      GoRoute(
        path: '/parent/exam-results',
        name: 'parentExamResults',
        builder: (context, state) => const ParentExamResultsScreen(),
      ),
      GoRoute(
        path: '/parent/bus/tracking',
        name: 'busTracking',
        builder: (context, state) => const BusTrackingMapScreen(),
      ),
      GoRoute(
        path: '/parent/bus/details',
        name: 'busDetails',
        builder: (context, state) => const parent_bus.BusDetailsScreen(),
      ),
      GoRoute(
        path: '/parent/bus-activity',
        name: 'parentBusActivity',
        // `?child=<studentId>` opens straight on one child; without it the
        // screen shows every linked child.
        builder: (context, state) => ChildBusActivityScreen(
          initialStudentId: state.uri.queryParameters['child'],
        ),
      ),
      GoRoute(
        path: '/parent/notifications',
        name: 'parentNotifications',
        builder: (context, state) => ParentNotificationsScreen(),
      ),
      GoRoute(
        path: '/parent/profile',
        name: 'parentProfile',
        builder: (context, state) => const ParentProfileScreen(),
      ),
      // TEACHER
      GoRoute(
        path: '/teacher/dashboard',
        name: 'teacherDashboard',
        builder: (context, state) => const TeacherDashboard(),
      ),
      GoRoute(
        path: '/teacher/class/:id/students',
        name: 'classStudents',
        builder: (context, state) =>
            ClassStudentsScreen(classId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/teacher/mark-attendance',
        name: 'markAttendance',
        builder: (context, state) => const MarkAttendanceScreen(),
      ),
      GoRoute(
        path: '/teacher/attendance/history',
        name: 'teacherAttendanceHistory',
        builder: (context, state) => const AttendanceHistoryScreen(),
      ),
      GoRoute(
        path: '/teacher/exam-results',
        name: 'examResults',
        builder: (context, state) => const ExamResultsScreen(),
      ),
      GoRoute(
        path: '/teacher/exams',
        name: 'teacherExams',
        builder: (context, state) =>
            const ExamManagementScreen(role: AppConstants.roleTeacher),
      ),
      GoRoute(
        path: '/teacher/exam-results/entered',
        name: 'enteredExamResults',
        builder: (context, state) =>
            const ExamResultManagementScreen(role: AppConstants.roleTeacher),
      ),
      // DRIVER
      GoRoute(
        path: '/driver/dashboard',
        name: 'driverDashboard',
        builder: (context, state) => const DriverDashboard(),
      ),
      GoRoute(
        path: '/driver/bus/details',
        name: 'driverBusDetails',
        builder: (context, state) => const driver_bus.DriverBusDetailsScreen(),
      ),
      GoRoute(
        path: '/driver/route/map',
        name: 'routeMap',
        builder: (context, state) => const RouteMapScreen(),
      ),
      GoRoute(
        path: '/driver/start-trip',
        name: 'startTrip',
        builder: (context, state) => const StartTripScreen(),
      ),
      GoRoute(
        path: '/driver/live-tracking',
        name: 'liveTracking',
        builder: (context, state) => const LiveTrackingScreen(),
      ),
      GoRoute(
        path: '/driver/student/pickup',
        name: 'studentPickup',
        builder: (context, state) => const StudentPickupScreen(),
      ),
      GoRoute(
        path: '/driver/student/dropoff',
        name: 'studentDropoff',
        builder: (context, state) => const StudentDropoffScreen(),
      ),
      GoRoute(
        path: '/driver/trip/history',
        name: 'tripHistory',
        builder: (context, state) => const TripHistoryScreen(),
      ),
    ],
  );
});

Future<String?> _roleRedirect(String location) async {
  if (location == '/' ||
      location == '/login' ||
      location == '/forgot-password') {
    return null;
  }

  final user = AuthService().currentUser;
  if (user == null) return '/login';

  final userDoc = await FirebaseFirestore.instance
      .collection(AppConstants.colUsers)
      .doc(user.uid)
      .get();
  final role = userDoc.data()?['role'] as String?;
  if (role == null) return '/login';

  if (location.startsWith('/admin/') && role != AppConstants.roleAdmin) {
    return getUserRoleRoute(role);
  }
  if (location.startsWith('/parent/') && role != AppConstants.roleParent) {
    return getUserRoleRoute(role);
  }
  if (location.startsWith('/teacher/') && role != AppConstants.roleTeacher) {
    return getUserRoleRoute(role);
  }
  if (location.startsWith('/driver/') && role != AppConstants.roleDriver) {
    return getUserRoleRoute(role);
  }
  return null;
}

/// Determine the user role and return the appropriate dashboard route.
Future<String> getUserRoleRoute(String role) async {
  switch (role) {
    case 'admin':
      return '/admin/dashboard';
    case 'parent':
      return '/parent/dashboard';
    case 'teacher':
      return '/teacher/dashboard';
    case 'driver':
      return '/driver/dashboard';
    default:
      return '/login';
  }
}

/// Initialize FCM on app start.
final fcmInitProvider = Provider<void>((ref) {});
