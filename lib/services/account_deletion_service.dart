import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AccountDeletionService {
  static final _db = FirebaseFirestore.instance;

  static Future<String> deleteMyAccount() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception('Not logged in');

    final uid = me.uid;
    debugPrint('[Delete] START $uid');

    // ---- Delete top-level user data (fast, with timeouts) ----
    await _safeDelete('posts',
      _db.collection('posts').where('userId', isEqualTo: uid));
    await _safeDelete('chatsA',
      _db.collection('chats').where('userA', isEqualTo: uid));
    await _safeDelete('chatsB',
      _db.collection('chats').where('userB', isEqualTo: uid));
    await _safeDelete('partnershipsA',
      _db.collection('partnerships').where('userA', isEqualTo: uid));
    await _safeDelete('partnershipsB',
      _db.collection('partnerships').where('userB', isEqualTo: uid));
    await _safeDelete('requestsA',
      _db.collection('partnershipRequests').where('userA', isEqualTo: uid));
    await _safeDelete('requestsB',
      _db.collection('partnershipRequests').where('userB', isEqualTo: uid));

    // Delete user doc
    try {
      await _db.collection('users').doc(uid).delete()
          .timeout(const Duration(seconds: 5));
      debugPrint('[Delete] user doc deleted');
    } catch (e) {
      debugPrint('[Delete] user doc error: $e');
    }

    // Delete Firebase Auth account
    try {
      await me.delete().timeout(const Duration(seconds: 8));
      debugPrint('[Delete] auth deleted');
    } catch (e) {
      debugPrint('[Delete] auth error: $e');
      try { await FirebaseAuth.instance.signOut(); } catch (_) {}
      // Don't throw — we already deleted the data. Just ensure signout.
    }

    // Force signout anyway
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}

    debugPrint('[Delete] DONE');
    return 'Account deleted';
  }

  static Future<void> _safeDelete(String label, Query query) async {
    try {
      debugPrint('[Delete] $label...');
      final snap = await query.limit(50).get()
          .timeout(const Duration(seconds: 6));
      for (final doc in snap.docs) {
        try {
          await doc.reference.delete()
              .timeout(const Duration(seconds: 4));
        } catch (_) {}
      }
      debugPrint('[Delete] $label done (${snap.docs.length})');
    } catch (e) {
      debugPrint('[Delete] $label ERROR: $e');
    }
  }
}
