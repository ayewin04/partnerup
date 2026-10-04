import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String fallbackContent;
  final String fallbackUsername;
  final String fallbackUserId;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.fallbackContent = '',
    this.fallbackUsername = '',
    this.fallbackUserId = '',
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _loading = true;
  PostModel? _post;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts').doc(widget.postId).get();
      if (doc.exists) {
        _post = PostModel.fromDoc(doc);
      } else {
        // Post was deleted — show cached mirror content
        _post = PostModel(
          id: widget.postId,
          userId: widget.fallbackUserId,
          username: widget.fallbackUsername.isEmpty
              ? 'Unknown' : widget.fallbackUsername,
          content: widget.fallbackContent,
          likesCount: 0,
          commentsCount: 0,
          viewsCount: 0,
          createdAt: Timestamp.now(),
        );
      }
    } catch (e) {
      debugPrint('[PostDetail] error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? const Center(child: Text('Post not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 6, bottom: 20),
                  child: PostCard(post: _post!, recordView: false),
                ),
    );
  }
}
