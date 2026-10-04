import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// App-wide theme controller. Listens to Firestore user settings
/// and notifies listeners when dark mode changes.
///
/// Auth-aware: re-subscribes to the new user's doc when the account
/// changes so dark mode follows the current user. Resets to light
/// mode on logout.
class ThemeController extends ChangeNotifier {
  static final ThemeController _instance = ThemeController._internal();
  factory ThemeController() => _instance;
  ThemeController._internal();

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  StreamSubscription<DocumentSnapshot>? _userDocSub;
  StreamSubscription<User?>? _authSub;
  String? _lastUid;

  /// Load from Firestore at startup (before auth state emits).
  Future<void> load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      final settings = doc.data()?['settings'] as Map<String, dynamic>?;
      _isDarkMode = settings?['darkMode'] == true;
      notifyListeners();
    } catch (e) {
      debugPrint('[Theme] load error: $e');
    }
  }

  /// Live listen: re-subscribes on every account change.
  void startListening() {
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _subscribeToUser(user?.uid);
    });
  }

  void _subscribeToUser(String? uid) {
    // Skip if we're already listening to the same user.
    if (uid == _lastUid && _userDocSub != null) return;

    _userDocSub?.cancel();
    _userDocSub = null;
    _lastUid = uid;

    if (uid == null) {
      // Logged out — reset to light mode.
      if (_isDarkMode) {
        _isDarkMode = false;
        notifyListeners();
      }
      return;
    }

    _userDocSub = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .snapshots()
        .listen((snap) {
      final settings = snap.data()?['settings'] as Map<String, dynamic>?;
      final newDark = settings?['darkMode'] == true;
      if (newDark != _isDarkMode) {
        _isDarkMode = newDark;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('[Theme] stream error: $e');
    });
  }

  /// Set dark mode and save to Firestore.
  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(uid).set({
        'settings': {'darkMode': value},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Theme] save error: $e');
    }
  }

  /// Force-clear cached UID so next auth event re-subscribes.
  /// Useful if you ever need to manually trigger a refresh.
  void reset() {
    _userDocSub?.cancel();
    _userDocSub = null;
    _lastUid = null;
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
