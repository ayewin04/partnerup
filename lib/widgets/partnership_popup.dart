import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/partnership_request_model.dart';
import '../services/partnership_service.dart';

class PartnershipPopup extends StatefulWidget {
  final String requestId;
  final VoidCallback onDismiss;

  const PartnershipPopup({
    super.key,
    required this.requestId,
    required this.onDismiss,
  });

  @override
  State<PartnershipPopup> createState() => _PartnershipPopupState();
}

class _PartnershipPopupState extends State<PartnershipPopup> {
  Timer? _timer;
  Timer? _successAutoDismiss;
  Duration _remaining = const Duration(minutes: 15);
  bool _processing = false;
  bool _hasShown = false;
  bool _successScheduled = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining - const Duration(seconds: 1);
      });
      if (_remaining.inSeconds <= 0) {
        t.cancel();
        _expire();
      }
    });
  }

  Future<void> _expire() async {
    try {
      await PartnershipService.expireRequest(widget.requestId);
    } catch (_) {}
    if (mounted) widget.onDismiss();
  }

  Future<void> _accept() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await PartnershipService.acceptRequest(widget.requestId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _cancel() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await PartnershipService.cancelRequest(widget.requestId,
        reason: 'cancelled_by_user');
    } catch (_) {}
    if (mounted) widget.onDismiss();
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00';
    return '${_twoDigits(d.inMinutes)}:${_twoDigits(d.inSeconds % 60)}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _successAutoDismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partnershipRequests')
          .doc(widget.requestId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return _loadingOverlay();

        if (!snap.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_hasShown) widget.onDismiss();
          });
          return _loadingOverlay();
        }

        final req = PartnershipRequestModel.fromDoc(snap.data!);
        _hasShown = true;

        // ---- ACCEPTED: show success overlay for 5 seconds ----
        if (req.status == 'accepted') {
          _timer?.cancel();

          // Schedule auto-dismiss once
          if (!_successScheduled) {
            _successScheduled = true;
            debugPrint('[Popup] success shown — auto-dismiss in 5s');
            _successAutoDismiss = Timer(
              const Duration(seconds: 5),
              () {
                debugPrint('[Popup] auto-dismissing success');
                if (mounted) widget.onDismiss();
              },
            );
          }

          final myUid = FirebaseAuth.instance.currentUser!.uid;
          final otherUsername = req.userA == myUid
              ? req.usernameB : req.usernameA;
          return _successOverlay(otherUsername);
        }

        // ---- CANCELLED / EXPIRED: dismiss ----
        if (req.status == 'cancelled' || req.status == 'expired') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _timer?.cancel();
            widget.onDismiss();
          });
          return _loadingOverlay();
        }

        // ---- PENDING: role-based UI ----
        final myUid = FirebaseAuth.instance.currentUser!.uid;
        final isSender = req.userA == myUid;
        final myAccepted = isSender ? req.userAAccepted : req.userBAccepted;
        final otherAccepted = isSender ? req.userBAccepted : req.userAAccepted;
        final otherUsername = isSender ? req.usernameB : req.usernameA;

        return Material(
          color: Colors.black.withValues(alpha: 0.85),
          child: SafeArea(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _buildContent(
                  isSender: isSender,
                  myAccepted: myAccepted,
                  otherAccepted: otherAccepted,
                  otherUsername: otherUsername,
                  req: req,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _loadingOverlay() {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  /// Full-screen success view with 5-second auto-dismiss.
  Widget _successOverlay(String otherUsername) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.celebration,
                  color: Colors.green, size: 80),
                const SizedBox(height: 16),
                const Text('Partnership Confirmed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  'You are now partnered with $otherUsername!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 20),
                // Countdown indicator
                const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Closing in 5 seconds...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      _successAutoDismiss?.cancel();
                      widget.onDismiss();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Great!',
                      style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required bool isSender,
    required bool myAccepted,
    required bool otherAccepted,
    required String otherUsername,
    required PartnershipRequestModel req,
  }) {
    if (isSender && !myAccepted && !otherAccepted) {
      return _waitingForReceiverView(otherUsername, req);
    }
    if (!isSender && !myAccepted && !otherAccepted) {
      return _receiverDecisionView(otherUsername, req);
    }
    if (!isSender && myAccepted && !otherAccepted) {
      return _waitingForSenderView(otherUsername);
    }
    if (isSender && !myAccepted && otherAccepted) {
      return _senderDecisionView(otherUsername);
    }
    return _loadingOverlay();
  }

  Widget _waitingForReceiverView(
      String otherUsername, PartnershipRequestModel req) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.hourglass_top, size: 60, color: Colors.orange),
        const SizedBox(height: 12),
        const Text('PARTNERSHIP REQUEST SENT',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1)),
        const SizedBox(height: 16),
        Text(
          'Waiting for $otherUsername to respond...',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        if (req.postContent.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(req.postContent,
              style: const TextStyle(fontSize: 13)),
          ),
        ],
        const SizedBox(height: 20),
        _timerChip(),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 48,
          child: OutlinedButton(
            onPressed: _processing ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel Request',
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _receiverDecisionView(
      String otherUsername, PartnershipRequestModel req) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.handshake, size: 60, color: Colors.blue),
        const SizedBox(height: 12),
        const Text('PARTNERSHIP REQUEST',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1)),
        const SizedBox(height: 16),
        Text(
          '$otherUsername wants to partner up with you!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        if (req.postContent.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(req.postContent,
              style: const TextStyle(fontSize: 13)),
          ),
        ],
        const SizedBox(height: 20),
        _timerChip(),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _processing ? null : _cancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('DECLINE',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _processing ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _processing
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                    : const Text('ACCEPT',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _waitingForSenderView(String otherUsername) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 60, color: Colors.green),
        const SizedBox(height: 12),
        const Text('YOU ACCEPTED',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: Colors.green)),
        const SizedBox(height: 16),
        Text(
          'Waiting for $otherUsername to confirm...',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 20),
        _timerChip(),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 48,
          child: OutlinedButton(
            onPressed: _processing ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel Request',
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _senderDecisionView(String otherUsername) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 60, color: Colors.green),
        const SizedBox(height: 12),
        Text('$otherUsername ACCEPTED!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: Colors.green)),
        const SizedBox(height: 16),
        const Text(
          'Confirm the partnership to finalize.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 20),
        _timerChip(),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _processing ? null : _cancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('DECLINE',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _processing ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _processing
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                    : const Text('CONFIRM',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _timerChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _remaining.inSeconds < 60
            ? Colors.red[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer,
            color: _remaining.inSeconds < 60
                ? Colors.red : Colors.orange),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_remaining),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _remaining.inSeconds < 60
                  ? Colors.red : Colors.orange[800],
              fontFeatures: const [
                FontFeature.tabularFigures()
              ],
            ),
          ),
        ],
      ),
    );
  }
}
