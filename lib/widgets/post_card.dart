import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';
import '../screens/comment_sheet.dart';
import '../screens/post_detail_screen.dart';
import '../screens/chat_screen.dart';
import '../services/rate_limiter.dart';
import '../services/rate_limit_service.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onDelete;
  /// Set false to skip view tracking (e.g. on Activity / Profile pages).
  final bool recordView;

  const PostCard({
    super.key,
    required this.post,
    this.onDelete,
    this.recordView = true,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isLiked = false;
  bool _likeLoading = false;
  bool _viewRecorded = false;

  @override
  void initState() {
    super.initState();
    _checkLikeStatus();  // one-time .get() instead of permanent listener
    if (widget.recordView) {
      _recordView();
    } else {
      _viewRecorded = true; // skip
    }
  }

  /// Records a unique view — only counts once per user per post.
  /// Uses local SharedPreferences cache to avoid Firestore reads.
  Future<void> _recordView() async {
    if (currentUserId == null || _viewRecorded) return;

    // Don't count the author viewing their own post
    if (widget.post.userId == currentUserId) {
      _viewRecorded = true;
      return;
    }

    _viewRecorded = true;

    try {
      // ===== LAYER 1: Local cache (no cost) =====
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'viewed_${widget.post.id}_$currentUserId';
      if (prefs.getBool(cacheKey) == true) {
        debugPrint('[Views] local cache hit for ${widget.post.id}');
        return;
      }

      final postRef = FirebaseFirestore.instance
          .collection('posts').doc(widget.post.id);
      final viewRef = postRef.collection('views').doc(currentUserId);

      // ===== LAYER 2: Firestore check (only if not cached locally) =====
      final existing = await viewRef.get();
      if (existing.exists) {
        // Save to local cache so we never check again
        await prefs.setBool(cacheKey, true);
        debugPrint('[Views] firestore says already counted');
        return;
      }

      // ===== LAYER 3: Record the view =====
      await viewRef.set({
        'userId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await postRef.update({
        'viewsCount': FieldValue.increment(1),
      });
      await prefs.setBool(cacheKey, true);
      debugPrint('[Views] recorded for ${widget.post.id}');
    } catch (e) {
      debugPrint('[Views] error: $e');
    }
  }

  /// ONE-TIME check: did I like this post?
  /// Cache-first — only reads Firestore if not cached locally.
  Future<void> _checkLikeStatus() async {
    if (currentUserId == null) return;
    try {
      // LAYER 1: local SharedPreferences cache
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'liked_${widget.post.id}_$currentUserId';
      final cached = prefs.getBool(cacheKey);
      if (cached != null) {
        if (mounted) setState(() => _isLiked = cached);
        debugPrint('[Like] cache hit for ${widget.post.id}');
        return;
      }

      // LAYER 2: Firestore (first time only)
      final doc = await FirebaseFirestore.instance
          .collection('posts').doc(widget.post.id)
          .collection('likes').doc(currentUserId)
          .get();
      if (mounted) setState(() => _isLiked = doc.exists);
      await prefs.setBool(cacheKey, doc.exists);
    } catch (e) {
      debugPrint('[Like] check error: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (currentUserId == null || _likeLoading) return;

    // Layer 1: debounce (1s)
    final ok = await RateLimiter.allow(
      action: 'toggle_like',
      cooldown: RateLimits.toggleLike,
    );
    if (!ok) return;

    // ===== OPTIMISTIC UI: flip state instantly =====
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likeLoading = true;
    });

    final postRef = FirebaseFirestore.instance
        .collection('posts').doc(widget.post.id);
    final likeRef = postRef.collection('likes').doc(currentUserId);
    try {
      if (wasLiked) {
        await likeRef.delete();
        await postRef.update({'likesCount': FieldValue.increment(-1)});

        // Remove from activity mirror
        try {
          await FirebaseFirestore.instance
              .collection('users').doc(currentUserId)
              .collection('activityLikes').doc(widget.post.id)
              .delete();
        } catch (e) {
          debugPrint('[Activity] unlike mirror error: $e');
        }
      } else {
        // Layer 2: hourly cap for likes
        final batch = FirebaseFirestore.instance.batch();
        try {
          await RateLimitService.checkAndBump(
            batch: batch,
            bucket: 'likes',
            cap: RateLimits.likesPerHour,
            window: const Duration(hours: 1),
          );
        } on RateLimitException catch (e) {
          if (mounted) {
            showRateLimitMessage(
              context,
              action: 'liking posts',
              seconds: e.retryAfterSeconds ?? 3600,
            );
            setState(() {
              _isLiked = wasLiked;
              _likeLoading = false;
            });
          }
          return;
        }
        await batch.commit();

        await likeRef.set({
          'userId': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await postRef.update({'likesCount': FieldValue.increment(1)});

        // Mirror to activity collection (no index needed)
        try {
          await FirebaseFirestore.instance
              .collection('users').doc(currentUserId)
              .collection('activityLikes').doc(widget.post.id)
              .set({
            'postId': widget.post.id,
            'postContent': widget.post.content,
            'postUsername': widget.post.username,
            'postUserId': widget.post.userId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('[Activity] like mirror error: $e');
        }

        if (widget.post.userId != currentUserId) {
          try {
            // Use cached username if available; else one read
            final myUsername = widget.post.username == 'me'
                ? 'Someone'
                : await _getMyUsernameCached();
            await FirebaseFirestore.instance
                .collection('users').doc(widget.post.userId)
                .collection('notifications').add({
              'type': 'like',
              'title': '$myUsername liked your post',
              'body': widget.post.content.length > 60
                  ? '${widget.post.content.substring(0, 60)}...'
                  : widget.post.content,
              'data': {'postId': widget.post.id},
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            debugPrint('[Notif] like error: $e');
          }
        }
      }
      // Persist the final like state to local cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          'liked_${widget.post.id}_$currentUserId',
          _isLiked,
        );
      } catch (e) {
        debugPrint('[Like] cache write error: $e');
      }
    } catch (e) {
      // Revert optimistic UI on error
      debugPrint('[Like] error: $e');
      if (mounted) setState(() => _isLiked = wasLiked);
      // Also revert the cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          'liked_${widget.post.id}_$currentUserId',
          wasLiked,
        );
      } catch (_) {}
    }
    if (mounted) setState(() => _likeLoading = false);
  }

  Future<void> _share() async {
    final shareText = '"${widget.post.content}" '
        '- ${widget.post.username} on PartnerUp';

    try {
      // Try native share (works on Android, iOS, macOS, Windows)
      // On web, share_plus falls back to navigator.share if available
      final result = await Share.share(
        shareText,
        subject: 'PartnerUp post by ${widget.post.username}',
      );

      if (result.status == ShareResultStatus.dismissed) {
        debugPrint('[Share] dismissed');
      }
    } catch (e) {
      debugPrint('[Share] error: $e');

      // Fallback: copy to clipboard
      try {
        await Clipboard.setData(ClipboardData(text: shareText));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post copied to clipboard!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e2) {
        debugPrint('[Share] clipboard error: $e2');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not share'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

  // ===== Cached current user's username (avoids repeat reads) =====
  static String? _cachedUsername;
  static String? _cachedUsernameFor;

  Future<String> _getMyUsernameCached() async {
    if (_cachedUsername != null && _cachedUsernameFor == currentUserId) {
      return _cachedUsername!;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(currentUserId).get();
    _cachedUsername = doc.data()?['username'] ?? 'Someone';
    _cachedUsernameFor = currentUserId;
    return _cachedUsername!;
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.post.userId == currentUserId) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Post',
                  style: TextStyle(color: Colors.blue)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog();
                },
              ),
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
            ],
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



  Future<void> _showEditDialog() async {
    final controller = TextEditingController(text: widget.post.content);
    bool saving = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLength: 200,
                maxLines: 5,
                minLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'What do you want to partner for?',
                  errorText: error,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) {
                        setDialogState(() =>
                          error = 'Post cannot be empty');
                        return;
                      }
                      if (text.length > 200) {
                        setDialogState(() =>
                          error = 'Max 200 characters');
                        return;
                      }
                      setDialogState(() { saving = true; error = null; });
                      try {
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(widget.post.id)
                            .update({
                          'content': text,
                          'contentLower': text.toLowerCase(),
                          'isEdited': true,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Post updated'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() {
                          error = 'Failed: $e';
                          saving = false;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              child: saving
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : const Text('Save'),
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
                      backgroundColor: Colors.blue.withValues(alpha: 0.2),
                      child: Text(
                        post.username.isNotEmpty
                          ? post.username[0].toUpperCase() : '?',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, height: 1.4)),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 340;
                    final w = isNarrow
                        ? constraints.maxWidth / 3 - 4
                        : constraints.maxWidth / 5 - 4;
                    final wHalf = constraints.maxWidth / 2 - 4;
                    return Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      runAlignment: WrapAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _flexAction(
                          width: w,
                          icon: _isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _isLiked
                              ? Colors.red
                              : Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color ??
                                  Colors.grey,
                          label: '${post.likesCount}',
                          onTap: _toggleLike,
                        ),
                        _flexAction(
                          width: w,
                          icon: Icons.chat_bubble_outline,
                          color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color ??
                              Colors.grey,
                          label: '${post.commentsCount}',
                          onTap: _openComments,
                        ),
                        _flexAction(
                          width: w,
                          icon: Icons.visibility_outlined,
                          color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color ??
                              Colors.grey,
                          label: '${post.viewsCount}',
                          onTap: () {},
                        ),
                        _flexAction(
                          width: isNarrow ? wHalf : w,
                          icon: Icons.share_outlined,
                          color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color ??
                              Colors.grey,
                          label: 'Share',
                          onTap: _share,
                        ),
                        _flexAction(
                          width: isNarrow ? wHalf : w,
                          icon: Icons.handshake_outlined,
                          color: Colors.blue[700]!,
                          label: 'Chat',
                          onTap: _openChat,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _flexAction({
    required double width,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}























