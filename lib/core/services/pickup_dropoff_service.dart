import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/pickup_dropoff_model.dart';
import '../constants/app_constants.dart';
import '../utils/date_utils.dart';
import 'notification_service.dart';

/// Records bus pickup / drop-off events and tells the child's parents.
///
/// Before this service existed the driver portal only overwrote
/// `students/{id}.pickupStatus`. That told a parent *what* the current state
/// was but never *when* it changed and kept no history, so there was nothing
/// for the parent app to show. Every driver status change now also appends a
/// timestamped document to `pickup_dropoff`, which the parent screens read as
/// a timeline.
class PickupDropoffService {
  PickupDropoffService._();

  static final PickupDropoffService instance = PickupDropoffService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// The `students` field that mirrors the latest state for [eventType].
  static String statusFieldFor(String eventType) =>
      eventType == PickupDropoffModel.eventDropoff
      ? 'dropoffStatus'
      : 'pickupStatus';

  /// The `students` field that mirrors the latest state of [tripType].
  ///
  /// The driver runs the bus twice a day, so the student document keeps one
  /// mirror per run: `pickupStatus` for the morning run (home -> school) and
  /// `dropoffStatus` for the afternoon run (school -> home). Both runs write
  /// through here, so the last event of a run is always what the driver list
  /// and the parent status card show for that run.
  static String statusFieldForTrip(String tripType) =>
      tripType == PickupDropoffModel.tripAfternoon
      ? 'dropoffStatus'
      : 'pickupStatus';

  /// Title used for the parent notification of [eventType].
  ///
  /// When the run is known the title names it, so a parent can tell the
  /// morning trip apart from the afternoon one at a glance in the
  /// notification list.
  static String titleFor(String eventType, {String? tripType}) {
    if (tripType != null) {
      return tripType == PickupDropoffModel.tripAfternoon
          ? 'Afternoon bus update'
          : 'Morning bus update';
    }
    return eventType == PickupDropoffModel.eventDropoff
        ? 'Bus drop-off update'
        : 'Bus pickup update';
  }

  /// Sentence shown to parents, e.g. "Amina was picked up at 07:12 AM." so the
  /// alert itself answers "when?".
  ///
  /// When [tripType] is passed the sentence also says which run it happened
  /// on, e.g. "... at 07:12 AM on the morning run (home → school)."
  static String sentenceFor({
    required String studentName,
    required String status,
    required DateTime at,
    String? tripType,
  }) {
    final name = studentName.trim().isEmpty ? 'Your child' : studentName.trim();
    final sentence =
        '$name was ${PickupDropoffModel.labelFor(status).toLowerCase()} '
        'at ${DateTimeUtils.formatTime(at)}';
    if (tripType == null) return '$sentence.';
    // Lower-case the run label so it reads naturally mid-sentence:
    // "... at 07:12 AM on the morning run (home → school)."
    final run = PickupDropoffModel.longLabelForTrip(tripType);
    final runLower = run[0].toLowerCase() + run.substring(1);
    return '$sentence on the $runLower.';
  }

  /// Resolve the auth uids of every parent linked to [studentId].
  ///
  /// `students.parentIds` holds parent *document* ids, not auth uids, so each
  /// one is looked up in `parents` first. Failures are swallowed and an empty
  /// list returned: the event is still worth recording when a parent profile is
  /// missing, and the lookup may simply be denied by the security rules.
  Future<List<String>> parentUserIdsFor(String studentId) async {
    final userIds = <String>[];
    try {
      final student = await _db
          .collection(AppConstants.colStudents)
          .doc(studentId)
          .get();
      final parentIds = List<String>.from(
        (student.data()?['parentIds'] as List?) ?? const [],
      );
      for (final parentId in parentIds) {
        final parent = await _db
            .collection(AppConstants.colParents)
            .doc(parentId)
            .get();
        final userId = parent.data()?['userId'] as String?;
        if (userId != null && userId.isNotEmpty && !userIds.contains(userId)) {
          userIds.add(userId);
        }
      }
    } catch (e) {
      debugPrint('PickupDropoffService.parentUserIdsFor($studentId): $e');
    }
    return userIds;
  }

  /// Persist one pickup / drop-off event, mirror the latest state onto the
  /// student document, and notify the child's parents.
  ///
  /// The event document and the student mirror are written sequentially rather
  /// than batched: the event is the record of what happened, and has to survive
  /// even when the mirror is rejected by the security rules (which scope
  /// student edits to the status fields of a bus the driver actually drives).
  Future<void> recordEvent({
    required String studentId,
    required String studentName,
    required String status,
    required String eventType,
    required String busId,
    String? tripType,
    String? tripId,
    String? driverId,
    String? note,
  }) async {
    final parentUserIds = await parentUserIdsFor(studentId);
    final at = DateTime.now();
    // A null tripType falls back to the event type (pickup = morning run,
    // drop-off = afternoon run) inside the model, so both this event and the
    // mirror below always agree on which run is being updated.
    final resolvedTripType =
        tripType ??
        (eventType == PickupDropoffModel.eventDropoff
            ? PickupDropoffModel.tripAfternoon
            : PickupDropoffModel.tripMorning);

    await _db
        .collection(AppConstants.colPickupDropoff)
        .add(
          PickupDropoffModel(
            id: '',
            studentId: studentId,
            studentName: studentName,
            busId: busId,
            tripId: tripId,
            status: status,
            eventType: eventType,
            tripType: resolvedTripType,
            timestamp: at,
            note: note,
            driverId: driverId,
            parentUserIds: parentUserIds,
          ).toMap(),
        );

    // Mirror the current state so the driver screen's dropdown and the
    // parent's "current status" card agree with the timeline. The field is
    // keyed by run: `pickupStatus` tracks the morning run, `dropoffStatus`
    // the afternoon run (both are whitelisted in the security rules).
    await _db.collection(AppConstants.colStudents).doc(studentId).update({
      statusFieldForTrip(resolvedTripType): status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _notifyParents(
      parentUserIds: parentUserIds,
      studentId: studentId,
      title: titleFor(eventType, tripType: resolvedTripType),
      message: sentenceFor(
        studentName: studentName,
        status: status,
        at: at,
        tripType: resolvedTripType,
      ),
    );
  }

  /// Best effort: notification delivery must never make a saved status look
  /// like it failed, and [NotificationService.sendNotificationToUsers] already
  /// swallows its own errors.
  Future<void> _notifyParents({
    required List<String> parentUserIds,
    required String studentId,
    required String title,
    required String message,
  }) async {
    if (parentUserIds.isEmpty) return;
    await NotificationService.instance.sendNotificationToUsers(
      userIds: parentUserIds,
      title: title,
      message: message,
      type: 'bus',
      payload: studentId,
    );
  }
}
