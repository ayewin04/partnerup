import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockService {
  static final _db = FirebaseFirestore.instance;

  /// Block a user. Adds to my `blockedUsers` list and to their `blockedBy` list.
  static Future<void> blockUser({
    required String blockedUserId,
    required String blockedUsername,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception('Not logged in');
    if (me.uid == blockedUserId) throw Exception('Cannot block yourself');

    // Add to my blocked list
    await _db.collection('users').doc(me.uid)
        .collection('blockedUsers').doc(blockedUserId).set({
      'userId': blockedUserId,
      'username': blockedUsername,
      'blockedAt': FieldValue.serverTimestamp(),
    });

    // Add to their blockedBy list (so their client knows)
    await _db.collection('users').doc(blockedUserId)
        .collection('blockedBy').doc(me.uid).set({
      'userId': me.uid,
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unblock a user. Removes from both sides.
  static Future<void> unblockUser(String blockedUserId) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception('Not logged in');

    await _db.collection('users').doc(me.uid)
        .collection('blockedUsers').doc(blockedUserId).delete();

    await _db.collection('users').doc(blockedUserId)
        .collection('blockedBy').doc(me.uid).delete();
  }

  /// Check if I have blocked this user.
  static Future<bool> haveIBlocked(String otherUserId) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return false;
    final doc = await _db.collection('users').doc(me.uid)
        .collection('blockedUsers').doc(otherUserId).get();
    return doc.exists;
  }

  /// Check if the other user has blocked me.
  static Future<bool> hasBlockedMe(String otherUserId) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return false;
    final doc = await _db.collection('users').doc(otherUserId)
        .collection('blockedBy').doc(me.uid).get();
    return doc.exists;
  }

  /// Live stream: have I blocked this user?
  static Stream<bool> haveIBlockedStream(String otherUserId) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return Stream.value(false);
    return _db.collection('users').doc(me.uid)
        .collection('blockedUsers').doc(otherUserId)
        .snapshots().map((d) => d.exists);
  }
}
