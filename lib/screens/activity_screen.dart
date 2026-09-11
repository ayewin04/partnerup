import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'chat_screen.dart';

enum ActivityType { likes, comments, partnerships }

class ActivityScreen extends StatefulWidget {
  final ActivityType type;
  const ActivityScreen({super.key, required this.type});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  String get _title {
    switch (widget.type) {
      case ActivityType.likes:
        return 'Posts I Liked';
      case ActivityType.comments:
        return 'Posts I Commented On';
      case ActivityType.partnerships:
        return 'My Partnerships';
    }
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
        title: Text(_title,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (widget.type) {
      case ActivityType.likes:
        return _mirroredList('activityLikes');
      case ActivityType.comments:
        return _mirroredList('activityComments');
      case ActivityType.partnerships:
        return _partnershipsList();
    }
  }

  // ============ MIRRORED LIKES / COMMENTS ============
  // Reads from users/{uid}/activityLikes or activityComments
  // Uses single where + orderBy on same collection = no composite index needed.
  Widget _mirroredList(String collection) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _errorState('${snap.error}');
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _emptyState(
            icon: widget.type == ActivityType.likes
                ? Icons.favorite_border
                : Icons.chat_bubble_outline,
            text: widget.type == ActivityType.likes
                ? 'You haven\'t liked any posts yet'
                : 'You haven\'t commented on any posts yet',
          );
        }

        final docs = snap.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 6, bottom: 20),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final postId = data['postId'] ?? '';
            return _postLoader(postId);
          },
        );
      },
    );
  }

  // ============ PARTNERSHIPS ============
  Widget _partnershipsList() {
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

            if (unique.isEmpty) {
              return _emptyState(
                icon: Icons.handshake_outlined,
                text: 'No partnerships yet',
              );
            }

            unique.sort((a, b) {
              final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return tb.compareTo(ta);
            });

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: unique.length,
              itemBuilder: (_, i) => _partnershipTile(unique[i]),
            );
          },
        );
      },
    );
  }

  Widget _partnershipTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userA = data['userA'] as String? ?? '';
    final userB = data['userB'] as String? ?? '';
    final usernameA = data['usernameA'] ?? 'User';
    final usernameB = data['usernameB'] ?? 'User';
    final reason = data['reason'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;

    final otherUserId = userA == uid ? userB : userA;
    final otherUsername = userA == uid ? usernameB : usernameA;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.blue[100],
          child: Text(
            otherUsername.isNotEmpty
              ? otherUsername[0].toUpperCase() : '?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        title: Text(otherUsername,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          )),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('MMM d, y').format(createdAt.toDate()),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.chat_bubble_outline,
            color: Colors.blue),
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ChatScreen(
              otherUserId: otherUserId,
              otherUsername: otherUsername,
            )),
          ),
        ),
      ),
    );
  }

  // ============ LOAD POST BY ID ============
  Widget _postLoader(String postId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts').doc(postId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }
        final post = PostModel.fromDoc(snap.data!);
        return PostCard(post: post);
      },
    );
  }

  // ============ HELPERS ============
  Widget _emptyState({required IconData icon, required String text}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 60, color: Colors.grey),
                const SizedBox(height: 12),
                Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Error: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}
