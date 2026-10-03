import 'package:intl/intl.dart';

/// Utility functions for date formatting and manipulation.
class DateTimeUtils {
  static final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('MMM dd, yyyy hh:mm a');
  static final DateFormat _dayFormat = DateFormat('EEE, MMM dd');

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatTime(DateTime time) => _timeFormat.format(time);
  static String formatDateTime(DateTime dateTime) =>
      _dateTimeFormat.format(dateTime);
  static String formatDay(DateTime date) => _dayFormat.format(date);

  static String formatDateRange(DateTime start, DateTime end) =>
      '${_dateFormat.format(start)} - ${_dateFormat.format(end)}';

  static DateTime get startOfDay =>
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  static DateTime get endOfDay => startOfDay.add(const Duration(days: 1));

  static int get daysInCurrentMonth {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    return lastDay.day;
  }

  static List<DateTime> getLastNDays(int n) {
    final now = DateTime.now();
    return List.generate(n, (i) => now.subtract(Duration(days: i)));
  }

  static List<String> getWeekDays(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (i) {
      final day = startOfWeek.add(Duration(days: i));
      return DateFormat('EEE\ndd').format(day);
    });
  }

  static String formatForFirestore(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  static DateTime parseFromFirestore(String dateStr) =>
      DateFormat('yyyy-MM-dd').parse(dateStr);
}
