import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PartnershipSheet extends StatelessWidget {
  final String currentUserId;
  final String otherUserId;
  final String otherUsername;

  const PartnershipSheet({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUsername,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.handshake, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Partnerships with $otherUsername',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('partnerships')
                  .where('userA', whereIn: [currentUserId, otherUserId])
                  .limit(100)
                  .snapshots(),
              builder: (context, snapA) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('partnerships')
                      .where('userB', whereIn: [currentUserId, otherUserId])
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapB) {
                    // Merge both sides
                    final all = <QueryDocumentSnapshot>[];
                    if (snapA.hasData) all.addAll(snapA.data!.docs);
                    if (snapB.hasData) all.addAll(snapB.data!.docs);

                    // Dedupe + filter to only partnerships between these 2
                    final seen = <String>{};
                    final relevant = <QueryDocumentSnapshot>[];
                    for (final d in all) {
                      if (!seen.add(d.id)) continue;
                      final data = d.data() as Map<String, dynamic>;
                      final a = data['userA'];
                      final b = data['userB'];
                      if ((a == currentUserId && b == otherUserId) ||
                          (a == otherUserId && b == currentUserId)) {
                        relevant.add(d);
                      }
                    }

                    // Sort by createdAt desc
                    relevant.sort((a, b) {
                      final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      if (ta == null && tb == null) return 0;
                      if (ta == null) return 1;
                      if (tb == null) return -1;
                      return tb.compareTo(ta);
                    });

                    if (relevant.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.handshake_outlined,
                                size: 60, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No partnerships yet',
                                style: TextStyle(
                                  fontSize: 15, color: Colors.grey)),
                              SizedBox(height: 6),
                              Text(
                                'Partner up from the chat to see agreements here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Header stats
                    final total = relevant.length;
                    final activeCount = relevant.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['isActive'] != false;
                    }).length;
                    final reportedCount = relevant.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['isReported'] == true;
                    }).length;

                    return Column(
                      children: [
                        // Stats bar
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                          color: Colors.blue[50],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Flexible(child: _statChip('🤝', '$total', 'Total')),
                              Flexible(child: _statChip('✅', '$activeCount', 'Active')),
                              Flexible(child: _statChip('⚠️', '$reportedCount', 'Reported')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Partnership list
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: relevant.length,
                            itemBuilder: (_, i) => _partnershipItem(
                              context, relevant[i], i + 1, total - i,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String emoji, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          )),
        Text(label,
          style: TextStyle(fontSize: 10, color: Colors.grey[700])),
      ],
    );
  }

  Widget _partnershipItem(
    BuildContext context,
    QueryDocumentSnapshot doc,
    int index,
    int displayNumber,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final reason = data['reason'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final isReported = data['isReported'] == true;
    final isActive = data['isActive'] != false;

    String statusLabel;
    Color statusColor;
    IconData statusIcon;

    if (isReported) {
      statusLabel = 'REPORTED';
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber;
    } else if (isActive) {
      statusLabel = 'ACTIVE';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusLabel = 'ENDED';
      statusColor = Colors.grey;
      statusIcon = Icons.cancel;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isReported
              ? Colors.orange[200]!
              : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Partnership #$displayNumber',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 10, color: statusColor),
                      const SizedBox(width: 3),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Reason
            if (reason.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.description_outlined,
                    size: 14, color: Colors.grey[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Date
            if (createdAt != null)
              Row(
                children: [
                  Icon(Icons.calendar_today,
                    size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Agreed on ${DateFormat('MMM d, y').format(createdAt.toDate())}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}


