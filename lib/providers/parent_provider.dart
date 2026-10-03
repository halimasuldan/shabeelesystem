import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/parent_model.dart';

/// Provider for all parents.
final parentsProvider = StreamProvider.autoDispose<List<ParentModel>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colParents)
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ParentModel.fromFirestore(doc))
          .toList());
});

/// Provider for a single parent by user ID.
final parentByUserIdProvider =
    StreamProvider.autoDispose.family<ParentModel?, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colParents)
      .where('userId', isEqualTo: userId)
      .limit(1)
      .snapshots()
      .map((snapshot) => snapshot.docs.isNotEmpty
          ? ParentModel.fromFirestore(snapshot.docs.first)
          : null);
});

/// Provider for the parent CRUD controller.
final parentCrudProvider =
    StateNotifierProvider<ParentCrudNotifier, AsyncValue<void>>((ref) {
  return ParentCrudNotifier();
});

class ParentCrudNotifier extends StateNotifier<AsyncValue<void>> {
  ParentCrudNotifier() : super(const AsyncData(null));

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createParent(ParentModel parent) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colParents)
          .doc(parent.id)
          .set(parent.toMap());
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateParent(ParentModel parent) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colParents)
          .doc(parent.id)
          .update(parent.toMap());
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deleteParent(String parentId) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colParents)
          .doc(parentId)
          .delete();
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Link a parent to a student.
  Future<void> linkParentToStudent(String parentId, String studentId) async {
    try {
      await _firestore
          .collection(AppConstants.colParents)
          .doc(parentId)
          .update({
        'studentIds': FieldValue.arrayUnion([studentId]),
      });

      await _firestore
          .collection(AppConstants.colStudents)
          .doc(studentId)
          .update({
        'parentIds': FieldValue.arrayUnion([parentId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Unlink a parent from a student.
  Future<void> unlinkParentFromStudent(
      String parentId, String studentId) async {
    try {
      await _firestore
          .collection(AppConstants.colParents)
          .doc(parentId)
          .update({
        'studentIds': FieldValue.arrayRemove([studentId]),
      });

      await _firestore
          .collection(AppConstants.colStudents)
          .doc(studentId)
          .update({
        'parentIds': FieldValue.arrayRemove([parentId]),
      });
    } catch (e) {
      rethrow;
    }
  }
}
