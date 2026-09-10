import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
      _restart();
    });
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
