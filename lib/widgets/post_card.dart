import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post_model.dart';
import '../screens/comment_sheet.dart';
import '../screens/chat_screen.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onDelete;
  const PostCard({super.key, required this.post, this.onDelete});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isLiked = false;
  bool _likeLoading = false;

  @override
  void initState() {
    super.initState();
    _listenLikeStatus();
  }

  void _listenLikeStatus() {
    if (currentUserId == null) return;
    FirebaseFirestore.instance
        .collection('posts').doc(widget.post.id)
        .collection('likes').doc(currentUserId)
        .snapshots().listen((doc) {
      if (mounted) setState(() => _isLiked = doc.exists);
    });
  }

  Future<void> _toggleLike() async {
    if (currentUserId == null || _likeLoading) return;
    setState(() => _likeLoading = true);
    final postRef = FirebaseFirestore.instance
        .collection('posts').doc(widget.post.id);
    final likeRef = postRef.collection('likes').doc(currentUserId);
    try {
      if (_isLiked) {
        await likeRef.delete();
        await postRef.update({'likesCount': FieldValue.increment(-1)});
      } else {
        await likeRef.set({
          'userId': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await postRef.update({'likesCount': FieldValue.increment(1)});
      }
    } catch (_) {}
    if (mounted) setState(() => _likeLoading = false);
  }

  Future<void> _share() async {
    await Share.share(
      '"${widget.post.content}" - ${widget.post.username} on PartnerUp');
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentSheet(postId: widget.post.id),
    );
  }

  void _openChat() {
    if (widget.post.userId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't chat with yourself")));
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(
        otherUserId: widget.post.userId,
        otherUsername: widget.post.username,
        postId: widget.post.id,
        postContent: widget.post.content,
      ),
    ));
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.post.userId == currentUserId)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Post',
                  style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete post?'),
                      content: const Text(
                        'This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () =>
                          Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                        TextButton(onPressed: () =>
                          Navigator.pop(ctx, true),
                          child: const Text('Delete',
                            style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.post.id).delete();
                    widget.onDelete?.call();
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () { Navigator.pop(context); _share(); },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts').doc(widget.post.id).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();

        PostModel post;
        if (snapshot.hasData && snapshot.data!.exists) {
          post = PostModel.fromDoc(snapshot.data!);
        } else {
          post = widget.post;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        post.username.isNotEmpty
                          ? post.username[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(_timeAgo(post.createdAt),
                            style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: _showMenu,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(post.content,
                  style: const TextStyle(fontSize: 15, height: 1.4)),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _actionBtn(
                      icon: _isLiked
                          ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.grey[700]!,
                      label: '${post.likesCount}',
                      onTap: _toggleLike,
                    ),
                    _actionBtn(
                      icon: Icons.chat_bubble_outline,
                      color: Colors.grey[700]!,
                      label: '${post.commentsCount}',
                      onTap: _openComments,
                    ),
                    _actionBtn(
                      icon: Icons.share_outlined,
                      color: Colors.grey[700]!,
                      label: 'Share',
                      onTap: _share,
                    ),
                    _actionBtn(
                      icon: Icons.handshake_outlined,
                      color: Colors.blue[700]!,
                      label: 'Chat',
                      onTap: _openChat,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
