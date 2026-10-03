import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/teacher_model.dart';

/// Provider for all teachers.
final teachersProvider = StreamProvider.autoDispose<List<TeacherModel>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colTeachers)
      .where('isActive', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => TeacherModel.fromFirestore(doc))
          .toList());
});

/// Provider for a single teacher by user ID.
final teacherByUserIdProvider =
    StreamProvider.autoDispose.family<TeacherModel?, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colTeachers)
      .where('userId', isEqualTo: userId)
      .limit(1)
      .snapshots()
      .map((snapshot) => snapshot.docs.isNotEmpty
          ? TeacherModel.fromFirestore(snapshot.docs.first)
          : null);
});

/// Provider for the teacher CRUD controller.
final teacherCrudProvider =
    StateNotifierProvider<TeacherCrudNotifier, AsyncValue<void>>((ref) {
  return TeacherCrudNotifier();
});

class TeacherCrudNotifier extends StateNotifier<AsyncValue<void>> {
  TeacherCrudNotifier() : super(const AsyncData(null));

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createTeacher(TeacherModel teacher) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colTeachers)
          .doc(teacher.id)
          .set(teacher.toMap());
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateTeacher(TeacherModel teacher) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colTeachers)
          .doc(teacher.id)
          .update(teacher.toMap());
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deleteTeacher(String teacherId) async {
    state = const AsyncLoading();
    try {
      await _firestore
          .collection(AppConstants.colTeachers)
          .doc(teacherId)
          .update({'isActive': false});
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }
}
