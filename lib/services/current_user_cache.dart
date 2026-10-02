import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Global cache for the current user's profile data.
/// Load once, reuse everywhere. Invalidated on logout.
class CurrentUserCache {
  static String? _username;
  static String? _uid;

  /// Get the current user's username. Reads Firestore only once per session.
  static Future<String> getUsername() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return 'Unknown';

    if (_uid == me.uid && _username != null) {
      return _username!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(me.uid).get();
      _username = doc.data()?['username'] ?? 'Unknown';
      _uid = me.uid;
      debugPrint('[Cache] loaded username: $_username');
      return _username!;
    } catch (e) {
      debugPrint('[Cache] error: $e');
      return 'Unknown';
    }
  }

  /// Manually set (e.g. after signup or username change)
  static void set(String username) {
    _username = username;
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  /// Get synchronously if already loaded.
  static String? get maybeUsername => _username;

  /// Clear on logout.
  static void clear() {
    _username = null;
    _uid = null;
  }
}
