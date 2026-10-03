import 'package:cloud_firestore/cloud_firestore.dart';

/// Pickup and drop-off tracking model.
///
/// One document is appended for every driver status change so a parent can
/// answer "when was my child picked up / dropped off?". The student document
/// only ever holds the *latest* state, so it cannot carry that history.
///
/// A driver runs the bus twice a day, so every event carries both dimensions:
/// * [eventType] - what happened (boarding vs. alighting), and
/// * [tripType] - which run it happened on: [tripMorning] (home -> school) or
///   [tripAfternoon] (school -> home).
class PickupDropoffModel {
  /// Event type written by the driver's Student Pickup screen.
  static const String eventPickup = 'pickup';

  /// Event type written by the driver's Student Drop-off screen.
  static const String eventDropoff = 'dropoff';

  /// Morning run: children are collected at home and delivered to school.
  static const String tripMorning = 'morning';

  /// Afternoon run: children are collected at school and taken home.
  static const String tripAfternoon = 'afternoon';

  final String id;
  final String studentId;
  final String studentName;
  final String busId;
  final String? tripId;

  /// Status the driver selected, e.g. `picked_up`, `on_bus`, `dropped_off`,
  /// `at_school`, `absent`, `waiting`, `pending`.
  final String status;

  /// Which driver screen produced the event ([eventPickup] or
  /// [eventDropoff]).
  final String eventType;

  /// Which of the driver's two daily runs this event belongs to
  /// ([tripMorning] or [tripAfternoon]).
  ///
  /// Older records predate the field; [fromFirestore] falls back to deriving
  /// it from [eventType] so historical events still land on the right run.
  final String tripType;

  final DateTime timestamp;
  final String? note;
  final String? driverId;

  /// Auth uids of the parents linked to the student when the event happened.
  ///
  /// Denormalised on purpose: it lets the Firestore rules grant a parent read
  /// access to their own child's events without exposing the whole
  /// `pickup_dropoff` collection to every signed-in account.
  final List<String> parentUserIds;

  PickupDropoffModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.busId,
    this.tripId,
    required this.status,
    String? eventType,
    String? tripType,
    required this.timestamp,
    this.note,
    this.driverId,
    this.parentUserIds = const <String>[],
  }) : eventType = eventType ?? eventPickup,
       // Default the run from the event type so a caller that only knows
       // "pickup screen / drop-off screen" still writes a valid tripType:
       // pickups happen on the way to school, drop-offs on the way home.
       tripType =
           tripType ??
           ((eventType ?? eventPickup) == eventDropoff
               ? tripAfternoon
               : tripMorning);

  factory PickupDropoffModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final eventType = data['eventType'] as String? ?? eventPickup;
    return PickupDropoffModel(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      busId: data['busId'] as String? ?? '',
      tripId: data['tripId'] as String?,
      status: data['status'] as String? ?? 'waiting',
      eventType: eventType,
      // Events written before the field existed are assigned to the run that
      // matches their event type so the parent timeline stays correct.
      tripType:
          data['tripType'] as String? ??
          (eventType == eventDropoff ? tripAfternoon : tripMorning),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] as String?,
      driverId: data['driverId'] as String?,
      parentUserIds: List<String>.from(
        data['parentUserIds'] as List? ?? const [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'busId': busId,
      'tripId': tripId,
      'status': status,
      'eventType': eventType,
      'tripType': tripType,
      'timestamp': Timestamp.fromDate(timestamp),
      'note': note,
      'driverId': driverId,
      'parentUserIds': parentUserIds,
    };
  }

  /// True when the event describes boarding the bus.
  bool get isPickup => eventType == eventPickup;

  /// True when the event belongs to the morning run (home -> school).
  bool get isMorningTrip => tripType == tripMorning;

  /// The event type a status transition represents.
  ///
  /// Alighting statuses (`at_school` on the morning run, `dropped_off` on the
  /// afternoon run) are drop-offs; everything else (waiting, boarding) is a
  /// pickup. Deriving it means the timeline labels stay correct no matter
  /// which of the two driver screens the status was recorded from.
  static String eventTypeForStatus(String status) =>
      status == 'dropped_off' || status == 'at_school'
      ? eventDropoff
      : eventPickup;

  /// Short run label for the parent timeline / driver UI, e.g. `Home → school`.
  static String labelForTrip(String tripType) =>
      tripType == tripAfternoon ? 'School → home' : 'Home → school';

  /// Full run label used in notifications, e.g.
  /// `Morning run (home → school)`.
  static String longLabelForTrip(String tripType) => tripType == tripAfternoon
      ? 'Afternoon run (school → home)'
      : 'Morning run (home → school)';

  /// Human label for a raw [status] value, used by the parent timeline and the
  /// notification text. A value the UI does not know about falls back to the
  /// raw status so it is still readable.
  static String labelFor(String status) {
    switch (status) {
      case 'waiting':
        return 'Waiting for the bus';
      case 'picked_up':
        return 'Picked up';
      case 'on_bus':
        return 'On the bus';
      case 'dropped_off':
        return 'Dropped off';
      case 'at_school':
        return 'Arrived at school';
      case 'pending':
        return 'Pending';
      case 'absent':
        return 'Absent';
      default:
        return status;
    }
  }
}
