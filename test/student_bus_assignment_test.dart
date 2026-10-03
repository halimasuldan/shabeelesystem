import 'package:flutter_test/flutter_test.dart';

import 'package:shabelle_system/core/utils/driver_assignment_utils.dart';
import 'package:shabelle_system/models/driver_model.dart';
import 'package:shabelle_system/models/student_model.dart';
import 'package:shabelle_system/screens/admin/linking/student_bus_assignment_screen.dart';

void main() {
  StudentModel student(String id, {String? busId, String? name}) =>
      StudentModel(
        id: id,
        studentCode: 'CODE-$id',
        fullName: name ?? 'Student $id',
        gender: 'F',
        classId: 'class-1',
        className: 'Grade 1',
        parentIds: const [],
        busId: busId,
        address: 'Some address',
        emergencyContactName: 'Next of kin',
        emergencyContactPhone: '0700000000',
        status: 'active',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  group('studentsVisibleForAssignment', () {
    test('shows every student, including unassigned ones, when no bus is '
        'selected', () {
      final students = [student('a'), student('b', busId: 'bus-1')];

      final visible = studentsVisibleForAssignment(students, null);

      expect(visible.map((s) => s.id), ['a', 'b']);
    });

    test(
      'keeps unassigned students and students from other buses selectable',
      () {
        final students = [
          student('a'),
          student('b', busId: 'bus-1'),
          student('c', busId: 'bus-2'),
        ];

        final visible = studentsVisibleForAssignment(students, 'bus-1');

        expect(visible.map((s) => s.id), ['a', 'c']);
      },
    );

    test('hides students already riding the selected bus', () {
      final students = [student('b', busId: 'bus-1')];

      final visible = studentsVisibleForAssignment(students, 'bus-1');

      expect(visible, isEmpty);
    });
  });

  group('studentsAssignedToBus', () {
    test('returns the selected bus roster without other bus students', () {
      final students = [
        student('here', busId: 'bus-1'),
        student('there', busId: 'bus-2'),
        student('unassigned'),
      ];

      final assigned = studentsAssignedToBus(students, 'bus-1');

      expect(assigned.map((entry) => entry.id), ['here']);
      expect(
        studentsVisibleForAssignment(
          students,
          'bus-1',
        ).map((entry) => entry.id),
        ['there', 'unassigned'],
      );
    });

    test('returns no assigned roster before a bus is selected', () {
      final assigned = studentsAssignedToBus([
        student('a', busId: 'bus-1'),
      ], null);

      expect(assigned, isEmpty);
      expect(
        () => assigned.sort((a, b) => a.id.compareTo(b.id)),
        returnsNormally,
      );
    });

    test(
      'assignment lists can be copied and sorted when source is immutable',
      () {
        final source = List<StudentModel>.unmodifiable([
          student('z', busId: 'bus-1', name: 'Zed'),
          student('a', busId: 'bus-1', name: 'Amina'),
        ]);
        final roster = List<StudentModel>.of(
          studentsAssignedToBus(source, 'bus-1'),
        )..sort((a, b) => a.fullName.compareTo(b.fullName));

        expect(roster.map((entry) => entry.id), ['a', 'z']);
      },
    );
  });

  group('busMovesToClear', () {
    test('maps each moved student to the bus they are leaving', () {
      final students = [
        student('a', busId: 'bus-old'),
        student('b', busId: 'bus-old-2'),
      ];

      final moves = busMovesToClear(students, ['a', 'b'], 'bus-new');

      expect(moves, {'a': 'bus-old', 'b': 'bus-old-2'});
    });

    test('ignores unassigned students, unselected students and students '
        'already on the target bus', () {
      final students = [
        student('unassigned'),
        student('stays', busId: 'bus-1'),
        student('unselected', busId: 'bus-other'),
      ];

      final moves = busMovesToClear(students, ['unassigned', 'stays'], 'bus-1');

      expect(moves, isEmpty);
    });

    test('returns nothing when no bus is selected', () {
      final students = [student('a', busId: 'bus-old')];

      final moves = busMovesToClear(students, ['a'], null);

      expect(moves, isEmpty);
    });
  });

  group('busLabelForStudent', () {
    test('reports unassigned students and resolves known bus labels', () {
      const labels = {'bus-1': 'B-01 (ABC-123)'};

      expect(busLabelForStudent(student('a'), labels), 'Not on a bus');
      expect(
        busLabelForStudent(student('b', busId: 'bus-1'), labels),
        'B-01 (ABC-123)',
      );
      expect(
        busLabelForStudent(student('c', busId: 'gone'), labels),
        'Bus: gone',
      );
    });
  });

  group('busIsAssignedToDriver', () {
    const driverIds = {'driver-profile-id', 'driver-auth-uid'};

    test('matches document id, auth uid and legacy current driver links', () {
      expect(
        busIsAssignedToDriver(
          {'driverId': 'driver-profile-id'},
          driverIds: driverIds,
          userId: 'driver-auth-uid',
        ),
        isTrue,
      );
      expect(
        busIsAssignedToDriver(
          {'driverUserId': 'driver-auth-uid'},
          driverIds: driverIds,
          userId: 'driver-auth-uid',
        ),
        isTrue,
      );
      expect(
        busIsAssignedToDriver(
          {'currentDriverId': 'driver-auth-uid'},
          driverIds: driverIds,
          userId: 'driver-auth-uid',
        ),
        isTrue,
      );
    });

    test('does not match another driver assignment', () {
      expect(
        busIsAssignedToDriver(
          {'driverId': 'someone-else', 'driverUserId': 'someone-else'},
          driverIds: driverIds,
          userId: 'driver-auth-uid',
        ),
        isFalse,
      );
    });
  });

  group('DriverModel activation', () {
    test('a driver record without an isActive field counts as active, so the '
        'assignment dropdown can list drivers created outside the app', () {
      final driver = DriverModel(
        id: 'legacy-1',
        userId: '',
        name: 'Legacy Driver',
        email: 'legacy@school.com',
        phone: '0700000000',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(driver.isActive, isTrue);
      expect(driver.assignmentUserId, 'legacy-1');
    });

    test('uses the linked auth user ID when the profile has one', () {
      final driver = DriverModel(
        id: 'legacy-profile-doc',
        userId: 'auth-user-1',
        name: 'Legacy Driver',
        email: 'legacy@school.com',
        phone: '0700000000',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(driver.assignmentUserId, 'auth-user-1');
    });
  });
}
