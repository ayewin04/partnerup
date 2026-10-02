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

  // Merged chat list — one-shot loaded, paginated
  final List<QueryDocumentSnapshot> _chats = [];
  DocumentSnapshot? _lastDoc;  // last doc after global sort
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
  }

  /// Loads one page of chats. We fetch 2× (pageSize × 2) from each side
  /// to account for merges + sort across userA/userB, then keep the top
  /// `_pageSize` uniques. The cursor is stored on the merged/sorted list.
  Future<void> _loadPage({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _chats.clear();
        _lastDoc = null;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final db = FirebaseFirestore.instance;
      final fetchLimit = _pageSize * 2;

      final futures = <Future<QuerySnapshot>>[
        db.collection('chats')
            .where('userA', isEqualTo: _currentUserId)
            .orderBy('lastMessageTime', descending: true)
            .limit(fetchLimit)
            .get(),
        db.collection('chats')
            .where('userB', isEqualTo: _currentUserId)
            .orderBy('lastMessageTime', descending: true)
            .limit(fetchLimit)
            .get(),
      ];

      final results = await Future.wait(futures);

      // Merge + dedupe
      final seen = <String>{};
      final merged = <QueryDocumentSnapshot>[];
      for (final snap in results) {
        for (final d in snap.docs) {
          if (seen.add(d.id)) merged.add(d);
        }
      }

      // Sort newest-first
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

      // Drop anything already loaded (by id)
      final existing = _chats.map((d) => d.id).toSet();
      final fresh = merged.where((d) => !existing.contains(d.id)).toList();

      final page = fresh.take(_pageSize).toList();

      if (!mounted) return;
      setState(() {
        _chats.addAll(page);
        _hasMore = fresh.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ChatList] load error: $e');
      if (mounted) setState(() => _loading = false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

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
            onPressed: () => _loadPage(reset: true),
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
                        style: TextStyle(fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Start by chatting with someone on the feed',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadPage(reset: true),
                  child: ListView.separated(
                    itemCount: _chats.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => Divider(
                        height: 1, color: Theme.of(context).dividerColor),
                    itemBuilder: (context, i) {
                      if (i == _chats.length) {
                        if (_loadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: OutlinedButton.icon(
                              onPressed: () => _loadPage(reset: false),
                              icon: const Icon(Icons.expand_more, size: 18),
                              label: const Text('Load More'),
                            ),
                          ),
                        );
                      }
                      return _ChatRow(
                        chatDoc: _chats[i],
                        currentUserId: _currentUserId,
                      );
                    },
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

    // -------- Unread count from counter fields --------
    final amIUserA = userA == currentUserId;
    final int unreadCount = amIUserA
        ? (data['unreadForUserA'] ?? 0) as int
        : (data['unreadForUserB'] ?? 0) as int;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(otherUserId).snapshots(),
      builder: (context, userSnap) {
        final uData = userSnap.data?.data() as Map<String, dynamic>?;
        final username = uData?['username'] ?? 'Unknown';
        final isOnline = uData?['isOnline'] == true;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.blue[100],
                child: Text(
                  username.isNotEmpty
                    ? username[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white, width: 2),
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
                    size: 14,
                    color: Colors.blue[400]),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    lastMessage.isEmpty ? 'No messages yet' : lastMessage,
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
            await Navigator.push(context,
              MaterialPageRoute(builder: (_) => ChatScreen(
                otherUserId: otherUserId,
                otherUsername: username,
              )),
            );
            // When returning, force rebuild so counter reflects the reset
            // (the listener will already update, this is just a safety)
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





