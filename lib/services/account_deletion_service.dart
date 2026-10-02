import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AccountDeletionService {
  static final _db = FirebaseFirestore.instance;

  /// Small helper: wrap any future with a timeout so nothing hangs.
  static Future<T?> _withTimeout<T>(
    Future<T> future,
    String label, {
    int seconds = 15,
  }) async {
    try {
      return await future.timeout(Duration(seconds: seconds));
    } catch (e) {
      debugPrint('[Delete] $label TIMEOUT/ERROR: $e');
      return null;
    }
  }

  /// Deletes the current user's account and all associated data.
  /// Uses pagination to handle any number of docs.
  static Future<String> deleteMyAccount() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception('Not logged in');

    final uid = me.uid;
    debugPrint('[Delete] START $uid');

    // ---- 1) Delete my posts (with subcollections, paginated) ----
    await _deleteAllWithSubcollections(
      label: 'posts',
      query: () => _db.collection('posts')
          .where('userId', isEqualTo: uid).limit(50),
      subcollections: ['likes', 'comments', 'views'],
    );

    // ---- 2) Delete my likes from others' posts (collectionGroup, paginated) ----
    await _deleteAllSimple(
      label: 'my likes',
      query: () => _db.collectionGroup('likes')
          .where('userId', isEqualTo: uid).limit(50),
    );

    // ---- 3) Delete my comments from others' posts ----
    await _deleteAllSimple(
      label: 'my comments',
      query: () => _db.collectionGroup('comments')
          .where('userId', isEqualTo: uid).limit(50),
    );

    // ---- 4) Delete my chats (with messages, paginated) ----
    await _deleteAllWithSubcollections(
      label: 'chats as userA',
      query: () => _db.collection('chats')
          .where('userA', isEqualTo: uid).limit(50),
      subcollections: ['messages'],
    );
    await _deleteAllWithSubcollections(
      label: 'chats as userB',
      query: () => _db.collection('chats')
          .where('userB', isEqualTo: uid).limit(50),
      subcollections: ['messages'],
    );

    // ---- 5) Delete my partnerships ----
    await _deleteAllSimple(
      label: 'partnerships as userA',
      query: () => _db.collection('partnerships')
          .where('userA', isEqualTo: uid).limit(50),
    );
    await _deleteAllSimple(
      label: 'partnerships as userB',
      query: () => _db.collection('partnerships')
          .where('userB', isEqualTo: uid).limit(50),
    );

    // ---- 6) Delete partnership requests ----
    await _deleteAllSimple(
      label: 'requests as userA',
      query: () => _db.collection('partnershipRequests')
          .where('userA', isEqualTo: uid).limit(50),
    );
    await _deleteAllSimple(
      label: 'requests as userB',
      query: () => _db.collection('partnershipRequests')
          .where('userB', isEqualTo: uid).limit(50),
    );

    // ---- 7) Delete my user subcollections (paginated) ----
    final userRef = _db.collection('users').doc(uid);
    for (final sub in [
      'notifications',
      'activityLikes',
      'activityComments',
      'blockedUsers',
      'blockedBy',
    ]) {
      await _deleteSubcollectionPaginated(userRef, sub);
    }

    // ---- 8) Delete user doc ----
    try {
      await _withTimeout(
        _db.collection('users').doc(uid).delete(),
        'user doc delete',
      );
      debugPrint('[Delete] user doc deleted');
    } catch (e) {
      debugPrint('[Delete] user doc error: $e');
    }

    // ---- 9) Delete Firebase Auth account ----
    debugPrint('[Delete] deleting auth account');
    try {
      await me.delete().timeout(const Duration(seconds: 10));
      debugPrint('[Delete] auth account deleted');
    } on FirebaseAuthException catch (e) {
      debugPrint('[Delete] Auth error: ${e.code}');
      if (e.code == 'requires-recent-login') {
        try { await FirebaseAuth.instance.signOut(); } catch (_) {}
        throw Exception(
          'For security, please logout and login again, then try deleting.');
      }
      try { await FirebaseAuth.instance.signOut(); } catch (_) {}
      throw Exception('Auth deletion failed: ${e.message}');
    } catch (e) {
      debugPrint('[Delete] Auth error: $e');
      try { await FirebaseAuth.instance.signOut(); } catch (_) {}
      throw Exception('Could not delete account. Please try again.');
    }

    // ---- 10) Force sign out ----
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}

    debugPrint('[Delete] DONE');
    return 'Account deleted';
  }

  // ============================================================
  // Paginated deleter — keeps fetching until no docs remain
  // ============================================================
  static Future<void> _deleteAllSimple({
    required String label,
    required Query Function() query,
  }) async {
    int total = 0;
    while (true) {
      try {
        final snap = await _withTimeout(query().get(), '$label fetch');
        if (snap == null || snap.docs.isEmpty) break;

        for (final doc in snap.docs) {
          await _withTimeout(doc.reference.delete(), '$label delete');
        }
        total += snap.docs.length;
        debugPrint('[Delete] $label: deleted ${snap.docs.length} (total $total)');

        // If fewer than 50 returned, we're done
        if (snap.docs.length < 50) break;
      } catch (e) {
        debugPrint('[Delete] $label loop error: $e');
        break;
      }
    }
    debugPrint('[Delete] $label FINAL total: $total');
  }

  static Future<void> _deleteAllWithSubcollections({
    required String label,
    required Query Function() query,
    required List<String> subcollections,
  }) async {
    int total = 0;
    while (true) {
      try {
        final snap = await _withTimeout(query().get(), '$label fetch');
        if (snap == null || snap.docs.isEmpty) break;

        for (final doc in snap.docs) {
          // Delete each subcollection first
          for (final sub in subcollections) {
            await _deleteSubcollectionPaginated(doc.reference, sub);
          }
          await _withTimeout(doc.reference.delete(), '$label delete');
        }
        total += snap.docs.length;
        debugPrint('[Delete] $label: deleted ${snap.docs.length} (total $total)');

        if (snap.docs.length < 50) break;
      } catch (e) {
        debugPrint('[Delete] $label loop error: $e');
        break;
      }
    }
    debugPrint('[Delete] $label FINAL total: $total');
  }

  /// Deletes every document inside a subcollection, paginated.
  static Future<void> _deleteSubcollectionPaginated(
    DocumentReference parent,
    String subcollection,
  ) async {
    int total = 0;
    while (true) {
      try {
        final snap = await _withTimeout(
          parent.collection(subcollection).limit(50).get(),
          '$subcollection fetch',
          seconds: 10,
        );
        if (snap == null || snap.docs.isEmpty) break;

        for (final doc in snap.docs) {
          await _withTimeout(
            doc.reference.delete(),
            '$subcollection delete',
            seconds: 5,
          );
        }
        total += snap.docs.length;
        if (snap.docs.length < 50) break;
      } catch (e) {
        debugPrint('[Delete] $subcollection error: $e');
        break;
      }
    }
    if (total > 0) {
      debugPrint('[Delete]   $subcollection: removed $total docs');
    }
  }
}
