import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'splash_screen.dart';
import 'settings_screen.dart';
import 'admin_panel_screen.dart';
import 'chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout',
              style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
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
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile',
          style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('User data not found'));
          }
          final data = snap.data!.data() as Map<String, dynamic>;
          final username = data['username'] ?? 'Unknown';
          final bio = data['bio'] ?? '';
          final partnershipCount = data['partnershipCount'] ?? 0;
          final isOnline = data['isOnline'] ?? false;

          // The ENTIRE body is a single scroll view.
          // Tabs become sections instead of a TabBarView.
          return DefaultTabController(
            length: 3,
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: _profileHeader(
                    username: username,
                    bio: bio,
                    isOnline: isOnline,
                    partnershipCount: partnershipCount,
                  ),
                ),
                SliverPersistentHeader(
                  delegate: _TabBarDelegate(
                    TabBar(
                      labelColor: Colors.blue[700],
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blue[700],
                      tabs: const [
                        Tab(text: 'Posts'),
                        Tab(text: 'Partnerships'),
                        Tab(text: 'Contract'),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ],
              body: TabBarView(
                children: [
                  _postsTab(),
                  _partnershipsTab(),
                  _contractTab(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============ HEADER ============
  Widget _profileHeader({
    required String username,
    required String bio,
    required bool isOnline,
    required int partnershipCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: Colors.blue[100],
                child: Text(
                  username.isNotEmpty
                    ? username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 2, bottom: 2,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white, width: 3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Stats + Admin + Logout in compact form
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statPill('🤝', '$partnershipCount'),
              const SizedBox(width: 8),
              _postsPill(uid),
            ],
          ),
          const SizedBox(height: 12),
          // Admin panel button (if admin)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('admins').doc(uid).snapshots(),
            builder: (context, adminSnap) {
              if (!adminSnap.hasData ||
                  !adminSnap.data!.exists) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                        builder: (_) => const AdminPanelScreen())),
                    icon: const Icon(Icons.admin_panel_settings,
                      color: Colors.deepPurple, size: 18),
                    label: const Text('Admin Panel',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      )),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: Colors.deepPurple[200]!),
                      backgroundColor: Colors.deepPurple[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              );
            },
          ),

        ],
      ),
    );
  }

  Widget _statPill(String emoji, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            )),
          const SizedBox(width: 4),
          const Text('partnerships',
            style: TextStyle(fontSize: 11, color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _postsPill(String? userUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userUid)
          .limit(500)
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📝', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text('$count',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                )),
              const SizedBox(width: 4),
              Text('posts',
                style: TextStyle(
                  fontSize: 11, color: Colors.grey[700])),
            ],
          ),
        );
      },
    );
  }

  // ============ TAB 1: MY POSTS ============
  Widget _postsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _emptyState(
            icon: Icons.article_outlined,
            title: 'No posts yet',
            subtitle: 'Create your first post from the feed!',
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

        return ListView.builder(
          padding: const EdgeInsets.only(top: 6, bottom: 20),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final post = PostModel.fromDoc(docs[i]);
            return PostCard(post: post, onDelete: () {});
          },
        );
      },
    );
  }

  // ============ TAB 2: MY PARTNERSHIPS ============
  Widget _partnershipsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partnerships')
          .where('userA', whereIn: [uid])
          .limit(200)
          .snapshots(),
      builder: (context, snapA) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('partnerships')
              .where('userB', whereIn: [uid])
              .limit(200)
              .snapshots(),
          builder: (context, snapB) {
            final all = <QueryDocumentSnapshot>[];
            if (snapA.hasData) all.addAll(snapA.data!.docs);
            if (snapB.hasData) all.addAll(snapB.data!.docs);

            final seen = <String>{};
            final unique = <QueryDocumentSnapshot>[];
            for (final d in all) {
              if (seen.add(d.id)) unique.add(d);
            }

            unique.sort((a, b) {
              final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return tb.compareTo(ta);
            });

            if (unique.isEmpty) {
              return _emptyState(
                icon: Icons.handshake_outlined,
                title: 'No partnerships yet',
                subtitle: 'Partner up with someone to see it here!',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: unique.length,
              itemBuilder: (_, i) => _partnershipCard(unique[i]),
            );
          },
        );
      },
    );
  }

  Widget _partnershipCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userA = data['userA'] as String? ?? '';
    final userB = data['userB'] as String? ?? '';
    final usernameA = data['usernameA'] ?? 'User';
    final usernameB = data['usernameB'] ?? 'User';
    final reason = data['reason'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final isReported = data['isReported'] == true;

    final otherUserId = userA == uid ? userB : userA;
    final otherUsername = userA == uid ? usernameB : usernameA;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    otherUsername.isNotEmpty
                      ? otherUsername[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(otherUsername,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        )),
                      if (createdAt != null)
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                if (isReported)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: const Text('REPORTED',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      )),
                  ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline,
                    size: 18, color: Colors.blue),
                  tooltip: 'Chat',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ChatScreen(
                      otherUserId: otherUserId,
                      otherUsername: otherUsername,
                    )),
                  ),
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.description_outlined,
                      size: 13, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(reason,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============ TAB 3: CONTRACT ============
  Widget _contractTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('PARTNERSHIP AGREEMENT',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 14),
          Text('By using PartnerUp, you agree to the following:',
            style: TextStyle(fontSize: 14)),
          SizedBox(height: 12),
          Text('1. PARTNERSHIP RULE:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(
            'Once you and another user agree to a partnership by both '
            'clicking "PARTNER" in the 15-minute partnership popup, you '
            'are entering a binding agreement.',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 12),
          Text('2. NO BACKING OUT:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(
            'You cannot cancel or back out of a partnership agreement '
            'without the mutual written consent of both parties.',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 12),
          Text('3. CONSEQUENCES OF VIOLATION:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(
            'If you back out without mutual agreement, the other party '
            'may report you.\n'
            '- You will have 80 hours to submit proof of your innocence.\n'
            '- If you fail to submit proof, your account will be flagged as '
            'CHEATER and displayed on the Cheater Board.\n'
            '- After 36 hours on the board, your account will be '
            'permanently deleted.\n'
            '- All your past partners will be notified.',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 12),
          Text('4. REPORTING:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(
            'If you believe someone violated this agreement, you must '
            'submit both a reason and proof with your report.',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 12),
          Text('5. ACCOUNT TERMINATION:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(
            'PartnerUp reserves the right to terminate any account that '
            'violates this agreement without prior notice.',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 12),
          Text('6. DATA USAGE:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(
            'Your data will be stored securely and used only for app '
            'functionality.',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 30),
          Center(
            child: Text(
              'You agreed to this contract at signup.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ EMPTY STATE (scrollable) ============
  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    // Use a scrollable so it never overflows even on tiny viewports
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey, fontSize: 15)),
                const SizedBox(height: 6),
                Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    return DateFormat('MMM d, y').format(d);
  }
}

// Helper to pin a TabBar
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset,
      bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

