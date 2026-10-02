import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/comment_model.dart';

class CommentSheet extends StatefulWidget {
  final String postId;
  const CommentSheet({super.key, required this.postId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (text.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment must be under 100 characters')));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _sending = true);
    try {
      // ===== OPTIMIZATION: Read user + post in PARALLEL (1 round-trip) =====
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users').doc(user.uid).get(),
        FirebaseFirestore.instance
            .collection('posts').doc(widget.postId).get(),
      ]);
      final userDoc = results[0];
      final postDoc = results[1];

      final username = userDoc.data()?['username'] ?? 'Unknown';
      final postData = postDoc.data();
      final postOwner = postData?['userId'] as String?;
      final postContent = postData?['content'] as String? ?? '';
      final postUsername = postData?['username'] as String? ?? '';

      // ===== Write comment + increment + mirror in ONE batch =====
      final batch = FirebaseFirestore.instance.batch();

      final commentRef = FirebaseFirestore.instance
          .collection('posts').doc(widget.postId)
          .collection('comments').doc();

      batch.set(commentRef, {
        'userId': user.uid,
        'username': username,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(
        FirebaseFirestore.instance.collection('posts').doc(widget.postId),
        {'commentsCount': FieldValue.increment(1)},
      );

      batch.set(
        FirebaseFirestore.instance
            .collection('users').doc(user.uid)
            .collection('activityComments').doc(widget.postId),
        {
          'postId': widget.postId,
          'postContent': postContent,
          'postUsername': postUsername,
          'postUserId': postOwner ?? '',
          'myComment': text,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      // ===== Notify post owner (if not self) — same batch =====
      if (postOwner != null && postOwner != user.uid) {
        final notifRef = FirebaseFirestore.instance
            .collection('users').doc(postOwner)
            .collection('notifications').doc();
        batch.set(notifRef, {
          'type': 'comment',
          'title': '$username commented',
          'body': text.length > 80
              ? '${text.substring(0, 80)}...'
              : text,
          'data': {'postId': widget.postId},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(postOwner),
          {'unreadNotificationCount': FieldValue.increment(1)},
        );
      }

      await batch.commit();

      _controller.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      debugPrint('[Comment] error: $e');
    }
    if (mounted) setState(() => _sending = false);
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('MMM d').format(ts.toDate());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Comments',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),

          // Comments list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts').doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No comments yet. Be the first!',
                      style: TextStyle(color: Colors.grey)));
                }
                final comments = snap.data!.docs
                    .map((d) => CommentModel.fromDoc(d)).toList();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: comments.length,
                  itemBuilder: (_, i) {
                    final c = comments[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              c.username.isNotEmpty
                                ? c.username[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(c.username,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_timeAgo(c.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(c.text, style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input
          Container(
            padding: EdgeInsets.only(
              left: 12, right: 12, top: 8, bottom: bottom + 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 100,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
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
        ],
      ),
    );
  }
}





