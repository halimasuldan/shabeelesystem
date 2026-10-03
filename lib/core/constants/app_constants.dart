/// Application-wide constants for Shabelle Primary School system.
class AppConstants {
  // App Info
  static const String appName = 'Shabelle Primary School';
  static const String appVersion = '1.0.0';

  // User Roles
  static const String roleAdmin = 'admin';
  static const String roleParent = 'parent';
  static const String roleTeacher = 'teacher';
  static const String roleDriver = 'driver';

  // Attendance Statuses
  static const String attendancePresent = 'present';
  static const String attendanceAbsent = 'absent';
  static const String attendanceLate = 'late';
  static const String attendanceExcused = 'excused';

  // Bus Statuses
  static const String busAvailable = 'available';
  static const String busOnRoute = 'on_route';
  static const String busReturning = 'returning';
  static const String busMaintenance = 'maintenance';
  static const String busOffline = 'offline';

  // Trip Statuses
  static const String tripActive = 'active';
  static const String tripCompleted = 'completed';
  static const String tripCancelled = 'cancelled';

  // Pickup/Dropoff Statuses
  static const String statusWaiting = 'waiting';
  static const String statusPickedUp = 'picked_up';
  static const String statusOnBus = 'on_bus';
  static const String statusDroppedOff = 'dropped_off';
  static const String statusAtSchool = 'at_school';
  static const String statusAbsent = 'absent';

  // Firestore Collection Names
  static const String colUsers = 'users';
  static const String colStudents = 'students';
  static const String colParents = 'parents';
  static const String colTeachers = 'teachers';
  static const String colDrivers = 'drivers';
  static const String colBuses = 'buses';
  static const String colRoutes = 'routes';
  static const String colAttendance = 'attendance';
  static const String colBusLocations = 'bus_locations';
  static const String colBusTrips = 'bus_trips';
  static const String colPickupDropoff = 'pickup_dropoff';
  static const String colNotifications = 'notifications';
  static const String colSchoolInfo = 'school_info';
  static const String colExamDefinitions = 'exam_definitions';
  static const String colExamResults = 'exam_results';
  static const String colClasses = 'classes';
  static const String colSections = 'sections';
  static const String colSubjects = 'subjects';

  // SharedPreferences Keys
  static const String prefUserRole = 'user_role';
  static const String prefUserId = 'user_id';
  static const String prefIsFirstLaunch = 'is_first_launch';

  // Location Update Interval (meters)
  static const double locationDistanceFilter = 10.0;

  // Pagination
  static const int itemsPerPage = 20;

  // Default Values
  static const int defaultBusCapacity = 40;
  static const String defaultProfileImage = 'https://via.placeholder.com/150';
  static const String defaultSchoolName = 'Shabelle Primary School';
  static const String defaultSchoolAddress = 'Addis Ababa, Ethiopia';
  static const String defaultSchoolPhone = '+251 11 123 4567';
  static const String defaultSchoolEmail = 'info@shabelleschool.com';
}
