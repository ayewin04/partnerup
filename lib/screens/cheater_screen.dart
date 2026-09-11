import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CheaterScreen extends StatelessWidget {
  const CheaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cheater Board',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .limit(500)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Error loading reports',
                  style: TextStyle(color: Colors.red)),
              ),
            );
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user,
                    size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text('Cheater Board is empty',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('No users have been flagged recently.',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            );
          }

          // ---- FILTER IN DART: only cheaters ----
          final docs = snap.data!.docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] == 'cheater';
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user,
                    size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text('Cheater Board is empty',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          // Sort by cheaterAt desc
          docs.sort((a, b) {
            final ta = (a.data() as Map<String, dynamic>)['cheaterAt'] as Timestamp?;
            final tb = (b.data() as Map<String, dynamic>)['cheaterAt'] as Timestamp?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[100]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                      color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'These users broke the partnership contract. '
                        'Their accounts will be deleted after 36 hours.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _cheaterCard(docs[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cheaterCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final reportedUsername = data['reportedUsername'] ?? 'Unknown';
    final reason = data['reason'] ?? '';
    final reporterUsername = data['reporterUsername'] ?? 'Unknown';
    final cheaterAt = data['cheaterAt'] as Timestamp?;
    final deleteAt = data['deleteAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red[100]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.red[100],
                  child: Text(
                    reportedUsername.isNotEmpty
                      ? reportedUsername[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('@$reportedUsername',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.red,
                        )),
                      if (cheaterAt != null)
                        Text(
                          'Flagged ${_timeAgo(cheaterAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('CHEATER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    )),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reason
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reason:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    )),
                  const SizedBox(height: 4),
                  Text(reason,
                    style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Reported by @$reporterUsername',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),

            if (deleteAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer,
                    size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    'Account deletes in ${_remaining(deleteAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _remaining(Timestamp ts) {
    final diff = ts.toDate().difference(DateTime.now());
    if (diff.isNegative) return 'soon';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }
}

