import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'chat_screen.dart';

enum SearchTab { users, posts }

enum PostFilter {
  mostLiked,
  mostViewed,
  today,
  threeDays,
  oneWeek,
  oneMonth,
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late TabController _tabController;

  String _query = '';
  SearchTab _tab = SearchTab.users;
  PostFilter _filter = PostFilter.mostLiked;

  List<PostModel> _postResults = [];
  List<Map<String, dynamic>> _userResults = [];
  DocumentSnapshot? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;
  static const int pageSize = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _tab = _tabController.index == 0
              ? SearchTab.users
              : SearchTab.posts;
        });
        _performSearch(reset: true);
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300 &&
        !_loading &&
        _hasMore) {
      _performSearch(reset: false);
    }
  }

  Future<void> _performSearch({required bool reset}) async {
    final q = _query.trim();

    if (q.isEmpty && _tab == SearchTab.users) {
      setState(() {
        _userResults = [];
        _postResults = [];
        _loading = false;
        _hasMore = false;
      });
      return;
    }

    if (reset) {
      setState(() {
        _loading = true;
        _userResults = [];
        _postResults = [];
        _lastDoc = null;
        _hasMore = true;
      });
    } else {
      if (!_hasMore || _loading) return;
      setState(() => _loading = true);
    }

    try {
      if (_tab == SearchTab.users) {
        await _searchUsers(reset);
      } else {
        await _searchPosts(reset);
      }
    } catch (e) {
      debugPrint('[Search] error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  // ============ USERS ============
  Future<void> _searchUsers(bool reset) async {
    final q = _query.trim().toLowerCase();

    Query query;

    if (q.isNotEmpty) {
      query = FirebaseFirestore.instance
          .collection('users')
          .where('usernameLower', isGreaterThanOrEqualTo: q)
          .where('usernameLower', isLessThan: '$q\uf8ff')
          .limit(pageSize);
    } else {
      query = FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(pageSize);
    }

    final snap = _lastDoc != null && !reset
        ? await query.startAfterDocument(_lastDoc!).get()
        : await query.get();

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    final newUsers = snap.docs
        .where((d) => d.id != currentUid)
        .map((d) {
      final data = d.data() as Map<String, dynamic>;
      return {
        'uid': d.id,
        'username': data['username'] ?? 'Unknown',
        'partnershipCount': data['partnershipCount'] ?? 0,
        'bio': data['bio'] ?? '',
        'isOnline': data['isOnline'] ?? false,
      };
    }).toList();

    setState(() {
      if (reset) {
        _userResults = newUsers;
      } else {
        _userResults.addAll(newUsers);
      }
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
      _hasMore = snap.docs.length == pageSize;
    });
  }

  // ============ POSTS ============
  // Strategy: Fetch posts by keyword + sort in Dart.
  // "Most Viewed" and "Most Liked" fetch a large batch then sort client-side.
  Future<void> _searchPosts(bool reset) async {
    final q = _query.trim().toLowerCase();

    Query query;

    if (q.isNotEmpty) {
      // Keyword search on contentLower prefix
      query = FirebaseFirestore.instance
          .collection('posts')
          .where('contentLower', isGreaterThanOrEqualTo: q)
          .where('contentLower', isLessThan: '$q\uf8ff')
          .limit(100);
    } else {
      // No keyword → fetch recent posts by default
      query = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(100);
    }

    final snap = await query.get();
    var posts = snap.docs.map((d) => PostModel.fromDoc(d)).toList();

    // Apply filter in Dart
    final now = DateTime.now();
    switch (_filter) {
      case PostFilter.mostLiked:
        posts.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
      case PostFilter.mostViewed:
        posts.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
        break;
      case PostFilter.today:
        posts = posts
            .where((p) =>
                now.difference(p.createdAt.toDate()).inDays < 1)
            .toList();
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case PostFilter.threeDays:
        posts = posts
            .where((p) =>
                now.difference(p.createdAt.toDate()).inDays < 3)
            .toList();
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case PostFilter.oneWeek:
        posts = posts
            .where((p) =>
                now.difference(p.createdAt.toDate()).inDays < 7)
            .toList();
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case PostFilter.oneMonth:
        posts = posts
            .where((p) =>
                now.difference(p.createdAt.toDate()).inDays < 30)
            .toList();
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    final existingIds = _postResults.map((p) => p.id).toSet();
    final fresh = posts.where((p) => !existingIds.contains(p.id)).toList();
    final slice = fresh.take(pageSize).toList();

    setState(() {
      if (reset) {
        _postResults = slice;
      } else {
        _postResults.addAll(slice);
      }
      _hasMore = fresh.length > pageSize;
      _lastDoc = null;
    });
  }

  void _onQueryChanged(String val) {
    _query = val;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_query == val) {
        _performSearch(reset: true);
      }
    });
  }

  void _onFilterChanged(PostFilter f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _performSearch(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search',
          style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Users', icon: Icon(Icons.person, size: 18)),
            Tab(text: 'Posts', icon: Icon(Icons.article, size: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _tab == SearchTab.users
                    ? 'Search users by username...'
                    : 'Search posts by keyword...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          if (_tab == SearchTab.posts)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _filterChip(PostFilter.mostLiked, 'Most Liked',
                      Icons.favorite),
                  const SizedBox(width: 8),
                  _filterChip(PostFilter.mostViewed, 'Most Viewed',
                      Icons.visibility),
                  const SizedBox(width: 8),
                  _filterChip(PostFilter.today, 'Today',
                      Icons.today),
                  const SizedBox(width: 8),
                  _filterChip(PostFilter.threeDays, '3 Days',
                      Icons.calendar_today),
                  const SizedBox(width: 8),
                  _filterChip(PostFilter.oneWeek, '1 Week',
                      Icons.date_range),
                  const SizedBox(width: 8),
                  _filterChip(PostFilter.oneMonth, '1 Month',
                      Icons.event),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _loading && _userResults.isEmpty && _postResults.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_tab == SearchTab.users) {
      if (_userResults.isEmpty) {
        return _emptyState(
            _query.isEmpty
                ? 'Type a username to search'
                : 'No users found for "$_query"');
      }
      return ListView.separated(
        controller: _scrollController,
        itemCount: _userResults.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (_, i) {
          if (i == _userResults.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _userRow(_userResults[i]);
        },
      );
    } else {
      if (_postResults.isEmpty) {
        return _emptyState(
            _query.isEmpty
                ? 'No posts match this filter'
                : 'No posts found for "$_query"');
      }
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 6, bottom: 20),
        itemCount: _postResults.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _postResults.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return PostCard(post: _postResults[i]);
        },
      );
    }
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Widget _userRow(Map<String, dynamic> user) {
    final username = user['username'] as String;
    final partnerships = user['partnershipCount'] ?? 0;
    final isOnline = user['isOnline'] == true;
    final bio = user['bio'] as String? ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue[100],
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 18,
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
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(username,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(bio,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12, color: Colors.grey[600])),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('🤝 $partnerships partnerships',
              style: TextStyle(
                fontSize: 12, color: Colors.grey[700])),
          ),
        ],
      ),
      trailing: ElevatedButton.icon(
        onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatScreen(
            otherUserId: user['uid'],
            otherUsername: username,
          )),
        ),
        icon: const Icon(Icons.chat_bubble_outline, size: 14),
        label: const Text('Chat', style: TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        ),
      ),
      onTap: () {
        Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatScreen(
            otherUserId: user['uid'],
            otherUsername: username,
          )),
        );
      },
    );
  }

  Widget _filterChip(PostFilter f, String label, IconData icon) {
    final selected = _filter == f;
    return InkWell(
      onTap: () => _onFilterChanged(f),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey[300]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
              size: 14,
              color: selected ? Colors.blue[700] : Colors.grey[700]),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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


