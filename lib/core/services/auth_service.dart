import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../../models/user_model.dart';

/// Authentication service handling sign-in, sign-up, and sign-out.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of auth state changes.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Current authenticated Firebase user.
  User? get currentUser => _auth.currentUser;

  /// Sign in with email and password.
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'unknown', message: 'Login failed');
      }

      // Fetch the user's role from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'User record not found. Please contact admin.',
        );
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final role = data['role'] as String? ?? AppConstants.roleParent;
      final rawActive = data['isActive'];
      final isActive = rawActive is bool
          ? rawActive
          : rawActive?.toString() != 'false';

      if (!isActive) {
        await signOut();
        throw FirebaseAuthException(
          code: 'user-disabled',
          message: 'Your account has been deactivated.',
        );
      }

      return UserModel(
        id: user.uid,
        name: data['name'] as String? ?? user.displayName ?? '',
        email: user.email ?? email,
        phone: data['phone'] as String?,
        role: role,
        photoUrl: data['photoUrl'] as String?,
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isActive: isActive,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }
  }

  /// Register a new user with email and password.
  Future<UserModel> registerUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'unknown',
          message: 'Failed to create user.',
        );
      }

      await user.updateDisplayName(name);

      final userModel = UserModel(
        id: user.uid,
        name: name,
        email: email,
        phone: phone,
        role: role,
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(user.uid)
          .set(userModel.toMap());

      // Create role-specific document
      await _createRoleDocument(userModel);

      return userModel;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }
  }

  /// Create role-specific document after registration.
  Future<void> _createRoleDocument(UserModel user) async {
    final Map<String, dynamic> roleData = {
      'userId': user.id,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'createdAt': user.createdAt,
      'isActive': user.isActive,
    };

    String? collection;
    switch (user.role) {
      case AppConstants.roleAdmin:
        // Admin is already in users collection
        return;
      case AppConstants.roleParent:
        collection = AppConstants.colParents;
        roleData['studentIds'] = [];
        roleData['address'] = '';
        break;
      case AppConstants.roleTeacher:
        collection = AppConstants.colTeachers;
        roleData['classIds'] = [];
        roleData['className'] = [];
        break;
      case AppConstants.roleDriver:
        collection = AppConstants.colDrivers;
        roleData['isActive'] = true;
        break;
      default:
        return;
    }

    await FirebaseFirestore.instance
        .collection(collection)
        .doc(user.id)
        .set(roleData);
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Send password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Reauthenticate the signed-in email/password user before changing password.
  Future<void> updateCurrentUserPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No email/password user is currently signed in.',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }
  }

  /// Send email verification.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Reload the current user to refresh token state.
  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
    }
  }
}
