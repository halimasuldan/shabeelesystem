import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../core/services/auth_service.dart';
import '../models/user_model.dart';

/// Provider for the authentication service.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Stream provider for authentication state changes.
final authStateProvider = StreamProvider<User?>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.authStateChanges();
});

/// Provider for the current authenticated user.
final currentUserProvider = StateProvider<UserModel?>((ref) {
  return null;
});

/// Provider to track if initialization is complete.
final initCompleteProvider = StateProvider<bool>((ref) => false);

/// Provider that resolves the Firebase role for the current user.
final userRoleProvider = FutureProvider<String>((ref) async {
  final user = ref.watch(authServiceProvider).currentUser;
  if (user == null) return 'guest';
  final doc = await FirebaseFirestore.instance
      .collection(AppConstants.colUsers)
      .doc(user.uid)
      .get();
  if (!doc.exists) return 'guest';
  return doc.data()?['role'] as String? ?? AppConstants.roleParent;
});
