import 'dart:convert';

class ExamGradebookMark {
  ExamGradebookMark({required this.score, required this.maxMarks});

  num score;
  num maxMarks;
}

class ExamGradebookExam {
  ExamGradebookExam({required this.id, required this.name});

  final String id;
  final String name;
}

class ExamGradebookSubject {
  ExamGradebookSubject({required this.name, required this.resultIds});

  final String name;
  final List<String> resultIds;
  final Map<String, ExamGradebookMark> examMarks = {};

  num get totalScore =>
      examMarks.values.fold<num>(0, (total, mark) => total + mark.score);

  num get totalMaxMarks =>
      examMarks.values.fold<num>(0, (total, mark) => total + mark.maxMarks);
}

class ExamGradebookReport {
  ExamGradebookReport({
    required this.studentName,
    required this.className,
    required this.courseName,
  });

  final String studentName;
  final String className;
  final String courseName;
  final Map<String, ExamGradebookExam> exams = {};
  final Map<String, ExamGradebookSubject> subjects = {};

  num get totalScore => subjects.values.fold<num>(
    0,
    (total, subject) => total + subject.totalScore,
  );

  num get totalMaxMarks => subjects.values.fold<num>(
    0,
    (total, subject) => total + subject.totalMaxMarks,
  );
}

List<ExamGradebookReport> buildExamGradebookReports(
  Iterable<Map<String, dynamic>> results,
) {
  final reports = <String, ExamGradebookReport>{};

  for (final result in results) {
    final examId =
        result['examId']?.toString() ?? result['examName']?.toString() ?? '';
    final studentId =
        result['studentId']?.toString() ??
        result['studentName']?.toString() ??
        '';
    final classId =
        result['classId']?.toString() ?? result['className']?.toString() ?? '';
    final courseId = result['courseId']?.toString() ?? classId;
    final reportKey = jsonEncode([studentId, classId, courseId]);
    final report = reports.putIfAbsent(
      reportKey,
      () => ExamGradebookReport(
        studentName: result['studentName']?.toString() ?? 'Student',
        className: result['className']?.toString() ?? '',
        courseName:
            result['courseName']?.toString() ??
            result['className']?.toString() ??
            '',
      ),
    );

    report.exams.putIfAbsent(
      examId,
      () => ExamGradebookExam(
        id: examId,
        name: result['examName']?.toString() ?? 'Exam',
      ),
    );
    final subjectId =
        result['subjectId']?.toString() ?? result['subject']?.toString() ?? '';
    final subject = report.subjects.putIfAbsent(
      subjectId,
      () => ExamGradebookSubject(
        name: result['subject']?.toString() ?? 'Subject',
        resultIds: [],
      ),
    );
    final mark = subject.examMarks.putIfAbsent(
      examId,
      () => ExamGradebookMark(score: 0, maxMarks: 0),
    );
    mark.score += _asNumber(result['score']);
    mark.maxMarks += _asNumber(result['maxMarks'], fallback: 100);

    final resultId = result['_resultId']?.toString();
    if (resultId != null && resultId.isNotEmpty) {
      subject.resultIds.add(resultId);
    }
  }

  final sortedReports = reports.values.toList()
    ..sort((a, b) => a.studentName.compareTo(b.studentName));
  for (final report in sortedReports) {
    final sortedExams = report.exams.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));
    report.exams
      ..clear()
      ..addEntries(sortedExams);

    final sortedSubjects = report.subjects.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));
    report.subjects
      ..clear()
      ..addEntries(sortedSubjects);
  }
  return sortedReports;
}

num _asNumber(dynamic value, {num fallback = 0}) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? fallback;
}
