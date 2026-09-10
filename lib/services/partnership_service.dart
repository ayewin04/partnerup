import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PartnershipService {
  static final _db = FirebaseFirestore.instance;

  static Future<String> createRequest({
    required String otherUserId,
    required String otherUsername,
    required String myUsername,
    String? postId,
    String? postContent,   // in this flow = "reason"
  }) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final expiresAt = DateTime.now().add(const Duration(minutes: 15));

    final ref = await _db.collection('partnershipRequests').add({
      'userA': myUid,
      'userB': otherUserId,
      'usernameA': myUsername,
      'usernameB': otherUsername,
      'postId': postId ?? '',
      'postContent': postContent ?? '',
      'reason': postContent ?? '',   // explicit reason field
      'status': 'pending',
      'userAAccepted': false,
      'userBAccepted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    return ref.id;
  }

  static Future<void> acceptRequest(String requestId) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final ref = _db.collection('partnershipRequests').doc(requestId);

    final snap = await ref.get();
    if (!snap.exists) throw Exception('Request no longer exists');
    final data = snap.data()!;
    if (data['status'] != 'pending') {
      throw Exception('Request is no longer pending');
    }

    final userA = data['userA'] as String;
    final userB = data['userB'] as String;
    final usernameA = data['usernameA'] ?? 'User';
    final usernameB = data['usernameB'] ?? 'User';
    final reason = data['reason'] ?? data['postContent'] ?? '';

    final bool aAcc = data['userAAccepted'] ?? false;
    final bool bAcc = data['userBAccepted'] ?? false;
    final newAAcc = (userA == myUid) ? true : aAcc;
    final newBAcc = (userB == myUid) ? true : bAcc;
    final both = newAAcc && newBAcc;

    await ref.update({
      'userAAccepted': newAAcc,
      'userBAccepted': newBAcc,
      if (both) 'status': 'accepted',
      if (both) 'acceptedAt': FieldValue.serverTimestamp(),
    });

    if (!both) return;

    // Partnership doc
    final pRef = _db.collection('partnerships').doc();
    await pRef.set({
      'userA': userA,
      'userB': userB,
      'usernameA': usernameA,
      'usernameB': usernameB,
      'reason': reason,
      'postId': data['postId'] ?? '',
      'requestId': requestId,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'isReported': false,
    });

    // Counts
    try {
      await _db.collection('users').doc(userA).update({
        'partnershipCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('[Service] userA count error: $e');
    }
    try {
      await _db.collection('users').doc(userB).update({
        'partnershipCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('[Service] userB count error: $e');
    }

    // System chat message
    final ids = [userA, userB]..sort();
    final chatId = ids.join('_');
    try {
      await _db.collection('chats').doc(chatId)
          .collection('messages').add({
        'senderId': 'system',
        'text': 'Partnership confirmed',
        'systemType': 'partnership',
        'systemUserA': usernameA,
        'systemUserB': usernameB,
        'systemAUid': userA,
        'systemBUid': userB,
        'systemReason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': true,
      });
      await _db.collection('chats').doc(chatId).update({
        'lastMessage': '🤝 Partnership confirmed',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Service] system message error: $e');
    }
  }

  static Future<void> cancelRequest(String requestId,
      {String reason = 'cancelled'}) async {
    final ref = _db.collection('partnershipRequests').doc(requestId);
    try {
      final snap = await ref.get();
      if (!snap.exists) return;
      if (snap.data()!['status'] != 'pending') return;
      await ref.update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelReason': reason,
      });
    } catch (e) {
      debugPrint('[Service] cancel error: $e');
    }
  }

  static Future<void> expireRequest(String requestId) async {
    final ref = _db.collection('partnershipRequests').doc(requestId);
    try {
      final snap = await ref.get();
      if (!snap.exists) return;
      if (snap.data()!['status'] != 'pending') return;
      await ref.update({
        'status': 'expired',
        'expiredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Service] expire error: $e');
    }
  }
}
