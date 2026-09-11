import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// App-wide theme controller. Listens to Firestore user settings
/// and notifies listeners when dark mode changes.
class ThemeController extends ChangeNotifier {
  static final ThemeController _instance = ThemeController._internal();
  factory ThemeController() => _instance;
  ThemeController._internal();

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  /// Load from Firestore at startup.
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

  /// Live listen to the user doc so changes propagate instantly.
  void startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    FirebaseFirestore.instance
        .collection('users').doc(uid)
        .snapshots()
        .listen((snap) {
      final settings = snap.data()?['settings'] as Map<String, dynamic>?;
      final newDark = settings?['darkMode'] == true;
      if (newDark != _isDarkMode) {
        _isDarkMode = newDark;
        notifyListeners();
      }
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
}
