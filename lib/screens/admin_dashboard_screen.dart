import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import 'admin_panel_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.people, size: 18), text: 'Users'),
            Tab(icon: Icon(Icons.report, size: 18), text: 'Reports'),
            Tab(icon: Icon(Icons.article, size: 18), text: 'Posts'),
            Tab(icon: Icon(Icons.campaign, size: 18), text: 'Broadcast'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(tabController: _tabController),
          const _UsersTab(),
          const _ReportsTab(),
          const _PostsTab(),
          const _BroadcastTab(),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 1: OVERVIEW
// ============================================================
class _OverviewTab extends StatelessWidget {
  final TabController tabController;

  const _OverviewTab({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            final crossCount = isWide ? 4 : 2;
            return GridView.count(
              crossAxisCount: crossCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _statCard(
                  icon: Icons.people,
                  label: 'Total Users',
                  color: Colors.blue,
                  query: FirebaseFirestore.instance
                      .collection('users').limit(2000).snapshots(),
                ),
                _statCard(
                  icon: Icons.article,
                  label: 'Total Posts',
                  color: Colors.green,
                  query: FirebaseFirestore.instance
                      .collection('posts').limit(2000).snapshots(),
                ),
                _statCard(
                  icon: Icons.report,
                  label: 'Pending Reports',
                  color: Colors.orange,
                  query: FirebaseFirestore.instance
                      .collection('reports')
                      .where('status', isEqualTo: 'pending_proof')
                      .limit(500).snapshots(),
                ),
                _statCard(
                  icon: Icons.warning_amber,
                  label: 'Cheaters',
                  color: Colors.red,
                  query: FirebaseFirestore.instance
                      .collection('reports')
                      .where('status', isEqualTo: 'cheater')
                      .limit(500).snapshots(),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Quick actions
        const Text('Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          )),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _quickAction(
              context,
              icon: Icons.people_alt,
              label: 'Manage Users',
              color: Colors.blue,
              onTap: () => tabController.animateTo(1),
            ),
            _quickAction(
              context,
              icon: Icons.gavel,
              label: 'Manage Reports',
              color: Colors.deepPurple,
              onTap: () => tabController.animateTo(2),
            ),
            _quickAction(
              context,
              icon: Icons.article_outlined,
              label: 'Manage Posts',
              color: Colors.green,
              onTap: () => tabController.animateTo(3),
            ),
            _quickAction(
              context,
              icon: Icons.campaign,
              label: 'Send Broadcast',
              color: Colors.orange,
              onTap: () => tabController.animateTo(4),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Recent activity
        const Text('Recent Activity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          )),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .limit(10)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No recent activity',
                  style: TextStyle(color: Colors.grey)),
              );
            }
            final docs = snap.data!.docs.toList();
            docs.sort((a, b) {
              final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return tb.compareTo(ta);
            });
            return Column(
              children: docs.take(5).map((d) {
                final data = d.data() as Map<String, dynamic>;
                return _activityTile(
                  icon: Icons.report,
                  color: Colors.orange,
                  title: '@${data['reporterUsername']} → @${data['reportedUsername']}',
                  subtitle: data['reason'] ?? '',
                  time: data['createdAt'] as Timestamp?,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required Color color,
    required Stream<QuerySnapshot> query,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: query,
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text('$count',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                )),
              const SizedBox(height: 2),
              Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                )),
            ],
          ),
        );
      },
    );
  }

  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              )),
          ],
        ),
      ),
    );
  }

  Widget _activityTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Timestamp? time,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13)),
        subtitle: subtitle.isNotEmpty
          ? Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12))
          : null,
        trailing: time != null
          ? Text(_timeAgo(time),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]))
          : null,
      ),
    );
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ============================================================
// TAB 2: USERS
// ============================================================
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search + filter
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search by username...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('all', 'All'),
                    _filterChip('online', 'Online'),
                    _filterChip('banned', 'Banned'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // User list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users').limit(500).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var docs = snap.data!.docs.toList();

              // Filter by search
              if (_query.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final username = (data['username'] ?? '').toString().toLowerCase();
                  return username.contains(_query);
                }).toList();
              }
              // Filter by status
              if (_filter == 'online') {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['isOnline'] == true;
                }).toList();
              } else if (_filter == 'banned') {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return data['isBanned'] == true;
                }).toList();
              }

              if (docs.isEmpty) {
                return const Center(
                  child: Text('No users found',
                    style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) => _userTile(docs[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _userTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final username = data['username'] ?? 'Unknown';
    final isOnline = data['isOnline'] == true;
    final isBanned = data['isBanned'] == true;
    final partnerships = data['partnershipCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isBanned
                  ? Colors.red[100]
                  : Colors.blue[100],
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isBanned ? Colors.red : Colors.blue,
                ),
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            if (isBanned)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: const Text('BANNED',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  )),
              ),
          ],
        ),
        subtitle: Text('🤝 $partnerships partnerships',
          style: const TextStyle(fontSize: 12)),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(doc, action),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 16),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            PopupMenuItem(
              value: isBanned ? 'unban' : 'ban',
              child: Row(
                children: [
                  Icon(
                    isBanned ? Icons.check_circle : Icons.block,
                    size: 16,
                    color: isBanned ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(isBanned ? 'Unban User' : 'Ban User',
                    style: TextStyle(
                      color: isBanned ? Colors.green : Colors.red)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'notify',
              child: Row(
                children: [
                  Icon(Icons.notifications, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Send Notification',
                    style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(QueryDocumentSnapshot doc, String action) async {
    final data = doc.data() as Map<String, dynamic>;
    final username = data['username'] ?? 'Unknown';

    if (action == 'view') {
      _showUserDetails(doc);
    } else if (action == 'ban' || action == 'unban') {
      final isBanning = action == 'ban';
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isBanning ? 'Ban User?' : 'Unban User?'),
          content: Text(isBanning
            ? 'Ban @$username? They will be forced to logout and cannot access the app.'
            : 'Unban @$username? They will be able to use the app again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isBanning ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(isBanning ? 'Ban' : 'Unban'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      try {
        await FirebaseFirestore.instance
            .collection('users').doc(doc.id)
            .update({'isBanned': isBanning});

        // Notify user
        await FirebaseFirestore.instance
            .collection('users').doc(doc.id)
            .collection('notifications').add({
          'type': 'admin_action',
          'title': isBanning ? 'Account banned' : 'Account restored',
          'body': isBanning
            ? 'Your account has been banned by an administrator.'
            : 'Your account has been restored.',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBanning
              ? '@$username banned'
              : '@$username restored'),
            backgroundColor: isBanning ? Colors.red : Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
            backgroundColor: Colors.red),
        );
      }
    } else if (action == 'notify') {
      _showSendNotificationDialog(doc.id, username);
    }
  }

  void _showUserDetails(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('@${data['username']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('UID', doc.id),
              _detailRow('Email', data['email'] ?? '-'),
              _detailRow('Bio', data['bio'] ?? '-'),
              _detailRow('Partnerships', '${data['partnershipCount'] ?? 0}'),
              _detailRow('Online', '${data['isOnline'] ?? false}'),
              _detailRow('Banned', '${data['isBanned'] ?? false}'),
              _detailRow('Created',
                data['createdAt'] != null
                  ? DateFormat('MMM d, y').format(
                      (data['createdAt'] as Timestamp).toDate())
                  : '-'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              )),
          ),
          Expanded(
            child: SelectableText(value,
              style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showSendNotificationDialog(String uid, String username) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send Notification to @$username'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
              try {
                await FirebaseFirestore.instance
                    .collection('users').doc(uid)
                    .collection('notifications').add({
                  'type': 'admin_message',
                  'title': titleCtrl.text,
                  'body': bodyCtrl.text,
                  'isRead': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification sent!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'),
                    backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 3: REPORTS (reuse the existing AdminPanelScreen content)
// ============================================================
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    // Simply embed the existing admin panel screen as the reports tab
    return const AdminPanelScreen();
  }
}

// ============================================================
// TAB 4: POSTS
// ============================================================
class _PostsTab extends StatefulWidget {
  const _PostsTab();
  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[100],
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search posts by content...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts').limit(200).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var docs = snap.data!.docs.toList();

              if (_query.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final content = (data['content'] ?? '').toString().toLowerCase();
                  return content.contains(_query);
                }).toList();
              }

              if (docs.isEmpty) {
                return const Center(
                  child: Text('No posts found',
                    style: TextStyle(color: Colors.grey)));
              }

              // Sort by createdAt desc
              docs.sort((a, b) {
                final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                if (ta == null && tb == null) return 0;
                if (ta == null) return 1;
                if (tb == null) return -1;
                return tb.compareTo(ta);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) => _postTile(docs[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _postTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final username = data['username'] ?? 'Unknown';
    final content = data['content'] ?? '';
    final likes = data['likesCount'] ?? 0;
    final comments = data['commentsCount'] ?? 0;
    final views = data['viewsCount'] ?? 0;
    final createdAt = data['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                if (createdAt != null)
                  Text(_timeAgo(createdAt),
                    style: TextStyle(
                      fontSize: 11, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text(content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                _statPill(Icons.favorite, '$likes', Colors.pink),
                const SizedBox(width: 12),
                _statPill(Icons.chat_bubble, '$comments', Colors.blue),
                const SizedBox(width: 12),
                _statPill(Icons.visibility, '$views', Colors.grey),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  tooltip: 'Delete Post',
                  onPressed: () => _deletePost(doc),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(value,
          style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  Future<void> _deletePost(QueryDocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text(
          'This permanently deletes the post and all its likes and comments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // Delete likes subcollection
      final likes = await doc.reference.collection('likes').get();
      for (final l in likes.docs) {
        await l.reference.delete();
      }
      // Delete comments subcollection
      final comments = await doc.reference.collection('comments').get();
      for (final c in comments.docs) {
        await c.reference.delete();
      }
      // Delete views subcollection
      final views = await doc.reference.collection('views').get();
      for (final v in views.docs) {
        await v.reference.delete();
      }
      // Delete post
      await doc.reference.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted'),
          backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'),
          backgroundColor: Colors.red),
      );
    }
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ============================================================
// TAB 5: BROADCAST
// ============================================================
class _BroadcastTab extends StatefulWidget {
  const _BroadcastTab();
  @override
  State<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<_BroadcastTab> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _target = 'all';
  String _priority = 'normal';
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required'),
          backgroundColor: Colors.orange),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Broadcast?'),
        content: Text(
          'Send "${_titleCtrl.text}" to $_target users?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _sending = true);
    try {
      // Get target users
      Query query = FirebaseFirestore.instance.collection('users');
      if (_target == 'online') {
        query = query.where('isOnline', isEqualTo: true);
      } else if (_target == 'banned') {
        query = query.where('isBanned', isEqualTo: true);
      } else if (_target == 'not_banned') {
        query = query.where('isBanned', isEqualTo: false);
      }

      final users = await query.limit(1000).get();

      // Batch write
      int batches = 0;
      WriteBatch? batch;
      int inBatch = 0;

      for (final userDoc in users.docs) {
        batch ??= FirebaseFirestore.instance.batch();
        final notifRef = userDoc.reference
            .collection('notifications').doc();
        batch.set(notifRef, {
          'type': 'broadcast',
          'title': _titleCtrl.text.trim(),
          'body': _bodyCtrl.text.trim(),
          'priority': _priority,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        inBatch++;
        if (inBatch >= 490) {
          await batch.commit();
          batches++;
          batch = null;
          inBatch = 0;
        }
      }
      if (batch != null) {
        await batch.commit();
        batches++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent to ${users.docs.length} users'),
          backgroundColor: Colors.green,
        ),
      );
      _titleCtrl.clear();
      _bodyCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'),
          backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Send Announcement to Users',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Send a broadcast notification to selected user groups.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 20),

          // Target selection
          const Text('Send to:',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _targetChip('all', 'All Users'),
              _targetChip('online', 'Online Only'),
              _targetChip('not_banned', 'Active Users'),
              _targetChip('banned', 'Banned Users'),
            ],
          ),
          const SizedBox(height: 20),

          // Priority
          const Text('Priority:',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _priorityChip('normal', 'Normal', Colors.blue),
              _priorityChip('important', 'Important', Colors.orange),
              _priorityChip('urgent', 'Urgent', Colors.red),
            ],
          ),
          const SizedBox(height: 20),

          // Title + body
          TextField(
            controller: _titleCtrl,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. New feature announcement',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            maxLength: 500,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Message',
              hintText: 'Type your announcement here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send),
              label: Text(_sending ? 'Sending...' : 'Send Broadcast'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Preview
          const Text('Preview:',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.withValues(alpha: 0.15),
                child: const Icon(Icons.campaign,
                  color: Colors.deepPurple, size: 20),
              ),
              title: Text(_titleCtrl.text.isEmpty
                  ? 'Your title'
                  : _titleCtrl.text,
                style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_bodyCtrl.text.isEmpty
                  ? 'Your message'
                  : _bodyCtrl.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetChip(String value, String label) {
    final selected = _target == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _target = value),
    );
  }

  Widget _priorityChip(String value, String label, Color color) {
    final selected = _priority == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.2),
      onSelected: (_) => setState(() => _priority = value),
    );
  }
}

