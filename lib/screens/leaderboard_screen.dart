import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;

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
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Simple query — no filter, no orderBy → no composite index needed.
        // We fetch up to 500 users (bigger than top 100) then sort in Dart.
        stream: FirebaseFirestore.instance
            .collection('users')
            .limit(500)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                      size: 60, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text('Failed to load leaderboard',
                      style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined,
                    size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No rankings yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Complete partnerships to appear here!',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            );
          }

          // ---- SORT + FILTER IN DART ----
          final allDocs = snap.data!.docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            // Filter out banned users
            return data['isBanned'] != true;
          }).toList();

          // Sort by partnershipCount desc
          allDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aCount = (aData['partnershipCount'] ?? 0) as int;
            final bCount = (bData['partnershipCount'] ?? 0) as int;
            return bCount.compareTo(aCount);
          });

          // Take top 100
          final users = allDocs.take(100).toList();

          // Find my rank in top 100
          int? myRank;
          for (int i = 0; i < users.length; i++) {
            if (users[i].id == _currentUserId) {
              myRank = i + 1;
              break;
            }
          }

          // If not in top 100, compute my rank among all users
          int? myGlobalRank;
          if (myRank == null && _currentUserId != null) {
            final myIndex = allDocs.indexWhere(
                (d) => d.id == _currentUserId);
            if (myIndex >= 0) {
              myGlobalRank = myIndex + 1;
            }
          }

          return Column(
            children: [
              _myRankBanner(myRank, myGlobalRank, users),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                    top: 4, bottom: 20),
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final doc = users[i];
                    final rank = i + 1;
                    final data = doc.data() as Map<String, dynamic>;
                    return _leaderboardRow(
                      rank: rank,
                      uid: doc.id,
                      username: data['username'] ?? 'Unknown',
                      partnershipCount:
                          data['partnershipCount'] ?? 0,
                      isOnline: data['isOnline'] == true,
                      isMe: doc.id == _currentUserId,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---- My rank banner ----
  Widget _myRankBanner(int? myRank, int? myGlobalRank,
      List<QueryDocumentSnapshot> users) {
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

        String rankText;
        if (myRank != null) {
          rankText = 'Your rank: #$myRank';
        } else if (myGlobalRank != null) {
          rankText = 'Your rank: #$myGlobalRank';
        } else {
          rankText = 'Your rank: not ranked yet';
        }

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rankText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text('🤝 $myCount partnerships',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- Row renderer ----
  Widget _leaderboardRow({
    required int rank,
    required String uid,
    required String username,
    required int partnershipCount,
    required bool isOnline,
    required bool isMe,
  }) {
    return InkWell(
      onTap: () {
        if (isMe) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You can't chat with yourself")));
          return;
        }
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUserId: uid,
            otherUsername: username,
          ),
        ));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
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
            SizedBox(
              width: 40,
              child: _rankBadge(rank),
            ),
            const SizedBox(width: 10),

            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    username.isNotEmpty
                      ? username[0].toUpperCase() : '?',
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
                        border: Border.all(
                          color: Colors.white, width: 2),
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '🤝 $partnershipCount partnership${partnershipCount == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            if (!isMe)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline,
                  color: Colors.blue, size: 20),
                tooltip: 'Chat',
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
                child: Icon(Icons.star,
                  color: Colors.amber, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rankBadge(int rank) {
    if (rank == 1) {
      return const Center(child: Text('🥇',
        style: TextStyle(fontSize: 24)));
    }
    if (rank == 2) {
      return const Center(child: Text('🥈',
        style: TextStyle(fontSize: 24)));
    }
    if (rank == 3) {
      return const Center(child: Text('🥉',
        style: TextStyle(fontSize: 24)));
    }

    return Center(
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: rank <= 10 ? Colors.blue[50] : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '#$rank',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: rank <= 10 ? Colors.blue[700] : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}
