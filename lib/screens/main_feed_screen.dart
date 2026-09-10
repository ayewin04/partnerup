import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'splash_screen.dart';

class MainFeedScreen extends StatefulWidget {
  const MainFeedScreen({super.key});
  @override
  State<MainFeedScreen> createState() => _MainFeedScreenState();
}

class _MainFeedScreenState extends State<MainFeedScreen> {
  static const int pageSize = 20;
  final _postController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  List<PostModel> _posts = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;
  bool _posting = false;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _listenNotifications();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300 &&
        !_loading && _hasMore) {
      _loadMore();
    }
  }

  void _listenNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _unreadNotifications = snap.docs.length);
    });
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .get();

      _posts = snap.docs.map((d) => PostModel.fromDoc(d)).toList();
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      _hasMore = snap.docs.length == pageSize;
      await _saveLastSeen();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_lastDoc == null || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(pageSize)
          .get();

      final newPosts = snap.docs.map((d) => PostModel.fromDoc(d)).toList();
      _posts.addAll(newPosts);
      if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
      _hasMore = snap.docs.length == pageSize;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSeen',
      DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _refreshFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeen = prefs.getInt('lastSeen') ??
      DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen);

    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(lastSeenDate))
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .get();

      final newPosts = snap.docs.map((d) => PostModel.fromDoc(d)).toList();
      _posts = newPosts;
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      _hasMore = snap.docs.length == pageSize;

      if (newPosts.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No new posts since last visit')));
      }
      await _saveLastSeen();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;
    if (text.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post must be under 200 characters')));
      return;
    }

    setState(() => _posting = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final username = userDoc.data()?['username'] ?? 'Unknown';

      final newDoc = await FirebaseFirestore.instance
          .collection('posts').add({
        'userId': user.uid,
        'username': username,
        'content': text,
        'likesCount': 0,
        'commentsCount': 0,
        'viewsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _postController.clear();
      _focusNode.unfocus();

      final doc = await newDoc.get();
      setState(() {
        _posts.insert(0, PostModel.fromDoc(doc));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post published!')));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to publish post')));
    }
    if (mounted) setState(() => _posting = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout',
              style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users').doc(uid).update({
          'isOnline': false,
          'lastSeenAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _postController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PartnerUp',
          style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications screen coming soon')));
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Post Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    focusNode: _focusNode,
                    maxLength: 200,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'What do you want to partner for?',
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _posting
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      onPressed: _createPost,
                      icon: const Icon(Icons.send, color: Colors.blue),
                    ),
              ],
            ),
          ),

          // Feed list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshFeed,
              child: _posts.isEmpty && _loading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(child: Text('No posts yet. Be the first!',
                          style: TextStyle(color: Colors.grey))),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 6, bottom: 80),
                      itemCount: _posts.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _posts.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return PostCard(
                          post: _posts[i],
                          onDelete: () => setState(() => _posts.removeAt(i)),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _focusNode.requestFocus();
          _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
        },
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}
