import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// Base Firestore service providing CRUD operations.
/// Other services extend this for collection-specific operations.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generic create document with auto-generated ID.
  Future<DocumentReference> createDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    try {
      final ref = await _firestore.collection(collection).add(data);
      return ref;
    } catch (e) {
      debugPrint('Create document error: $e');
      rethrow;
    }
  }

  /// Create or update a document with a specific ID.
  Future<void> setDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) async {
    try {
      await _firestore
          .collection(collection)
          .doc(docId)
          .set(data, SetOptions(merge: merge));
    } catch (e) {
      debugPrint('Set document error: $e');
      rethrow;
    }
  }

  /// Update an existing document.
  Future<void> updateDocument({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
    } catch (e) {
      debugPrint('Update document error: $e');
      rethrow;
    }
  }

  /// Delete a document.
  Future<void> deleteDocument({
    required String collection,
    required String docId,
  }) async {
    try {
      await _firestore.collection(collection).doc(docId).delete();
    } catch (e) {
      debugPrint('Delete document error: $e');
      rethrow;
    }
  }

  /// Get a single document by ID.
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument({
    required String collection,
    required String docId,
  }) async {
    try {
      return await _firestore.collection(collection).doc(docId).get();
    } catch (e) {
      debugPrint('Get document error: $e');
      rethrow;
    }
  }

  /// Get a collection with optional query parameters.
  Future<QuerySnapshot<Map<String, dynamic>>> getCollection({
    required String collection,
    String? orderBy,
    bool descending = false,
    int? limit,
    String? whereField,
    dynamic whereValue,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(collection);

      if (whereField != null && whereValue != null) {
        query = query.where(whereField, isEqualTo: whereValue);
      }
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }
      if (limit != null) {
        query = query.limit(limit);
      }

      return await query.get();
    } catch (e) {
      debugPrint('Get collection error: $e');
      rethrow;
    }
  }

  /// Stream a single document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDocument({
    required String collection,
    required String docId,
  }) {
    return _firestore.collection(collection).doc(docId).snapshots();
  }

  /// Stream a collection with optional filtering.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection({
    required String collection,
    String? orderBy,
    bool descending = false,
    int? limit,
    String? whereField,
    dynamic whereValue,
    bool isEqualTo = true,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(collection);

    if (whereField != null && whereValue != null) {
      if (isEqualTo) {
        query = query.where(whereField, isEqualTo: whereValue);
      } else {
        query = query.where(whereField, arrayContains: whereValue);
      }
    }
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots();
  }

  /// Search documents with a string query (for search functionality).
  Future<QuerySnapshot<Map<String, dynamic>>> searchDocuments({
    required String collection,
    required String field,
    required String query,
    int limit = AppConstants.itemsPerPage,
  }) async {
    final lowerQuery = query.toLowerCase();
    try {
      return await _firestore
          .collection(collection)
          .where(field, isGreaterThanOrEqualTo: lowerQuery)
          .where(field, isLessThan: '${lowerQuery}zzzz')
          .limit(limit)
          .get();
    } catch (e) {
      debugPrint('Search documents error: $e');
      rethrow;
    }
  }
}
