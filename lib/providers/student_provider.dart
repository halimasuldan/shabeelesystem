import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/services/firestore_service.dart';
import '../models/student_model.dart';

/// Provider for the Firestore service.
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Provider for a single student by ID.
final studentProvider = StreamProvider.autoDispose
    .family<StudentModel?, String>((ref, studentId) {
      return FirebaseFirestore.instance
          .collection(AppConstants.colStudents)
          .doc(studentId)
          .snapshots()
          .map((doc) => doc.exists ? StudentModel.fromFirestore(doc) : null);
    });

/// Provider for all active students.
final studentsProvider = StreamProvider.autoDispose<List<StudentModel>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colStudents)
      .where('status', isEqualTo: 'active')
      .orderBy('fullName')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => StudentModel.fromFirestore(doc))
            .toList(),
      );
});

/// Provider for students linked to a parent.
final parentStudentsProvider = StreamProvider.autoDispose
    .family<List<StudentModel>, String>((ref, parentId) {
      return FirebaseFirestore.instance
          .collection(AppConstants.colStudents)
          .where('parentIds', arrayContains: parentId)
          .where('status', isEqualTo: 'active')
          .orderBy('fullName')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => StudentModel.fromFirestore(doc))
                .toList(),
          );
    });

/// Provider for students assigned to a bus.
final busStudentsProvider = StreamProvider.autoDispose
    .family<List<StudentModel>, String>((ref, busId) {
      return FirebaseFirestore.instance
          .collection(AppConstants.colStudents)
          .where('busId', isEqualTo: busId)
          .where('status', isEqualTo: 'active')
          .orderBy('fullName')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => StudentModel.fromFirestore(doc))
                .toList(),
          );
    });

/// Provider for students in a class.
final classStudentsProvider = StreamProvider.autoDispose
    .family<List<StudentModel>, String>((ref, classId) {
      return FirebaseFirestore.instance
          .collection(AppConstants.colStudents)
          .where('classId', isEqualTo: classId)
          .where('status', isEqualTo: 'active')
          .orderBy('fullName')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => StudentModel.fromFirestore(doc))
                .toList(),
          );
    });

/// Provider for the student CRUD controller.
final studentCrudProvider =
    StateNotifierProvider<StudentCrudNotifier, AsyncValue<void>>((ref) {
      return StudentCrudNotifier();
    });

/// Controller for student create/update/delete operations.
class StudentCrudNotifier extends StateNotifier<AsyncValue<void>> {
  StudentCrudNotifier() : super(const AsyncData(null));

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createStudent(StudentModel student) async {
    state = const AsyncLoading();
    try {
      await _saveStudentAndAssignments(student, isCreate: true);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateStudent(StudentModel student) async {
    state = const AsyncLoading();
    try {
      await _saveStudentAndAssignments(student, isCreate: false);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> _saveStudentAndAssignments(
    StudentModel student, {
    required bool isCreate,
  }) async {
    final studentRef = _firestore
        .collection(AppConstants.colStudents)
        .doc(student.id);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(studentRef);
      if (!isCreate && !existing.exists) {
        throw StateError('Student ${student.id} no longer exists.');
      }
      if (isCreate && existing.exists) {
        throw StateError('Student ${student.id} already exists.');
      }

      final previousData = existing.data() ?? const <String, dynamic>{};
      final previousParentIds = List<String>.from(
        previousData['parentIds'] as List? ?? const <String>[],
      ).where((id) => id.isNotEmpty).toSet();
      final nextParentIds = student.parentIds
          .where((id) => id.isNotEmpty)
          .toSet();
      final previousBusId = previousData['busId'] as String?;
      final nextBusId = student.busId;

      final parentIds = {...previousParentIds, ...nextParentIds};
      final parentRefs = <String, DocumentReference<Map<String, dynamic>>>{
        for (final parentId in parentIds)
          parentId: _firestore
              .collection(AppConstants.colParents)
              .doc(parentId),
      };
      final parentSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in parentRefs.entries) {
        parentSnapshots[entry.key] = await transaction.get(entry.value);
      }

      final busIds = <String>{
        if (previousBusId != null && previousBusId.isNotEmpty) previousBusId,
        if (nextBusId != null && nextBusId.isNotEmpty) nextBusId,
      };
      final busRefs = <String, DocumentReference<Map<String, dynamic>>>{
        for (final busId in busIds)
          busId: _firestore.collection(AppConstants.colBuses).doc(busId),
      };
      final busSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in busRefs.entries) {
        busSnapshots[entry.key] = await transaction.get(entry.value);
      }

      if (!isCreate) {
        transaction.update(studentRef, student.toMap());
      } else {
        transaction.set(studentRef, student.toMap());
      }

      for (final parentId in previousParentIds.difference(nextParentIds)) {
        if (parentSnapshots[parentId]?.exists ?? false) {
          transaction.update(parentRefs[parentId]!, {
            'studentIds': FieldValue.arrayRemove([student.id]),
          });
        }
      }
      for (final parentId in nextParentIds) {
        final parentSnapshot = parentSnapshots[parentId];
        if (parentSnapshot == null || !parentSnapshot.exists) {
          throw StateError('Selected parent profile was not found.');
        }
        transaction.update(parentRefs[parentId]!, {
          'studentIds': FieldValue.arrayUnion([student.id]),
        });
      }

      if (previousBusId != null &&
          previousBusId.isNotEmpty &&
          previousBusId != nextBusId &&
          (busSnapshots[previousBusId]?.exists ?? false)) {
        transaction.update(busRefs[previousBusId]!, {
          'studentIds': FieldValue.arrayRemove([student.id]),
        });
      }
      if (nextBusId != null && nextBusId.isNotEmpty) {
        final busSnapshot = busSnapshots[nextBusId];
        if (busSnapshot == null || !busSnapshot.exists) {
          throw StateError('Selected bus was not found.');
        }
        transaction.update(busRefs[nextBusId]!, {
          'studentIds': FieldValue.arrayUnion([student.id]),
        });
      }
    });
  }

  Future<void> deleteStudent(String studentId) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colStudents)
          .doc(studentId)
          .update({'status': 'inactive'});
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Search students by name, student code, or class.
  Future<List<StudentModel>> searchStudents(String query) async {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();

    // Search by full name
    final snapshot = await _firestore
        .collection(AppConstants.colStudents)
        .where(
          'fullName',
          isGreaterThanOrEqualTo: lowerQuery,
          isLessThan: '${lowerQuery}zzzz',
        )
        .limit(AppConstants.itemsPerPage)
        .get();

    return snapshot.docs.map((doc) => StudentModel.fromFirestore(doc)).toList();
  }
}
