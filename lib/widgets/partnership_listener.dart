import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/splash_screen.dart';
import 'partnership_popup.dart';

class PartnershipListener extends StatefulWidget {
  final Widget child;
  const PartnershipListener({super.key, required this.child});

  @override
  State<PartnershipListener> createState() => _PartnershipListenerState();
}

class _PartnershipListenerState extends State<PartnershipListener> {
  String? _activeRequestId;
  StreamSubscription<QuerySnapshot>? _subA;
  StreamSubscription<QuerySnapshot>? _subB;
  StreamSubscription<User?>? _authSub;
  Timer? _nullDebounce;
  String? _uid;

  List<QueryDocumentSnapshot> _docsA = [];
  List<QueryDocumentSnapshot> _docsB = [];

  StreamSubscription<DocumentSnapshot>? _userDocSub;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
      _restart();
      _watchUserDoc(user?.uid);
    });
  }

  /// Watch the current user's doc. If it disappears (account deleted),
  /// or isBanned is true → force logout.
  void _watchUserDoc(String? uid) {
    _userDocSub?.cancel();
    _userDocSub = null;
    if (uid == null) return;

    _userDocSub = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      // Doc missing → account was deleted
      if (!snap.exists) {
        debugPrint('[AuthGuard] user doc missing → logout');
        _forceLogout('Your account has been deleted.');
        return;
      }

      // Check banned flag
      final data = snap.data() as Map<String, dynamic>?;
      if (data?['isBanned'] == true) {
        debugPrint('[AuthGuard] user banned → logout');
        _forceLogout('Your account has been banned.');
      }
    }, onError: (e) {
      debugPrint('[AuthGuard] userDoc error: $e');
    });
  }

  Future<void> _forceLogout(String message) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  void _restart() {
    _subA?.cancel();
    _subB?.cancel();
    _nullDebounce?.cancel();
    _subA = null;
    _subB = null;
    _docsA = [];
    _docsB = [];
    _activeRequestId = null;

    final uid = _uid;
    if (uid == null) return;

    _subA = FirebaseFirestore.instance
        .collection('partnershipRequests')
        .where('userA', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      _docsA = snap.docs;
      _recompute();
    }, onError: (e) => debugPrint('[PL-A] ERROR: $e'));

    _subB = FirebaseFirestore.instance
        .collection('partnershipRequests')
        .where('userB', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      _docsB = snap.docs;
      _recompute();
    }, onError: (e) => debugPrint('[PL-B] ERROR: $e'));
  }

  void _recompute() {
    String? foundId;
    for (final doc in _docsA) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'pending') {
        foundId = doc.id;
        break;
      }
    }
    if (foundId == null) {
      for (final doc in _docsB) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] == 'pending') {
          foundId = doc.id;
          break;
        }
      }
    }

    _nullDebounce?.cancel();
    if (foundId != null) {
      _setActive(foundId);
    } else {
      _nullDebounce = Timer(const Duration(milliseconds: 800), () {
        if (mounted) _setActive(null);
      });
    }
  }

  void _setActive(String? id) {
    if (_activeRequestId == id) return;
    if (mounted) setState(() => _activeRequestId = id);
  }

  @override
  void dispose() {
    _subA?.cancel();
    _subB?.cancel();
    _authSub?.cancel();
    _nullDebounce?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_activeRequestId != null)
          Positioned.fill(
            child: PartnershipPopup(
              key: ValueKey(_activeRequestId),
              requestId: _activeRequestId!,
              onDismiss: () => _setActive(null),
            ),
          ),
      ],
    );
  }
}

