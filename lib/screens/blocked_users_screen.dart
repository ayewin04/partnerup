import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/block_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});
  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('blockedUsers')
            .orderBy('blockedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.block,
                          size: 60, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('You haven\'t blocked anyone',
                          style: TextStyle(
                            color: Colors.grey, fontSize: 15)),
                        SizedBox(height: 6),
                        Text(
                          'Block users from the chat menu (⋮).',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: snap.data!.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _blockedRow(snap.data!.docs[i]),
          );
        },
      ),
    );
  }

  Widget _blockedRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final blockedUserId = data['userId'] ?? '';
    final username = data['username'] ?? 'Unknown';
    final blockedAt = data['blockedAt'] as Timestamp?;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.red[100],
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ),
        title: Text('@$username',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: blockedAt != null
          ? Text(
              'Blocked ${DateFormat('MMM d, y').format(blockedAt.toDate())}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]))
          : null,
        trailing: TextButton(
          onPressed: () => _unblock(blockedUserId, username),
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue,
          ),
          child: const Text('Unblock'),
        ),
      ),
    );
  }

  Future<void> _unblock(String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unblock User?'),
        content: Text('Unblock @$username? '
            'They will be able to message you again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await BlockService.unblockUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('@$username unblocked'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'),
          backgroundColor: Colors.red),
      );
    }
  }
}
