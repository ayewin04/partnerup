import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'splash_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout',
              style: TextStyle(color: Colors.red))),
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
        ],
      ),
      body: uid == null
        ? const Center(child: Text('Not logged in'))
        : StreamBuilder<DocumentSnapshot>(
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

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue[100],
                          child: Text(
                            username.isNotEmpty
                              ? username[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 40, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isOnline)
                          Positioned(
                            right: 5, bottom: 5,
                            child: Container(
                              width: 20, height: 20,
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
                    const SizedBox(height: 16),
                    Text(username,
                      style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(bio,
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statCard('Partnerships', '$partnershipCount',
                          Icons.handshake),
                        _statCard('Posts', '-', Icons.article),
                        _statCard('Reports', '-', Icons.report),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _menuTile(Icons.article_outlined, 'My Posts',
                      () => _showComingSoon(context)),
                    _menuTile(Icons.handshake_outlined, 'My Partnerships',
                      () => _showComingSoon(context)),
                    _menuTile(Icons.description_outlined, 'My Contract',
                      () => _showComingSoon(context)),
                    _menuTile(Icons.settings_outlined, 'Settings',
                      () => Navigator.push(context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen()))),
                    _menuTile(Icons.logout, 'Logout', _logout,
                      color: Colors.red),
                    const SizedBox(height: 20),
                    const Text('Profile features (My Posts, My Partnerships)',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const Text('Coming in Screen 9',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue[700], size: 24),
          const SizedBox(height: 6),
          Text(value,
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(
            fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap,
    {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: color == null
        ? const Icon(Icons.chevron_right, color: Colors.grey)
        : null,
      onTap: onTap,
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming in future screens!')));
  }
}
