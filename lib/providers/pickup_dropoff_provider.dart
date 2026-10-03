import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/pickup_dropoff_model.dart';
import 'auth_provider.dart';

/// Pickup / drop-off events for one student, newest first.
///
/// The security rules grant a parent read access only to events whose
/// `parentUserIds` contains their uid. Firestore evaluates `list` rules per
/// candidate document, so the query itself has to be constrained the same way
/// ("rules are not filters"): without the `arrayContains` filter the whole
/// timeline would be rejected as soon as one event for the child predates that
/// field. Events are sorted locally so this read does not require a composite
/// index just to order the timeline.
final studentPickupDropoffProvider = StreamProvider.autoDispose
    .family<List<PickupDropoffModel>, String>((ref, studentId) {
      final uid = ref.watch(authStateProvider).valueOrNull?.uid;
      if (uid == null) return Stream.value(const <PickupDropoffModel>[]);
      return FirebaseFirestore.instance
          .collection(AppConstants.colPickupDropoff)
          .where('studentId', isEqualTo: studentId)
          .where('parentUserIds', arrayContains: uid)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => PickupDropoffModel.fromFirestore(doc))
                    .toList()
                  ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
          );
    });
