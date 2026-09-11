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
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final username = userDoc.data()?['username'] ?? 'Unknown';

      await FirebaseFirestore.instance
          .collection('posts').doc(widget.postId)
          .collection('comments').add({
        'userId': user.uid,
        'username': username,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('posts').doc(widget.postId)
          .update({'commentsCount': FieldValue.increment(1)});

      try {
        final postDoc = await FirebaseFirestore.instance
            .collection('posts').doc(widget.postId).get();
        final postOwner = postDoc.data()?['userId'];
        if (postOwner != null && postOwner != user.uid) {
          await FirebaseFirestore.instance
              .collection('users').doc(postOwner)
              .collection('notifications').add({
            'type': 'comment',
            'title': '$username commented',
            'body': text.length > 80
                ? '${text.substring(0, 80)}...'
                : text,
            'data': {'postId': widget.postId},
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('[Notif] comment error: $e');
      }

      _controller.clear();
      FocusScope.of(context).unfocus();
    } catch (_) {}
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


