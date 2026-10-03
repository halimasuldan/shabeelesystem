import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../../models/notification_model.dart';

/// Service handling FCM notifications and notification CRUD operations.
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();

  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM and request permissions.
  Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
    );

    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');

    _messaging.onTokenRefresh.listen((token) {
      debugPrint('FCM Token refreshed: $token');
      _saveTokenToServer(token);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM Received: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM Opened: ${message.notification?.title}');
    });
  }

  /// Save FCM token to Firestore for the current user.
  Future<void> _saveTokenToServer(String token) async {
    debugPrint('Saving FCM token to server: $token');
  }

  /// Get the FCM token for the current user.
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Stream of notifications for a user.
  Stream<List<AppNotificationModel>> streamNotifications(String userId) {
    return FirebaseFirestore.instance
        .collection(AppConstants.colNotifications)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotificationModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Create a notification in Firestore.
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? payload,
    String? senderId,
  }) async {
    try {
      final notification = AppNotificationModel(
        id: '',
        userId: userId,
        title: title,
        message: message,
        type: type,
        isRead: false,
        createdAt: DateTime.now(),
        payload: payload,
        senderId: senderId,
      );
      await FirebaseFirestore.instance
          .collection(AppConstants.colNotifications)
          .add(notification.toMap());
    } catch (e) {
      debugPrint('Create notification error: $e');
    }
  }

  /// Notify every parent of every student currently assigned to [busId].
  ///
  /// Used by the driver app when a trip starts/ends so all affected parents
  /// get a notification. Students are linked to a bus via their `busId` field.
  Future<void> notifyBusParents({
    required String busId,
    required String title,
    required String message,
    required String type,
    String? payload,
    String? senderId,
  }) async {
    try {
      final students = await FirebaseFirestore.instance
          .collection(AppConstants.colStudents)
          .where('busId', isEqualTo: busId)
          .get();
      for (final doc in students.docs) {
        await notifyStudentParents(
          studentId: doc.id,
          title: title,
          message: message,
          type: type,
          payload: payload,
          senderId: senderId,
        );
      }
    } catch (e) {
      debugPrint('Notify bus parents error: $e');
    }
  }

  Future<void> notifyStudentParents({
    required String studentId,
    required String title,
    required String message,
    required String type,
    String? payload,
    String? senderId,
  }) async {
    final student = await FirebaseFirestore.instance
        .collection(AppConstants.colStudents)
        .doc(studentId)
        .get();
    final parentIds = List<String>.from(
      (student.data()?['parentIds'] as List?) ?? const [],
    );
    for (final parentId in parentIds) {
      final parent = await FirebaseFirestore.instance
          .collection(AppConstants.colParents)
          .doc(parentId)
          .get();
      final userId = parent.data()?['userId'] as String?;
      if (userId == null || userId.isEmpty) continue;
      await createNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
        payload: payload,
        senderId: senderId,
      );
    }
  }

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.colNotifications)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Mark notification error: $e');
    }
  }

  /// Mark all notifications as read for a user.
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.colNotifications)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Mark all notifications error: $e');
    }
  }

  /// Delete a notification.
  Future<void> deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.colNotifications)
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Delete notification error: $e');
    }
  }

  /// Send a notification to multiple users (admin function).
  Future<void> sendNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String message,
    required String type,
    String? payload,
  }) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();

      for (final userId in userIds) {
        final notification = AppNotificationModel(
          id: '',
          userId: userId,
          title: title,
          message: message,
          type: type,
          isRead: false,
          createdAt: now,
          payload: payload,
          senderId: null,
        );

        batch.set(
          FirebaseFirestore.instance
              .collection(AppConstants.colNotifications)
              .doc(),
          notification.toMap(),
        );
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Send notification error: $e');
    }
  }

  /// Send notification to all parents of a student.
  Future<void> sendToStudentParents({
    required String studentId,
    required String title,
    required String message,
    required String type,
    String? payload,
  }) async {
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection(AppConstants.colStudents)
          .doc(studentId)
          .get();

      if (!studentDoc.exists) return;

      final data = studentDoc.data() as Map<String, dynamic>;
      final parentIds = List<String>.from(data['parentIds'] as List? ?? []);

      // `parentIds` are the parent *document* ids in the `parents`
      // collection - not auth user ids. Resolve each to its `userId` before
      // creating notifications, otherwise nothing is ever delivered.
      final parentUserIds = <String>[];
      for (final parentId in parentIds) {
        final parentDoc = await FirebaseFirestore.instance
            .collection(AppConstants.colParents)
            .doc(parentId)
            .get();
        final userId = parentDoc.data()?['userId'] as String?;
        if (userId != null && userId.isNotEmpty) {
          parentUserIds.add(userId);
        }
      }

      if (parentUserIds.isNotEmpty) {
        await sendNotificationToUsers(
          userIds: parentUserIds,
          title: title,
          message: message,
          type: type,
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('Send to student parents error: $e');
    }
  }
}
