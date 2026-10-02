import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/paginated_list_view.dart';
import 'chat_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final _key = GlobalKey<PaginatedListViewState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard',
          style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _key.currentState?.refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          _myRankBanner(),
          Expanded(
            child: PaginatedListView(
              key: _key,
              pageSize: 20,
              firstPageQuery: () => FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('partnershipCount', descending: true)
                  .limit(20),
              nextPageLoader: (lastDoc) => FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('partnershipCount', descending: true)
                  .startAfterDocument(lastDoc)
                  .limit(20),
              itemBuilder: (context, doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['isBanned'] == true) {
                  return const SizedBox.shrink();
                }
                return _leaderboardRow(
                  uid: doc.id,
                  username: data['username'] ?? 'Unknown',
                  partnershipCount: data['partnershipCount'] ?? 0,
                  isOnline: data['isOnline'] == true,
                  isMe: doc.id == _currentUserId,
                );
              },
              emptyBuilder: (context) => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events_outlined,
                      size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No rankings yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _myRankBanner() {
    if (_currentUserId == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(_currentUserId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snap.data!.data() as Map<String, dynamic>;
        final myCount = data['partnershipCount'] ?? 0;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Row(
            children: [
              const Icon(Icons.person, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🤝 $myCount partnerships',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _leaderboardRow({
    required String uid,
    required String username,
    required int partnershipCount,
    required bool isOnline,
    required bool isMe,
  }) {
    return InkWell(
      onTap: () {
        if (isMe) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUserId: uid,
            otherUsername: username,
          ),
        ));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.blue : Colors.grey[200]!,
            width: isMe ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isMe ? '$username (You)' : username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '🤝 $partnershipCount partnership${partnershipCount == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            if (!isMe)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline,
                  color: Colors.blue, size: 20),
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ChatScreen(
                    otherUserId: uid,
                    otherUsername: username,
                  )),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.star, color: Colors.amber, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
