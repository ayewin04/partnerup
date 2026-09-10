import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../models/post_model.dart';
import '../widgets/post_card.dart';

enum FeedFilter { newest, mostInteracted, random }

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
  DocumentSnapshot? _lastDoc;   // for newest/interacted pagination
  bool _loading = false;
  bool _hasMore = true;
  bool _posting = false;
  int _unreadNotifications = 0;
  FeedFilter _filter = FeedFilter.newest;

  @override
  void initState() {
    super.initState();
    _loadFeed(reset: true);
    _listenNotifications();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300 &&
        !_loading && _hasMore) {
      _loadFeed(reset: false);
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

  /// Load posts according to the current filter.
  /// - reset = true  → start fresh
  /// - reset = false → load more (pagination)
  Future<void> _loadFeed({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _posts = [];
        _lastDoc = null;
        _hasMore = true;
      });
    } else {
      if (!_hasMore || _loading) return;
      setState(() => _loading = true);
    }

    try {
      switch (_filter) {
        case FeedFilter.newest:
          await _loadNewest(reset);
          break;
        case FeedFilter.mostInteracted:
          await _loadMostInteracted(reset);
          break;
        case FeedFilter.random:
          await _loadRandom(reset);
          break;
      }
    } catch (e) {
      debugPrint('[Feed] load error: $e');
    }

    if (mounted) setState(() => _loading = false);
    if (reset) await _saveLastSeen();
  }

  // ============ NEWEST ============
  Future<void> _loadNewest(bool reset) async {
    final query = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    final snap = _lastDoc != null && !reset
        ? await query.startAfterDocument(_lastDoc!).get()
        : await query.get();

    final newPosts = snap.docs.map((d) => PostModel.fromDoc(d)).toList();

    setState(() {
      if (reset) {
        _posts = newPosts;
      } else {
        _posts.addAll(newPosts);
      }
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
      _hasMore = snap.docs.length == pageSize;
    });
  }

  // ============ MOST INTERACTED ============
  // Score = likes + comments + views (computed client-side after fetch)
  Future<void> _loadMostInteracted(bool reset) async {
    // Fetch more so we can sort by interaction and still show 20
    final query = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('likesCount', descending: true)
        .limit(pageSize * 2);

    final snap = _lastDoc != null && !reset
        ? await query.startAfterDocument(_lastDoc!).get()
        : await query.get();

    var newPosts = snap.docs.map((d) => PostModel.fromDoc(d)).toList();

    // Sort by total interactions
    newPosts.sort((a, b) {
      final aScore = a.likesCount + a.commentsCount + a.viewsCount;
      final bScore = b.likesCount + b.commentsCount + b.viewsCount;
      return bScore.compareTo(aScore);
    });

    // Take first 20
    if (newPosts.length > pageSize) {
      newPosts = newPosts.sublist(0, pageSize);
    }

    setState(() {
      if (reset) {
        _posts = newPosts;
      } else {
        _posts.addAll(newPosts);
      }
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
      _hasMore = snap.docs.length == pageSize * 2;
    });
  }

  // ============ RANDOM ============
  // Pull a large batch and shuffle — different each refresh
  Future<void> _loadRandom(bool reset) async {
    // Fetch a bigger pool and shuffle
    final snap = await FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();

    final all = snap.docs.map((d) => PostModel.fromDoc(d)).toList();
    all.shuffle(Random());

    // Avoid duplicating already-loaded posts on "load more"
    final existingIds = _posts.map((p) => p.id).toSet();
    final fresh = all.where((p) => !existingIds.contains(p.id)).toList();

    final slice = fresh.take(pageSize).toList();

    setState(() {
      if (reset) {
        _posts = slice;
      } else {
        _posts.addAll(slice);
      }
      // Random doesn't really paginate normally — just keep going
      _hasMore = fresh.length > pageSize;
    });
  }

  // ============ LAST SEEN ============
  Future<void> _saveLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSeen', DateTime.now().millisecondsSinceEpoch);
  }

  // ============ REFRESH ============
  /// If Newest: show only posts since last visit.
  /// If Interacted / Random: re-run the filter fresh.
  Future<void> _refreshFeed() async {
    if (_filter == FeedFilter.newest) {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getInt('lastSeen') ??
        DateTime.now().subtract(const Duration(days: 1))
            .millisecondsSinceEpoch;
      final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen);

      setState(() => _loading = true);
      try {
        final snap = await FirebaseFirestore.instance
            .collection('posts')
            .where('createdAt',
                isGreaterThan: Timestamp.fromDate(lastSeenDate))
            .orderBy('createdAt', descending: true)
            .limit(pageSize)
            .get();

        final newPosts = snap.docs.map((d) => PostModel.fromDoc(d)).toList();
        setState(() {
          _posts = newPosts;
          _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
          _hasMore = snap.docs.length == pageSize;
        });

        if (newPosts.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No new posts since last visit')));
        }
        await _saveLastSeen();
      } catch (e) {
        debugPrint('[Feed] refresh error: $e');
      }
      if (mounted) setState(() => _loading = false);
    } else {
      await _loadFeed(reset: true);
    }
  }

  // ============ CREATE POST ============
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

  // ============ FILTER CHANGE ============
  void _onFilterChanged(FeedFilter f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _scrollController.jumpTo(0);
    _loadFeed(reset: true);
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
                    const SnackBar(content: Text('Notifications coming soon')));
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
        ],
      ),
      body: Column(
        children: [
          // Post input
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

          // Filter tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _filterChip(FeedFilter.newest, 'New',
                    Icons.access_time),
                _filterChip(FeedFilter.mostInteracted,
                    'Most Interacted', Icons.local_fire_department),
                _filterChip(FeedFilter.random, 'Random',
                    Icons.shuffle),
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
                          onDelete: () =>
                            setState(() => _posts.removeAt(i)),
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

  Widget _filterChip(FeedFilter f, String label, IconData icon) {
    final selected = _filter == f;
    return InkWell(
      onTap: () => _onFilterChanged(f),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: Colors.blue, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
              size: 16,
              color: selected ? Colors.blue[700] : Colors.grey[700]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.blue[700] : Colors.grey[700],
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
