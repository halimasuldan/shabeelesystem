import '../../models/student_model.dart';

/// Reconciles the student query with the bus document's legacy roster mirror.
///
/// A mirrored student without a `busId` is still included, but stale mirror
/// entries assigned to another bus and inactive students are ignored.
List<StudentModel> resolveDriverRoster({
  required String busId,
  required Iterable<StudentModel> studentsByBusId,
  required Iterable<StudentModel> mirroredStudents,
}) {
  final studentsById = <String, StudentModel>{};
  for (final student in [...studentsByBusId, ...mirroredStudents]) {
    if (student.status != 'active') continue;
    if (student.busId != null &&
        student.busId!.isNotEmpty &&
        student.busId != busId) {
      continue;
    }
    studentsById[student.id] = student;
  }

  final students = studentsById.values.toList()
    ..sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
  return students;
}
