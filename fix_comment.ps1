$dart = @"
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
  static const int _pageSize = 50;

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();

  bool _sending = false;

  final List<DocumentSnapshot> _comments = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  DocumentSnapshot? _editingDoc;
  String? _editingText;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _hasMore = true;
      _comments.clear();
      _lastDoc = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('posts').doc(widget.postId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .limit(_pageSize)
          .get();
      if (!mounted) return;
      setState(() {
        _comments.addAll(snap.docs);
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        _hasMore = snap.docs.length == _pageSize;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[Comment] load error: `$e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _loadingMore = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('posts').doc(widget.postId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();
      if (!mounted) return;
      setState(() {
        _comments.addAll(snap.docs);
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
        _hasMore = snap.docs.length == _pageSize;
      });
    } catch (e) {
      debugPrint('[Comment] loadMore error: `$e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (text.length > 100) {
      _showError('Comment must be under 100 characters');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _sending = true);
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        FirebaseFirestore.instance.collection('posts').doc(widget.postId).get(),
      ]);
      final userDoc = results[0];
      final postDoc = results[1];
      if (!postDoc.exists) throw Exception('Post not found');

      final username = userDoc.data()?['username'] ?? 'Unknown';
      final postData = postDoc.data();
      final postOwner = postData?['userId'] as String?;
      final postContent = postData?['content'] as String? ?? '';
      final postUsername = postData?['username'] as String? ?? '';

      final batch = FirebaseFirestore.instance.batch();
      final commentRef = FirebaseFirestore.instance
          .collection('posts').doc(widget.postId)
          .collection('comments').doc();

      batch.set(commentRef, {
        'userId': user.uid,
        'username': username,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isEdited': false,
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
      if (postOwner != null && postOwner != user.uid) {
        final notifRef = FirebaseFirestore.instance
            .collection('users').doc(postOwner)
            .collection('notifications').doc();
        batch.set(notifRef, {
          'type': 'comment',
          'title': '`$username commented',
          'body': text.length > 80 ? '`${text.substring(0, 80)}...' : text,
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

      try {
        final newSnap = await commentRef.get();
        if (mounted) {
          setState(() => _comments.add(newSnap));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }
      } catch (e) {
        debugPrint('[Comment] fetch new comment error: `$e');
      }

      _controller.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      _showError('Failed to comment: `$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _beginEdit(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _editingDoc = doc;
      _editingText = data['text'] as String? ?? '';
      _controller.text = _editingText ?? '';
    });
    _inputFocus.requestFocus();
  }

  void _cancelEdit() {
    setState(() {
      _editingDoc = null;
      _editingText = null;
    });
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _submitEdit() async {
    if (_editingDoc == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (text.length > 100) {
      _showError('Comment must be under 100 characters');
      return;
    }

    setState(() => _sending = true);
    try {
      await _editingDoc!.reference.update({
        'text': text,
        'isEdited': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final idx = _comments.indexWhere((d) => d.id == _editingDoc!.id);
      if (idx != -1) {
        final fresh = await _editingDoc!.reference.get();
        if (mounted) setState(() => _comments[idx] = fresh);
      }

      if (!mounted) return;
      _cancelEdit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Failed to update: `$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(DocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete comment?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(doc.reference);
      batch.update(
        FirebaseFirestore.instance.collection('posts').doc(widget.postId),
        {'commentsCount': FieldValue.increment(-1)},
      );
      final uid = _uid;
      if (uid != null) {
        batch.delete(
          FirebaseFirestore.instance
              .collection('users').doc(uid)
              .collection('activityComments').doc(widget.postId),
        );
      }
      await batch.commit();

      if (mounted) {
        setState(() => _comments.removeWhere((d) => d.id == doc.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to delete: `$e');
    }
  }

  void _showCommentActions(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isMine = data['userId'] == _uid;
    if (!isMine) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit comment'),
              onTap: () {
                Navigator.pop(context);
                _beginEdit(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete comment',
                style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteComment(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60) return '`${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '`${diff.inMinutes}m';
    if (diff.inHours < 24) return '`${diff.inHours}h';
    return DateFormat('MMM d').format(ts.toDate());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = _editingDoc != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
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

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Text('No comments yet. Be the first!',
                          style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _comments.length + (_hasMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == _comments.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          final doc = _comments[i];
                          final c = CommentModel.fromDoc(doc);
                          final data = doc.data() as Map<String, dynamic>;
                          final isMine = c.userId == _uid;
                          final isEdited = data['isEdited'] == true;
                          return _commentTile(
                            doc: doc,
                            c: c,
                            isMine: isMine,
                            isEdited: isEdited,
                          );
                        },
                      ),
          ),

          if (isEditing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
              color: Colors.blue[50],
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Editing comment...',
                      style: TextStyle(fontSize: 12, color: Colors.blue)),
                  ),
                  TextButton(
                    onPressed: _cancelEdit,
                    child: const Text('Cancel',
                      style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

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
                    focusNode: _inputFocus,
                    maxLength: 100,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) =>
                      isEditing ? _submitEdit() : _send(),
                    decoration: InputDecoration(
                      hintText: isEditing
                        ? 'Edit your comment...'
                        : 'Write a comment...',
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
                  onPressed: _sending
                    ? null
                    : (isEditing ? _submitEdit : _send),
                  icon: _sending
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        isEditing ? Icons.check : Icons.send,
                        color: isEditing ? Colors.green : Colors.blue,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentTile({
    required DocumentSnapshot doc,
    required CommentModel c,
    required bool isMine,
    required bool isEdited,
  }) {
    return InkWell(
      onLongPress: isMine ? () => _showCommentActions(doc) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isMine ? Colors.blue[700] : Colors.blue[100],
              child: Text(
                c.username.isNotEmpty ? c.username[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 12,
                  color: isMine ? Colors.white : Colors.blue,
                ),
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
                            fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      if (isMine)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('You',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            )),
                        ),
                      const SizedBox(width: 8),
                      Text(_timeAgo(c.createdAt),
                        style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                      if (isEdited) ...[
                        const SizedBox(width: 6),
                        const Text('· edited',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic)),
                      ],
                      const Spacer(),
                      if (isMine)
                        InkWell(
                          onTap: () => _showCommentActions(doc),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.more_horiz,
                              size: 16, color: Colors.grey[600]),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(c.text, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
"@

Set-Content -Path 'lib\screens\comment_sheet.dart' -Value $dart -Encoding UTF8 -NoNewline

Write-Host 'comment_sheet.dart overwritten' -ForegroundColor Green
Write-Host 'Now paste the rules from the previous message into Firebase Console -> Firestore -> Rules' -ForegroundColor Yellow
