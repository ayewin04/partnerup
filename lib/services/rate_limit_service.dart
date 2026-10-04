import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RateLimitException implements Exception {
  final String message;
  final int? retryAfterSeconds;
  RateLimitException(this.message, {this.retryAfterSeconds});
  @override
  String toString() => message;
}

/// Manages Firestore `rateLimits` counters.
/// Each counter lives at: users/{uid}/rateLimits/{bucket}
/// Shape: { count: int, windowStart: Timestamp }
class RateLimitService {
  static final _db = FirebaseFirestore.instance;

  /// Prepares a counter for the given bucket within a batch.
  /// Returns normally if under the cap; throws RateLimitException otherwise.
  ///
  /// MUST be called BEFORE the actual create write so we can abort early.
  static Future<void> checkAndBump({
    required WriteBatch batch,
    required String bucket,
    required int cap,
    required Duration window,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw RateLimitException('You must be logged in.');
    }

    final ref = _db
        .collection('users').doc(uid)
        .collection('rateLimits').doc(bucket);

    // Read the current counter
    final snap = await ref.get();
    final now = DateTime.now();

    if (!snap.exists) {
      // First action ever — create the counter
      batch.set(ref, {
        'count': 1,
        'windowStart': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = snap.data()!;
    final count = (data['count'] as num?)?.toInt() ?? 0;
    final windowStartTs = data['windowStart'] as Timestamp?;
    final windowStart = windowStartTs?.toDate() ?? now;

    final elapsed = now.difference(windowStart);
    final windowExpired = elapsed >= window;

    if (windowExpired) {
      // Reset the window
      batch.set(ref, {
        'count': 1,
        'windowStart': FieldValue.serverTimestamp(),
      });
      return;
    }

    if (count >= cap) {
      // Compute how many seconds until the window resets
      final remaining = window - elapsed;
      throw RateLimitException(
        'You\'ve reached the limit for this action.',
        retryAfterSeconds: remaining.inSeconds,
      );
    }

    // Under the cap — increment
    batch.update(ref, {
      'count': FieldValue.increment(1),
    });
  }

  /// Read-only check — useful for UI (e.g. showing "3/300 likes today").
  static Future<int> currentCount(String bucket) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    final snap = await _db
        .collection('users').doc(uid)
        .collection('rateLimits').doc(bucket)
        .get();
    return (snap.data()?['count'] as num?)?.toInt() ?? 0;
  }
}
