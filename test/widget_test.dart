// Unit tests for core utilities of the Shabelle System app.
//
// These tests exercise pure Dart logic (validators and date formatting) so they
// run without Firebase initialization or platform channels.
import 'package:flutter_test/flutter_test.dart';

import 'package:shabelle_system/core/utils/date_utils.dart';
import 'package:shabelle_system/core/utils/validators.dart';
import 'package:shabelle_system/screens/teacher/results/exam_results_screen.dart';

void main() {
  group('Validators', () {
    test('validateEmail rejects null and empty values', () {
      expect(Validators.validateEmail(null), isNotNull);
      expect(Validators.validateEmail(''), isNotNull);
    });

    test('validateEmail accepts a valid email', () {
      expect(Validators.validateEmail('parent@school.com'), isNull);
    });

    test('validateEmail rejects an invalid email', () {
      expect(Validators.validateEmail('not-an-email'), isNotNull);
    });

    test('validatePassword enforces minimum length of 6', () {
      expect(Validators.validatePassword('12345'), isNotNull);
      expect(Validators.validatePassword('123456'), isNull);
    });

    test('validateRequired trims whitespace before checking', () {
      expect(Validators.validateRequired('   ', 'Name'), isNotNull);
      expect(Validators.validateRequired('Ahmed', 'Name'), isNull);
    });
  });

  group('DateTimeUtils', () {
    test('formatDate renders as MMM dd, yyyy', () {
      expect(
        DateTimeUtils.formatDate(DateTime(2026, 8, 22)),
        'Aug 22, 2026',
      );
    });

    test('formatDay starts with weekday abbreviation', () {
      // Aug 22, 2026 falls on a Saturday.
      expect(DateTimeUtils.formatDay(DateTime(2026, 8, 22)).startsWith('Sat'),
          isTrue);
    });

    test('getLastNDays returns exactly n days starting today', () {
      final days = DateTimeUtils.getLastNDays(7);
      expect(days.length, 7);
      expect(days.first.day, DateTime.now().day);
    });
  });

  group('Exam grading', () {
    test('calculateExamGrade maps score to grade bands', () {
      expect(calculateExamGrade(95), 'A');
      expect(calculateExamGrade(75), 'B');
      expect(calculateExamGrade(65), 'C');
      expect(calculateExamGrade(55), 'D');
      expect(calculateExamGrade(40), 'F');
    });
  });
}
