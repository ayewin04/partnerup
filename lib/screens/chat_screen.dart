import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/partnership_service.dart';

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

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final ids = [_currentUserId, widget.otherUserId]..sort();
    _chatId = ids.join('_');
    _ensureChatExists().then((_) => _markAllMessagesAsRead());
  }

  Future<void> _ensureChatExists() async {
    final ref = FirebaseFirestore.instance.collection('chats').doc(_chatId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'userA': _currentUserId,
        'userB': widget.otherUserId,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'partnershipStatus': 'none',
      });
    }
  }

  Future<void> _markAllMessagesAsRead() async {
    try {
      final messagesRef = FirebaseFirestore.instance
          .collection('chats').doc(_chatId)
          .collection('messages');
      final all = await messagesRef.limit(200).get();
      final toUpdate = all.docs.where((d) {
        final data = d.data();
        return data['senderId'] != _currentUserId &&
               data['senderId'] != 'system' &&
               data['isRead'] != true;
      }).toList();
      if (toUpdate.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in toUpdate) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[Chat] mark read error: $e');
    }
  }

  Future<void> _markSingleAsRead(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats').doc(_chatId)
          .collection('messages').doc(messageId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Chat] mark single error: $e');
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
      await FirebaseFirestore.instance
          .collection('chats').doc(_chatId)
          .collection('messages').add({
        'senderId': _currentUserId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      await FirebaseFirestore.instance
          .collection('chats').doc(_chatId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
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
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  /// ============ UPDATED: REASON INPUT ============
  Future<void> _proposePartnership() async {
    if (_requesting) return;

    final reasonController = TextEditingController();

    // Pre-fill with post content if it exists
    if (widget.postContent != null && widget.postContent!.isNotEmpty) {
      reasonController.text = widget.postContent!;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
            title: const Text('Propose Partnership?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You are about to send a partnership request to '
                  '${widget.otherUsername}.'),
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
                  minLines: 1,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'e.g. Tennis at 6 PM tomorrow',
                    errorText: error,
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '⚠️ If both accept, you enter a binding agreement. '
                  'This reason will be shown if a report is made.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    setDialogState(() =>
                      error = 'Please enter a reason');
                    return;
                  }
                  if (reason.length < 3) {
                    setDialogState(() =>
                      error = 'Reason must be at least 3 characters');
                    return;
                  }
                  Navigator.pop(ctx, {
                    'reason': reason,
                    'postId': widget.postId ?? '',
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white),
                child: const Text('Send Request'),
              ),
            ],
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
        postContent: reason,     // reuse postContent as "reason"
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue[100],
              child: Text(
                widget.otherUsername.isNotEmpty
                  ? widget.otherUsername[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherUsername,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis),
                  PartnershipCountLabel(
                    userA: _currentUserId,
                    userB: widget.otherUserId,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _requesting ? null : _proposePartnership,
            icon: _requesting
              ? const SizedBox(
                  height: 16, width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.handshake,
                  color: Colors.white, size: 20),
            label: const Text('Partnerup',
              style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats').doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Start the conversation!',
                      style: TextStyle(color: Colors.grey)));
                }

                final messages = snap.data!.docs;

                for (final doc in messages) {
                  final m = doc.data() as Map<String, dynamic>;
                  final sender = m['senderId'];
                  final read = m['isRead'] ?? false;
                  if (sender != _currentUserId &&
                      sender != 'system' &&
                      read != true) {
                    _markSingleAsRead(doc.id);
                  }
                }

                final items = <_ChatItem>[];
                for (int i = 0; i < messages.length; i++) {
                  final m = messages[i].data() as Map<String, dynamic>;
                  final ts = m['timestamp'] as Timestamp?;
                  final senderId = m['senderId'] ?? '';
                  final isSystem = senderId == 'system';

                  if (i == 0 || !_isSameDay(
                      (messages[i - 1].data()
                          as Map<String, dynamic>)['timestamp'] as Timestamp?,
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
                    items.add(_ChatItem(
                      messageId: messages[i].id,
                      senderId: senderId,
                      text: m['text'] ?? '',
                      timestamp: ts,
                      isRead: m['isRead'] ?? false,
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
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
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500)),
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
          maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[700] : Colors.grey[200],
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
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
                fontSize: 15)),
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
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        );
      },
    );
  }
}
