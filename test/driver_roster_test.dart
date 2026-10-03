import 'package:flutter_test/flutter_test.dart';
import 'package:shabelle_system/core/utils/driver_roster_utils.dart';
import 'package:shabelle_system/models/student_model.dart';

StudentModel student(
  String id, {
  String? busId,
  String status = 'active',
  String? name,
}) => StudentModel(
  id: id,
  studentCode: 'CODE-$id',
  fullName: name ?? 'Student $id',
  gender: 'F',
  classId: 'class-1',
  className: 'Grade 1',
  parentIds: const [],
  busId: busId,
  address: '',
  emergencyContactName: '',
  emergencyContactPhone: '',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('includes legacy bus roster entries without student busId', () {
    final roster = resolveDriverRoster(
      busId: 'bus-1',
      studentsByBusId: [student('current', busId: 'bus-1')],
      mirroredStudents: [student('legacy')],
    );

    expect(roster.map((entry) => entry.id), ['current', 'legacy']);
  });

  test('deduplicates students and ignores stale/inactive mirror entries', () {
    final roster = resolveDriverRoster(
      busId: 'bus-1',
      studentsByBusId: [student('same', busId: 'bus-1')],
      mirroredStudents: [
        student('same', busId: 'bus-1'),
        student('moved', busId: 'bus-2'),
        student('inactive', status: 'inactive'),
      ],
    );

    expect(roster.map((entry) => entry.id), ['same']);
  });
}
