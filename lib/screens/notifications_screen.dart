import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications',
          style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Mark all as read
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users').doc(_currentUserId)
                .collection('notifications')
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              final unread = snap.data?.docs.length ?? 0;
              if (unread == 0) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () => _markAllAsRead(unread),
                icon: const Icon(Icons.done_all,
                  color: Colors.white, size: 18),
                label: const Text('Mark all read',
                  style: TextStyle(
                    color: Colors.white, fontSize: 12)),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(_currentUserId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                    size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('We\'ll notify you about partnerships, likes, and more.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            );
          }

          final docs = snap.data!.docs;

          // Group by date
          final grouped = <String, List<QueryDocumentSnapshot>>{};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['createdAt'] as Timestamp?;
            final label = ts != null ? _dateGroupLabel(ts) : 'Earlier';
            grouped.putIfAbsent(label, () => []).add(doc);
          }

          // Build flat list with headers
          final items = <Widget>[];
          for (final entry in grouped.entries) {
            items.add(_sectionHeader(entry.key));
            for (final doc in entry.value) {
              items.add(_notificationRow(doc));
            }
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: items,
          );
        },
      ),
    );
  }

  // ============ MARK ALL AS READ ============
  Future<void> _markAllAsRead(int count) async {
    try {
      final unread = await FirebaseFirestore.instance
          .collection('users').doc(_currentUserId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked $count as read'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Notif] mark all error: $e');
    }
  }

  // ============ MARK SINGLE AS READ ============
  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(_currentUserId)
          .collection('notifications').doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('[Notif] mark one error: $e');
    }
  }

  // ============ ROW RENDERER ============
  Widget _notificationRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] ?? 'info';
    final title = data['title'] ?? 'Notification';
    final body = data['body'] ?? '';
    final isRead = data['isRead'] == true;
    final ts = data['createdAt'] as Timestamp?;
    final extra = data['data'] as Map<String, dynamic>?;

    final visual = _visualFor(type);

    return Material(
      color: isRead
      ? Theme.of(context).cardColor
      : (Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A2A3A)
          : Colors.blue[50]),
      child: InkWell(
        onTap: () async {
          if (!isRead) await _markAsRead(doc.id);
          _handleTap(type, extra);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(visual.icon,
                  color: visual.color, size: 20),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: isRead
                                  ? Colors.black87 : Colors.black,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ts != null ? _shortTime(ts) : '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ TAP HANDLER ============
  void _handleTap(String type, Map<String, dynamic>? extra) {
    if (extra == null) return;

    // Navigate based on notification type
    final chatId = extra['chatId'] as String?;
    final otherUserId = extra['otherUserId'] as String?;
    final otherUsername = extra['otherUsername'] as String?;

    if (chatId != null && otherUserId != null && otherUsername != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(
          otherUserId: otherUserId,
          otherUsername: otherUsername,
        ),
      ));
      return;
    }

    // Future: handle other types (post, partnership, etc.)
  }

  // ============ HELPERS ============
  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark
      ? Colors.lightBlueAccent
      : Colors.blue[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _dateGroupLabel(Timestamp ts) {
    final d = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notifDay = DateTime(d.year, d.month, d.day);
    final diff = today.difference(notifDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This Week';
    if (diff < 30) return 'This Month';
    return 'Earlier';
  }

  String _shortTime(Timestamp ts) {
    final d = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && now.day == d.day) {
      return '${diff.inHours}h ago';
    }
    if (now.difference(d).inDays == 1) return 'Yesterday';
    if (now.difference(d).inDays < 7) {
      return DateFormat('EEE HH:mm').format(d);
    }
    return DateFormat('MMM d').format(d);
  }

  _NotificationVisual _visualFor(String type) {
    switch (type) {
      case 'partnership_accepted':
        return _NotificationVisual(
          Icons.handshake, Colors.green);
      case 'partnership_cancelled':
        return _NotificationVisual(
          Icons.cancel, Colors.red);
      case 'partnership_expired':
        return _NotificationVisual(
          Icons.timer_off, Colors.orange);
      case 'like':
        return _NotificationVisual(
          Icons.favorite, Colors.pink);
      case 'comment':
        return _NotificationVisual(
          Icons.chat_bubble, Colors.blue);
      case 'follow':
        return _NotificationVisual(
          Icons.person_add, Colors.purple);
      case 'report_submitted':
        return _NotificationVisual(
          Icons.report, Colors.orange);
      case 'report_received':
        return _NotificationVisual(
          Icons.warning_amber, Colors.red);
      case 'report_proof_submitted':
        return _NotificationVisual(
          Icons.description, Colors.blue);
      case 'report_accepted':
      case 'admin_action':
        return _NotificationVisual(
          Icons.verified, Colors.green);
      case 'partner_became_cheater':
        return _NotificationVisual(
          Icons.gpp_bad, Colors.red);
      default:
        return _NotificationVisual(
          Icons.notifications, Colors.blueGrey);
    }
  }
}

class _NotificationVisual {
  final IconData icon;
  final Color color;
  const _NotificationVisual(this.icon, this.color);
}


