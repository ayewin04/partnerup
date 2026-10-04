import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/partnership_service.dart';
import 'report_sheet.dart';
import 'partnership_sheet.dart';
import '../services/block_service.dart';
import '../services/rate_limiter.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUsername;
  final String? postId;
  final String? postContent;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUsername,
    this.postId,
    this.postContent,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _requesting = false;
  late String _chatId;
  late String _currentUserId;
  bool _isUserA = false;   // set once on init
  late final Stream<QuerySnapshot> _messagesStream;
  bool _firstLoad = true;
  int _lastMessageCount = 0;
  bool _markReadInFlight = false;  // debounce
  DateTime? _lastMarkedRead;
  StreamSubscription<DocumentSnapshot>? _chatDocSub;
  final ValueNotifier<Timestamp?> _otherLastRead = ValueNotifier(null);       // avoid repeat writes

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final ids = [_currentUserId, widget.otherUserId]..sort();
    _chatId = ids.join('_');
    _isUserA = ids.first == _currentUserId;

    // ✅ Create the messages stream ONCE so it isn't recreated
    // every time the outer chat-doc StreamBuilder rebuilds.
    _messagesStream = FirebaseFirestore.instance
        .collection('chats').doc(_chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(50)
        .snapshots();

    // ✅ Auto-mark read when new incoming messages arrive
    _messagesStream.listen((snap) {
      if (!mounted) return;
      final docs = snap.docs;
      if (docs.length <= _lastMessageCount) return;
      _lastMessageCount = docs.length;
      final last = docs.last.data() as Map<String, dynamic>;
      final sender = last['senderId'];
      if (sender != _currentUserId && sender != 'system') {
        _markRead();
      }
    });

    // ✅ Listen to chat doc for the OTHER user's read marker.
    // Uses a plain listener + ValueNotifier — does NOT rebuild the tree.
    _chatDocSub = FirebaseFirestore.instance
        .collection('chats').doc(_chatId)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final otherMarker = _isUserA
          ? (data['lastReadByUserB'] as Timestamp?)
          : (data['lastReadByUserA'] as Timestamp?);
      _otherLastRead.value = otherMarker;
    });

    _ensureChatExists().then((_) => _markRead());
  }

  Future<void> _ensureChatExists() async {
    // ⭐ Single write — no read, so no read-rule crash on non-existent docs.
    //    set(merge:true) creates if missing, patches if present. Idempotent.
    final ref = FirebaseFirestore.instance.collection('chats').doc(_chatId);
    await ref.set({
      'userA': _isUserA ? _currentUserId : widget.otherUserId,
      'userB': _isUserA ? widget.otherUserId : _currentUserId,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': '',
      'unreadForUserA': 0,
      'unreadForUserB': 0,
      'lastReadByUserA': null,
      'lastReadByUserB': null,
      'createdAt': FieldValue.serverTimestamp(),
      'partnershipStatus': 'none',
    }, SetOptions(merge: true));
  }

  /// Debounced mark-read. Only writes if not called in the last 2 seconds.
  Future<void> _markRead() async {
    if (_markReadInFlight) return;
    final now = DateTime.now();
    if (_lastMarkedRead != null &&
        now.difference(_lastMarkedRead!).inSeconds < 5) {
      return; // skip — we just marked
    }
    _markReadInFlight = true;
    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats').doc(_chatId);

      // ✅ Don't write if the counter is already 0 (prevents feedback loop)
      final checkSnap = await chatRef.get();
      final currentUnread = _isUserA
          ? (checkSnap.data()?['unreadForUserA'] ?? 0)
          : (checkSnap.data()?['unreadForUserB'] ?? 0);
      if (currentUnread == 0) return;

      await chatRef.update({
        _isUserA ? 'lastReadByUserA' : 'lastReadByUserB':
            FieldValue.serverTimestamp(),
        _isUserA ? 'unreadForUserA' : 'unreadForUserB': 0,
      });
      _lastMarkedRead = now;
      debugPrint('[Chat] marked read');
    } catch (e) {
      debugPrint('[Chat] mark read error: $e');
    } finally {
      _markReadInFlight = false;
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message too long')));
      return;
    }

    setState(() => _sending = true);
    try {
      // ⭐ Ensure chat doc exists FIRST — inside try so failures are visible.
      await _ensureChatExists();

      // Block check
      try {
        final iBlocked = await BlockService.haveIBlocked(widget.otherUserId);
        final theyBlocked =
            await BlockService.hasBlockedMe(widget.otherUserId);
        if (iBlocked) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('You blocked this user. Unblock to send messages.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (theyBlocked) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You cannot message this user.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('[Chat] block check error: $e');
      }

      await FirebaseFirestore.instance
          .collection('chats').doc(_chatId)
          .collection('messages').add({
        'senderId': _currentUserId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final chatRef = FirebaseFirestore.instance
          .collection('chats').doc(_chatId);

      await chatRef.update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': _currentUserId,
        _isUserA ? 'unreadForUserB' : 'unreadForUserA':
            FieldValue.increment(1),
      });

      _controller.clear();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('[Chat] send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _proposePartnership() async {
    if (_requesting) return;

    // Layer 1: 1 partnership proposal per 2 minutes
    const cooldown = RateLimits.proposePartnership;
    final ok = await RateLimiter.allow(
      action: 'propose_partnership',
      cooldown: cooldown,
    );
    if (!ok) {
      final secs = await RateLimiter.secondsRemaining(
        action: 'propose_partnership',
        cooldown: cooldown,
      );
      if (!mounted) return;
      showRateLimitMessage(
        context,
        action: 'sending a partnership request',
        seconds: secs,
      );
      return;
    }

    final reasonController = TextEditingController();
    if (widget.postContent != null && widget.postContent!.isNotEmpty) {
      reasonController.text = widget.postContent!;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                maxWidth: 500,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Propose Partnership?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            )),
                          const SizedBox(height: 12),
                          Text(
                            'You are about to send a partnership request to '
                            '${widget.otherUsername}.',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'What is this partnership for?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: reasonController,
                            maxLength: 200,
                            maxLines: 3,
                            minLines: 2,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'e.g. Tennis at 6 PM tomorrow',
                              errorText: error,
                              counterText: '',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange[200]!),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                  size: 16, color: Colors.orange),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'If both accept, you enter a binding '
                                    'agreement. This reason will be shown '
                                    'if a report is made.',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final reason =
                                  reasonController.text.trim();
                              if (reason.isEmpty) {
                                setDialogState(() =>
                                  error = 'Please enter a reason');
                                return;
                              }
                              if (reason.length < 3) {
                                setDialogState(() => error =
                                  'Reason must be at least 3 characters');
                                return;
                              }
                              Navigator.pop(ctx, {
                                'reason': reason,
                                'postId': widget.postId ?? '',
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Send Request',
                              style: TextStyle(
                                fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;

    final reason = result['reason'] as String;
    final postId = result['postId'] as String;

    setState(() => _requesting = true);
    try {
      final myDoc = await FirebaseFirestore.instance
          .collection('users').doc(_currentUserId).get();
      final myUsername = myDoc.data()?['username'] ?? 'Unknown';

      await PartnershipService.createRequest(
        otherUserId: widget.otherUserId,
        otherUsername: widget.otherUsername,
        myUsername: myUsername,
        postId: postId.isNotEmpty ? postId : null,
        postContent: reason,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent!'),
          backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _showPartnerships() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PartnershipSheet(
        currentUserId: _currentUserId,
        otherUserId: widget.otherUserId,
        otherUsername: widget.otherUsername,
      ),
    );
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('HH:mm').format(ts.toDate());
  }

  String _dateHeader(Timestamp ts) {
    final d = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(d.year, d.month, d.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d, y').format(d);
  }

  bool _isSameDay(Timestamp? a, Timestamp? b) {
    if (a == null || b == null) return false;
    final da = a.toDate();
    final db = b.toDate();
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _chatDocSub?.cancel();
    _otherLastRead.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        leadingWidth: 40,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Text(
                widget.otherUsername.isNotEmpty
                  ? widget.otherUsername[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Theme.of(context).cardColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherUsername,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: _showPartnerships,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 14,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: PartnershipCountLabel(
                          userA: _currentUserId,
                          userB: widget.otherUserId,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, size: 20),
            tooltip: 'Partnership history',
            onPressed: () => _showPartnerships(),
          ),
          _ReportMenuButton(
            currentUserId: _currentUserId,
            otherUserId: widget.otherUserId,
            otherUsername: widget.otherUsername,
          ),
          if (MediaQuery.of(context).size.width >= 380)
            TextButton.icon(
              onPressed: _requesting ? null : _proposePartnership,
              icon: _requesting
                ? SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).cardColor, strokeWidth: 2))
                : Icon(Icons.handshake,
                    color: Theme.of(context).cardColor, size: 18),
              label: Text('Partnerup',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 11,
                )),
            )
          else
            IconButton(
              tooltip: 'Partnerup',
              onPressed: _requesting ? null : _proposePartnership,
              icon: _requesting
                ? const SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.handshake,
                    color: Colors.white, size: 20),
            ),
        ],
      ),
      body: Column(
        children: [
          // Block status banner
          StreamBuilder<bool>(
            stream: BlockService.haveIBlockedStream(widget.otherUserId),
            builder: (context, snap) {
              if (snap.data != true) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
                color: Colors.red[50],
                child: Row(
                  children: [
                    const Icon(Icons.block,
                      color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You blocked this user. Unblock to send messages.',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final c = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Unblock?'),
                            content: Text(
                              'Unblock @${widget.otherUsername}?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                  Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                  Navigator.pop(ctx, true),
                                child: const Text('Unblock'),
                              ),
                            ],
                          ),
                        );
                        if (c == true) {
                          await BlockService.unblockUser(
                            widget.otherUserId);
                        }
                      },
                      child: const Text('Unblock',
                        style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              );
            },
          ),

          // ---- Messages list (single StreamBuilder, no nesting) ----
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    _firstLoad) {
                  return const Center(
                    child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Start the conversation!',
                      style: TextStyle(color: Colors.grey)));
                }

                final messages = snap.data!.docs;
                _firstLoad = false;

                final otherLastRead = _otherLastRead.value;

                final items = <_ChatItem>[];
                for (int i = 0; i < messages.length; i++) {
                  final m = messages[i].data()
                      as Map<String, dynamic>;
                  final ts = m['timestamp'] as Timestamp?;
                  final senderId = m['senderId'] ?? '';
                  final isSystem = senderId == 'system';

                  if (i == 0 || !_isSameDay(
                      (messages[i - 1].data()
                          as Map<String, dynamic>)['timestamp']
                          as Timestamp?,
                      ts)) {
                    if (ts != null) {
                      items.add(_ChatItem(
                        isDateHeader: true,
                        dateLabel: _dateHeader(ts),
                      ));
                    }
                  }

                  if (isSystem) {
                    final a = m['systemUserA'] ?? 'User';
                    final b = m['systemUserB'] ?? 'User';
                    final aUid = m['systemAUid'];
                    final reason = m['systemReason'] ?? '';
                    final base = aUid == _currentUserId
                        ? 'You confirmed a partnership with $b'
                        : 'You confirmed a partnership with $a';
                    final text = reason.isNotEmpty
                        ? '$base\n📋 $reason'
                        : base;
                    items.add(_ChatItem(
                      isSystem: true,
                      text: text,
                      timestamp: ts,
                    ));
                  } else {
                    final isMyMessage = senderId == _currentUserId;
                    final isRead = isMyMessage &&
                        otherLastRead != null &&
                        ts != null &&
                        !ts.toDate().isAfter(
                            otherLastRead.toDate());
                    items.add(_ChatItem(
                      messageId: messages[i].id,
                      senderId: senderId,
                      text: m['text'] ?? '',
                      timestamp: ts,
                      isRead: isRead,
                    ));
                  }
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _buildItem(items[i]),
                );
              },
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(
                color: Theme.of(context).dividerColor)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 500,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_ChatItem item) {
    if (item.isDateHeader) {
      return _dateHeaderWidget(item.dateLabel!);
    }
    if (item.isSystem) {
      return _systemMessage(item.text);
    }
    final isMe = item.senderId == _currentUserId;
    return _messageBubble(item, isMe);
  }

  Widget _dateHeaderWidget(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _systemMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.handshake, size: 14, color: Colors.blue),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[900],
                    fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageBubble(_ChatItem item, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
          minWidth: 60),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.blue[700]
              : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(item.text,
              softWrap: true,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFE0E0E0)
                        : Colors.black87),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              )),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeAgo(item.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.grey[600]),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    item.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: item.isRead
                        ? Colors.lightBlueAccent
                        : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatItem {
  final bool isDateHeader;
  final bool isSystem;
  final String? dateLabel;
  final String? messageId;
  final String? senderId;
  final String text;
  final Timestamp? timestamp;
  final bool isRead;

  _ChatItem({
    this.isDateHeader = false,
    this.isSystem = false,
    this.dateLabel,
    this.messageId,
    this.senderId,
    this.text = '',
    this.timestamp,
    this.isRead = false,
  });
}

class PartnershipCountLabel extends StatelessWidget {
  final String userA;
  final String userB;

  const PartnershipCountLabel({
    super.key,
    required this.userA,
    required this.userB,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partnerships')
          .where('userA', whereIn: [userA, userB])
          .snapshots(),
      builder: (context, snap) {
        int count = 0;
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final a = d['userA'];
            final b = d['userB'];
            if ((a == userA && b == userB) ||
                (a == userB && b == userA)) {
              count++;
            }
          }
        }
        return Text(
          count == 1 ? '🤝 1 partnership'
              : '🤝 $count partnerships',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white70,
            height: 1,
          ),
        );
      },
    );
  }
}

/// Shows a report icon ONLY if the current user has at least 1 partnership
/// with the other user. Clicking opens the Report Sheet.
class _ReportMenuButton extends StatelessWidget {
  final String currentUserId;
  final String otherUserId;
  final String otherUsername;

  const _ReportMenuButton({
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUsername,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partnerships')
          .where('userA', whereIn: [currentUserId, otherUserId])
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        int partnershipCount = 0;
        for (final doc in snap.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          final a = d['userA'];
          final b = d['userB'];
          if ((a == currentUserId && b == otherUserId) ||
              (a == otherUserId && b == currentUserId)) {
            partnershipCount++;
          }
        }

        if (partnershipCount == 0) {
          return const SizedBox.shrink();
        }

        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) async {
            if (value == 'report') {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ReportSheet(
                  reportedUserId: otherUserId,
                  reportedUsername: otherUsername,
                ),
              );
            } else if (value == 'block') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Block User?'),
                  content: Text(
                    'Block @$otherUsername? They will not be able to '
                    'message you, and you cannot message them.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Block'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;
              try {
                await BlockService.blockUser(
                  blockedUserId: otherUserId,
                  blockedUsername: otherUsername,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('@$otherUsername blocked'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'),
                    backgroundColor: Colors.red),
                );
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.report, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Text('Report User',
                    style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Block User',
                    style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}











