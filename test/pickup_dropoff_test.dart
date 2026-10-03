// Unit tests for the pickup / drop-off event plumbing that lets a parent see
// when a child was picked up and dropped off.
//
// These exercise the pure Dart helpers (labels, notification sentence and the
// Firestore payload shape) so they run without Firebase initialization.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shabelle_system/core/services/pickup_dropoff_service.dart';
import 'package:shabelle_system/models/pickup_dropoff_model.dart';

void main() {
  group('PickupDropoffModel.labelFor', () {
    test('maps the driver status values to parent-facing labels', () {
      expect(PickupDropoffModel.labelFor('waiting'), 'Waiting for the bus');
      expect(PickupDropoffModel.labelFor('picked_up'), 'Picked up');
      expect(PickupDropoffModel.labelFor('on_bus'), 'On the bus');
      expect(PickupDropoffModel.labelFor('dropped_off'), 'Dropped off');
      expect(PickupDropoffModel.labelFor('at_school'), 'Arrived at school');
      expect(PickupDropoffModel.labelFor('absent'), 'Absent');
    });

    test('falls back to the raw status for unknown values', () {
      expect(PickupDropoffModel.labelFor('something_new'), 'something_new');
    });
  });

  group('PickupDropoffService', () {
    test('statusFieldFor targets the matching student field', () {
      expect(
        PickupDropoffService.statusFieldFor(PickupDropoffModel.eventPickup),
        'pickupStatus',
      );
      expect(
        PickupDropoffService.statusFieldFor(PickupDropoffModel.eventDropoff),
        'dropoffStatus',
      );
    });

    test('titleFor distinguishes pickup from drop-off', () {
      expect(
        PickupDropoffService.titleFor(PickupDropoffModel.eventPickup),
        'Bus pickup update',
      );
      expect(
        PickupDropoffService.titleFor(PickupDropoffModel.eventDropoff),
        'Bus drop-off update',
      );
    });

    test('sentenceFor tells the parent when it happened', () {
      final sentence = PickupDropoffService.sentenceFor(
        studentName: 'Amina',
        status: 'picked_up',
        at: DateTime(2026, 8, 22, 7, 12),
      );
      expect(sentence, 'Amina was picked up at 07:12 AM.');
    });

    test('sentenceFor names the child generically when the name is blank', () {
      final sentence = PickupDropoffService.sentenceFor(
        studentName: '   ',
        status: 'dropped_off',
        at: DateTime(2026, 8, 22, 16, 5),
      );
      expect(sentence, 'Your child was dropped off at 04:05 PM.');
    });
  });

  group('PickupDropoffModel payload', () {
    test('toMap carries the fields the parent timeline and rules rely on', () {
      final at = DateTime(2026, 8, 22, 7, 12);
      final map = PickupDropoffModel(
        id: '',
        studentId: 'stu_1',
        studentName: 'Amina',
        busId: 'bus_1',
        status: 'picked_up',
        eventType: PickupDropoffModel.eventDropoff,
        timestamp: at,
        parentUserIds: const ['uid_parent'],
      ).toMap();

      expect(map['studentId'], 'stu_1');
      expect(map['studentName'], 'Amina');
      expect(map['busId'], 'bus_1');
      expect(map['status'], 'picked_up');
      expect(map['eventType'], 'dropoff');
      expect((map['timestamp'] as Timestamp).toDate(), at);
      // The rules grant a parent read access through this list.
      expect(map['parentUserIds'], ['uid_parent']);
    });

    test('isPickup is false for drop-off records', () {
      final event = PickupDropoffModel(
        id: 'pd_1',
        studentId: 'stu_1',
        studentName: 'Amina',
        busId: 'bus_1',
        status: 'dropped_off',
        eventType: PickupDropoffModel.eventDropoff,
        timestamp: DateTime(2026, 8, 22, 16, 5),
      );
      expect(event.isPickup, isFalse);
    });
  });

  group('Two daily runs (tripType)', () {
    test('tripType defaults from the event type', () {
      final morning = PickupDropoffModel(
        id: '',
        studentId: 'stu_1',
        studentName: 'Amina',
        busId: 'bus_1',
        status: 'picked_up',
        eventType: PickupDropoffModel.eventPickup,
        timestamp: DateTime(2026, 8, 22, 7, 12),
      );
      expect(morning.tripType, PickupDropoffModel.tripMorning);
      expect(morning.isMorningTrip, isTrue);

      final afternoon = PickupDropoffModel(
        id: '',
        studentId: 'stu_1',
        studentName: 'Amina',
        busId: 'bus_1',
        status: 'dropped_off',
        eventType: PickupDropoffModel.eventDropoff,
        timestamp: DateTime(2026, 8, 22, 16, 5),
      );
      expect(afternoon.tripType, PickupDropoffModel.tripAfternoon);
      expect(afternoon.isMorningTrip, isFalse);
    });

    test('an explicit tripType wins over the event type', () {
      // The run selector lets the driver record a pickup from *either* run,
      // so the explicit value must not be overwritten by the event type.
      final event = PickupDropoffModel(
        id: '',
        studentId: 'stu_1',
        studentName: 'Amina',
        busId: 'bus_1',
        status: 'picked_up',
        eventType: PickupDropoffModel.eventPickup,
        tripType: PickupDropoffModel.tripAfternoon,
        timestamp: DateTime(2026, 8, 22, 14, 0),
      );
      expect(event.tripType, PickupDropoffModel.tripAfternoon);
    });

    test('toMap carries tripType for the parent timeline', () {
      final map = PickupDropoffModel(
        id: '',
        studentId: 'stu_1',
        studentName: 'Amina',
        busId: 'bus_1',
        status: 'at_school',
        eventType: PickupDropoffModel.eventDropoff,
        tripType: PickupDropoffModel.tripMorning,
        timestamp: DateTime(2026, 8, 22, 7, 55),
      ).toMap();
      expect(map['tripType'], PickupDropoffModel.tripMorning);
    });

    test(
      'eventTypeForStatus labels arrivals as drop-offs and boarding as pickups',
      () {
        expect(
          PickupDropoffModel.eventTypeForStatus('at_school'),
          PickupDropoffModel.eventDropoff,
        );
        expect(
          PickupDropoffModel.eventTypeForStatus('dropped_off'),
          PickupDropoffModel.eventDropoff,
        );
        expect(
          PickupDropoffModel.eventTypeForStatus('picked_up'),
          PickupDropoffModel.eventPickup,
        );
        expect(
          PickupDropoffModel.eventTypeForStatus('on_bus'),
          PickupDropoffModel.eventPickup,
        );
        expect(
          PickupDropoffModel.eventTypeForStatus('waiting'),
          PickupDropoffModel.eventPickup,
        );
      },
    );

    test('run labels name both directions', () {
      expect(
        PickupDropoffModel.labelForTrip(PickupDropoffModel.tripMorning),
        'Home → school',
      );
      expect(
        PickupDropoffModel.labelForTrip(PickupDropoffModel.tripAfternoon),
        'School → home',
      );
      expect(
        PickupDropoffModel.longLabelForTrip(PickupDropoffModel.tripAfternoon),
        'Afternoon run (school → home)',
      );
    });
  });

  group('Run-aware plumbing in PickupDropoffService', () {
    test('statusFieldForTrip keeps one student mirror per run', () {
      expect(
        PickupDropoffService.statusFieldForTrip(PickupDropoffModel.tripMorning),
        'pickupStatus',
      );
      expect(
        PickupDropoffService.statusFieldForTrip(
          PickupDropoffModel.tripAfternoon,
        ),
        'dropoffStatus',
      );
    });

    test('titleFor names the run when it is known', () {
      expect(
        PickupDropoffService.titleFor(
          PickupDropoffModel.eventPickup,
          tripType: PickupDropoffModel.tripMorning,
        ),
        'Morning bus update',
      );
      expect(
        PickupDropoffService.titleFor(
          PickupDropoffModel.eventDropoff,
          tripType: PickupDropoffModel.tripAfternoon,
        ),
        'Afternoon bus update',
      );
      // Without a run the legacy titles are preserved.
      expect(
        PickupDropoffService.titleFor(PickupDropoffModel.eventPickup),
        'Bus pickup update',
      );
    });

    test('sentenceFor says which run it happened on', () {
      final sentence = PickupDropoffService.sentenceFor(
        studentName: 'Amina',
        status: 'picked_up',
        at: DateTime(2026, 8, 22, 7, 12),
        tripType: PickupDropoffModel.tripMorning,
      );
      expect(
        sentence,
        'Amina was picked up at 07:12 AM on the morning run (home → school).',
      );
    });
  });
}
