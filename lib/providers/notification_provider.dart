import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/services/notification_service.dart';
import '../models/notification_model.dart';

/// Provider for notifications for a specific user.
final userNotificationsProvider =
    StreamProvider.autoDispose.family<List<AppNotificationModel>, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colNotifications)
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AppNotificationModel.fromFirestore(doc))
          .toList());
});

/// Provider for unread notification count for a user.
final unreadNotificationCountProvider =
    StreamProvider.autoDispose.family<int, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colNotifications)
      .where('userId', isEqualTo: userId)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

/// Provider for the notification controller.
final notificationControllerProvider =
    StateNotifierProvider<NotificationController, AsyncValue<void>>((ref) {
  return NotificationController(NotificationService.instance);
});

class NotificationController extends StateNotifier<AsyncValue<void>> {
  NotificationController(this._service) : super(const AsyncData(null));

  final NotificationService _service;

  Future<void> markAsRead(String notificationId) async {
    state = const AsyncLoading();
    try {
      await _service.markAsRead(notificationId);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> markAllAsRead(String userId) async {
    state = const AsyncLoading();
    try {
      await _service.markAllAsRead(userId);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    state = const AsyncLoading();
    try {
      await _service.deleteNotification(notificationId);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }
}
