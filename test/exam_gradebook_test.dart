import 'package:flutter_test/flutter_test.dart';
import 'package:shabelle_system/core/utils/exam_gradebook_utils.dart';

void main() {
  group('buildExamGradebookReports', () {
    test('puts exams in columns and totals each subject and student', () {
      final reports = buildExamGradebookReports([
        {
          '_resultId': 'math-mid-1',
          'examId': 'midterm',
          'examName': 'Midterm',
          'studentId': 'student-1',
          'studentName': 'Amina',
          'classId': 'class-1',
          'className': 'Grade 1',
          'courseId': 'course-1',
          'courseName': 'Primary Mathematics',
          'subjectId': 'math',
          'subject': 'Math',
          'score': 12,
          'maxMarks': 20,
        },
        {
          '_resultId': 'math-mid-2',
          'examId': 'midterm',
          'examName': 'Midterm',
          'studentId': 'student-1',
          'studentName': 'Amina',
          'classId': 'class-1',
          'className': 'Grade 1',
          'courseId': 'course-1',
          'courseName': 'Primary Mathematics',
          'subjectId': 'math',
          'subject': 'Math',
          'score': 15,
          'maxMarks': 20,
        },
        {
          '_resultId': 'math-final',
          'examId': 'final',
          'examName': 'Final',
          'studentId': 'student-1',
          'studentName': 'Amina',
          'classId': 'class-1',
          'className': 'Grade 1',
          'courseId': 'course-1',
          'courseName': 'Primary Mathematics',
          'subjectId': 'math',
          'subject': 'Math',
          'score': 70,
          'maxMarks': 80,
        },
        {
          '_resultId': 'science-mid',
          'examId': 'midterm',
          'examName': 'Midterm',
          'studentId': 'student-1',
          'studentName': 'Amina',
          'classId': 'class-1',
          'className': 'Grade 1',
          'courseId': 'course-1',
          'courseName': 'Primary Mathematics',
          'subjectId': 'science',
          'subject': 'Science',
          'score': 18,
          'maxMarks': 20,
        },
        {
          '_resultId': 'science-final',
          'examId': 'final',
          'examName': 'Final',
          'studentId': 'student-1',
          'studentName': 'Amina',
          'classId': 'class-1',
          'className': 'Grade 1',
          'courseId': 'course-1',
          'courseName': 'Primary Mathematics',
          'subjectId': 'science',
          'subject': 'Science',
          'score': 60,
          'maxMarks': 80,
        },
      ]);

      final report = reports.single;
      expect(reports, hasLength(1));
      expect(report.exams.keys, ['final', 'midterm']);
      expect(report.subjects['math']?.examMarks['midterm']?.score, 27);
      expect(report.subjects['math']?.examMarks['midterm']?.maxMarks, 40);
      expect(report.subjects['math']?.examMarks['final']?.score, 70);
      expect(report.subjects['math']?.totalScore, 97);
      expect(report.subjects['math']?.totalMaxMarks, 120);
      expect(report.subjects['math']?.resultIds, [
        'math-mid-1',
        'math-mid-2',
        'math-final',
      ]);
      expect(report.subjects['science']?.totalScore, 78);
      expect(report.subjects['science']?.totalMaxMarks, 100);
      expect(report.totalScore, 175);
      expect(report.totalMaxMarks, 220);
      expect(report.studentName, 'Amina');
      expect(report.className, 'Grade 1');
      expect(report.courseName, 'Primary Mathematics');
    });

    test(
      'uses the saved class name for older results without a course name',
      () {
        final reports = buildExamGradebookReports([
          {
            'examId': 'final',
            'examName': 'Final',
            'studentId': 'student-1',
            'studentName': 'Amina',
            'classId': 'class-1',
            'className': 'Grade 1',
            'subjectId': 'math',
            'subject': 'Math',
            'score': 20,
            'maxMarks': 25,
          },
        ]);

        expect(reports.single.courseName, 'Grade 1');
      },
    );

    test('keeps legacy and course-linked exams on the same subject row', () {
      final reports = buildExamGradebookReports([
        {
          'examId': 'midterm',
          'examName': 'Midterm',
          'studentId': 'student-1',
          'studentName': 'Amina',
          'classId': 'class-1',
          'className': 'Grade 1',
          'subjectId': 'math',
          'subject': 'Math',
          'score': 15,
          'maxMarks': 20,
        },
        {
          'examId': 'final',
          'examName': 'Final',
          'studentId': 'student-1',
          'studentName': 'Amina',
          'classId': 'class-1',
          'className': 'Grade 1',
          'courseId': 'class-1',
          'courseName': 'Grade 1',
          'subjectId': 'math',
          'subject': 'Mathematics',
          'score': 70,
          'maxMarks': 80,
        },
      ]);

      expect(reports, hasLength(1));
      expect(reports.single.subjects, hasLength(1));
      expect(
        reports.single.subjects['math']?.examMarks.keys,
        unorderedEquals(['final', 'midterm']),
      );
      expect(reports.single.totalScore, 85);
      expect(reports.single.totalMaxMarks, 100);
    });
  });
}
