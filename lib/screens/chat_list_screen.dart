import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  static const int _pageSize = 20;

  // Merged + sorted chat list — one-shot loaded, paginated client-side.
  final List<QueryDocumentSnapshot> _chats = [];
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  // Cursors for real server-side pagination.
  DocumentSnapshot? _lastDocA;
  DocumentSnapshot? _lastDocB;
  bool _hasMoreA = true;
  bool _hasMoreB = true;

  /// Fetches chats where I'm userA and userB separately.
  /// No orderBy + where combo → zero composite indexes needed.
  /// First page: 30 + 30. Each "Load More": 30 + 30 via startAfterDocument.
  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _chats.clear();
        _lastDocA = null;
        _lastDocB = null;
        _hasMoreA = true;
        _hasMoreB = true;
      });
    } else {
      if (_loadingMore) return;
      if (!_hasMoreA && !_hasMoreB) return;   // nothing left on either side
      setState(() => _loadingMore = true);
    }

    try {
      final db = FirebaseFirestore.instance;

      // Build both queries — first page or next page per side.
      Query qA = db
          .collection('chats')
          .where('userA', isEqualTo: _currentUserId)
          .limit(_pageSize);
      Query qB = db
          .collection('chats')
          .where('userB', isEqualTo: _currentUserId)
          .limit(_pageSize);

      if (!reset) {
        if (_hasMoreA && _lastDocA != null) {
          qA = qA.startAfterDocument(_lastDocA!);
        } else {
          qA = qA.limit(0);   // exhausted — fetch nothing
        }
        if (_hasMoreB && _lastDocB != null) {
          qB = qB.startAfterDocument(_lastDocB!);
        } else {
          qB = qB.limit(0);
        }
      }

      final results = await Future.wait([qA.get(), qB.get()]);
      final snapA = results[0];
      final snapB = results[1];

      // Advance cursors + hasMore flags
      if (snapA.docs.isNotEmpty) {
        _lastDocA = snapA.docs.last;
        _hasMoreA = snapA.docs.length == _pageSize;
      } else {
        _hasMoreA = false;
      }
      if (snapB.docs.isNotEmpty) {
        _lastDocB = snapB.docs.last;
        _hasMoreB = snapB.docs.length == _pageSize;
      } else {
        _hasMoreB = false;
      }

      // Merge + dedupe by doc id (new page against what we already have)
      final existingIds = _chats.map((d) => d.id).toSet();
      final merged = <QueryDocumentSnapshot>[];
      for (final snap in results) {
        for (final d in snap.docs) {
          if (existingIds.add(d.id)) merged.add(d);
        }
      }

      // Sort newest-first in Dart (lastMessageTime desc).
      merged.sort((a, b) {
        final ta = (a.data() as Map<String, dynamic>)['lastMessageTime']
            as Timestamp?;
        final tb = (b.data() as Map<String, dynamic>)['lastMessageTime']
            as Timestamp?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      if (!mounted) return;
      setState(() {
        if (reset) {
          _chats
            ..clear()
            ..addAll(merged);
        } else {
          _chats.addAll(merged);
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ChatList] load error: $e');
      if (mounted) setState(() => _loading = false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool get _hasMore => _hasMoreA || _hasMoreB;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _load(reset: true),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No chats yet',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Start by chatting with someone on the feed',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView.separated(
                    itemCount: _chats.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Theme.of(context).dividerColor),
                    itemBuilder: (context, i) => _ChatRow(
                      chatDoc: _chats[i],
                      currentUserId: _currentUserId,
                    ),
                  ),
                ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final QueryDocumentSnapshot chatDoc;
  final String currentUserId;

  const _ChatRow({required this.chatDoc, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final data = chatDoc.data() as Map<String, dynamic>;
    final userA = data['userA'] as String? ?? '';
    final userB = data['userB'] as String? ?? '';
    final otherUserId = userA == currentUserId ? userB : userA;
    final lastMessage = data['lastMessage'] as String? ?? '';
    final lastTime = data['lastMessageTime'] as Timestamp?;
    final lastSenderId = data['lastMessageSenderId'] as String?;

    // Unread count for my side.
    final amIUserA = userA == currentUserId;
    final int unreadCount = amIUserA
        ? (data['unreadForUserA'] ?? 0) as int
        : (data['unreadForUserB'] ?? 0) as int;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .snapshots(),
      builder: (context, userSnap) {
        final uData = userSnap.data?.data() as Map<String, dynamic>?;
        final username = uData?['username'] ?? 'Unknown';
        final isOnline = uData?['isOnline'] == true;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.blue[100],
                child: Text(
                  username.isNotEmpty
                      ? username[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: unreadCount > 0
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (lastTime != null)
                Text(
                  _shortTime(lastTime),
                  style: TextStyle(
                    fontSize: 11,
                    color: unreadCount > 0
                        ? Colors.blue[700]
                        : Colors.grey[600],
                    fontWeight: unreadCount > 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (lastSenderId == currentUserId) ...[
                  Icon(Icons.done_all,
                      size: 14, color: Colors.blue[400]),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    lastMessage.isEmpty
                        ? 'No messages yet'
                        : lastMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color: unreadCount > 0
                          ? Colors.black87
                          : Colors.grey[600],
                      fontWeight: unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    constraints: const BoxConstraints(minWidth: 22),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  otherUserId: otherUserId,
                  otherUsername: username,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _shortTime(Timestamp ts) {
    final d = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24 && now.day == d.day) return '${diff.inHours}h';
    if (now.difference(d).inDays == 1) return 'Yesterday';
    if (now.difference(d).inDays < 7) {
      return DateFormat('EEE').format(d);
    }
    return DateFormat('MMM d').format(d);
  }
}

