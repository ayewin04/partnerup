import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import '../widgets/paginated_list_view.dart';
import 'chat_screen.dart';
import 'post_detail_screen.dart';

enum ActivityType { likes, comments, partnerships }

class ActivityScreen extends StatefulWidget {
  final ActivityType type;
  const ActivityScreen({super.key, required this.type});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  String get _title {
    switch (widget.type) {
      case ActivityType.likes:
        return 'Posts I Liked';
      case ActivityType.comments:
        return 'Posts I Commented On';
      case ActivityType.partnerships:
        return 'My Partnerships';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_title,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (widget.type) {
      case ActivityType.likes:
        return _mirroredList('activityLikes');
      case ActivityType.comments:
        return _mirroredList('activityComments');
      case ActivityType.partnerships:
        return _partnershipsList();
    }
  }

  // ============ MIRRORED LIKES / COMMENTS (paginated) ============
  Widget _mirroredList(String collection) {
    final base = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection(collection)
        .orderBy('createdAt', descending: true);

    return PaginatedListView(
      pageSize: 20,
      firstPageQuery: () => base.limit(20),
      nextPageLoader: (lastDoc) =>
          base.startAfterDocument(lastDoc).limit(20),
      itemBuilder: (context, doc) {
        final data = doc.data() as Map<String, dynamic>;
        final postId = data['postId'] ?? '';
        // ← Use mirror data directly if available
        final content = data['postContent'] as String? ?? '';
        final username = data['postUsername'] as String? ?? '';
        final postUserId = data['postUserId'] as String? ?? '';

        // If mirror has all the data we need, don't fetch the post
        if (content.isNotEmpty && username.isNotEmpty) {
          return _postFromMirror(
            postId: postId,
            content: content,
            username: username,
            postUserId: postUserId,
            myComment: data['myComment'] as String?,
          );
        }

        // Fallback: load the post
        return _postLoader(postId);
      },
      emptyBuilder: (context) => _emptyState(
        icon: widget.type == ActivityType.likes
            ? Icons.favorite_border
            : Icons.chat_bubble_outline,
        text: widget.type == ActivityType.likes
            ? 'You haven\'t liked any posts yet'
            : 'You haven\'t commented on any posts yet',
      ),
    );
  }

  // ============ POST FROM MIRROR (no extra reads!) ============
  Widget _postFromMirror({
    required String postId,
    required String content,
    required String username,
    required String postUserId,
    String? myComment,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (postId.isEmpty) return;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => PostDetailScreen(
              postId: postId,
              fallbackContent: content,
              fallbackUsername: username,
              fallbackUserId: postUserId,
            ),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.4)),
              if (myComment != null && myComment.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                        size: 14, color: Colors.blue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('You commented: "$myComment"',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          )),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============ PARTNERSHIPS (no index — merged both sides) ============
  Widget _partnershipsList() {
    return _PartnershipsMergedList(uid: uid!);
  }

  Widget _partnershipTile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userA = data['userA'] as String? ?? '';
    final userB = data['userB'] as String? ?? '';
    final usernameA = data['usernameA'] ?? 'User';
    final usernameB = data['usernameB'] ?? 'User';
    final reason = data['reason'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;

    final otherUserId = userA == uid ? userB : userA;
    final otherUsername = userA == uid ? usernameB : usernameA;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.blue[100],
          child: Text(
            otherUsername.isNotEmpty
              ? otherUsername[0].toUpperCase() : '?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        title: Text(otherUsername,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          )),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('MMM d, y').format(createdAt.toDate()),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.chat_bubble_outline,
            color: Colors.blue),
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ChatScreen(
              otherUserId: otherUserId,
              otherUsername: otherUsername,
            )),
          ),
        ),
      ),
    );
  }

  // ============ FALLBACK: LOAD POST BY ID ============
  Widget _postLoader(String postId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('posts').doc(postId).get(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }
        final post = PostModel.fromDoc(snap.data!);
        // Disable view tracking — this is a list of posts I already interacted with
        return PostCard(post: post, recordView: false);
      },
    );
  }

  // ============ HELPERS ============
  Widget _emptyState({required IconData icon, required String text}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 60, color: Colors.grey),
                const SizedBox(height: 12),
                Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




// ============================================================
// PARTNERSHIPS MERGED LIST — no composite index needed
// Fetches userA=me and userB=me separately (single where each),
// merges, sorts in Dart, paginates client-side.
// ============================================================
class _PartnershipsMergedList extends StatefulWidget {
  final String uid;
  const _PartnershipsMergedList({required this.uid});

  @override
  State<_PartnershipsMergedList> createState() =>
      _PartnershipsMergedListState();
}

class _PartnershipsMergedListState
    extends State<_PartnershipsMergedList> {
  List<DocumentSnapshot> _docs = [];
  int _visible = 20;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      // Each query has ONE where, no orderBy → zero index needed
      final results = await Future.wait([
        db
            .collection('partnerships')
            .where('userA', isEqualTo: widget.uid)
            .limit(100)
            .get(),
        db
            .collection('partnerships')
            .where('userB', isEqualTo: widget.uid)
            .limit(100)
            .get(),
      ]);

      // Merge + dedupe
      final seen = <String>{};
      final merged = <DocumentSnapshot>[];
      for (final snap in results) {
        for (final d in snap.docs) {
          if (seen.add(d.id)) merged.add(d);
        }
      }

      // Sort newest-first in Dart
      merged.sort((a, b) {
        final ta =
            (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        final tb =
            (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      if (!mounted) return;
      setState(() {
        _docs = merged;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[Partnerships] load error: $e');
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 50, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_docs.isEmpty) {
      return _emptyState(
        icon: Icons.handshake_outlined,
        text: 'No partnerships yet',
      );
    }

    final visible = _docs.take(_visible).toList();
    final hasMore = _visible < _docs.length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: visible.length + (hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == visible.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'Showing $_visible of ${_docs.length}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _visible += 20),
                      icon: const Icon(Icons.expand_more, size: 18),
                      label: const Text('Load More'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return _tile(visible[i]);
        },
      ),
    );
  }

  Widget _tile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userA = data['userA'] as String? ?? '';
    final userB = data['userB'] as String? ?? '';
    final usernameA = data['usernameA'] ?? 'User';
    final usernameB = data['usernameB'] ?? 'User';
    final reason = data['reason'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;

    final otherUserId = userA == widget.uid ? userB : userA;
    final otherUsername = userA == widget.uid ? usernameB : usernameA;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.blue[100],
          child: Text(
            otherUsername.isNotEmpty
                ? otherUsername[0].toUpperCase()
                : '?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        title: Text(
          otherUsername,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('MMM d, y').format(createdAt.toDate()),
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.chat_bubble_outline,
              color: Colors.blue),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                otherUserId: otherUserId,
                otherUsername: otherUsername,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState({required IconData icon, required String text}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 60, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
