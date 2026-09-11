import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'splash_screen.dart';
import 'activity_screen.dart';
import 'change_screens.dart';
import 'blocked_users_screen.dart';
import 'delete_account_screen.dart';
import '../services/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  bool _showOnlineStatus = true;
  bool _allowChatFromAnyone = true;
  bool _notifyLikes = true;
  bool _notifyComments = true;
  bool _notifyPartnerships = true;
  bool _notifyReports = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      final prefs = doc.data()?['settings'] as Map<String, dynamic>?;
      if (prefs != null && mounted) {
        setState(() {
          _showOnlineStatus = prefs['showOnlineStatus'] != false;
          _allowChatFromAnyone = prefs['allowChatFromAnyone'] != false;
          _notifyLikes = prefs['notifyLikes'] != false;
          _notifyComments = prefs['notifyComments'] != false;
          _notifyPartnerships = prefs['notifyPartnerships'] != false;
          _notifyReports = prefs['notifyReports'] != false;
        });
      }
    } catch (e) {
      debugPrint('[Settings] load error: $e');
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(uid).set({
        'settings': {key: value},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Settings] save error: $e');
    }
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

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Language',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.check, color: Colors.blue),
              title: const Text('English'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('Coming soon: More languages'),
              enabled: false,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeCtrl = ThemeController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          _sectionHeader('Account'),
          _menuTile(Icons.email_outlined, 'Change Email',
            () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ChangeEmailScreen()))),
          _menuTile(Icons.lock_outline, 'Change Password',
            () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ChangePasswordScreen()))),
          _menuTile(Icons.person_outline, 'Change Username',
            () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ChangeUsernameScreen())),
            subtitle: 'Max 1 change per month'),

          _sectionHeader('Activity'),
          _menuTile(Icons.favorite, 'Posts I Liked',
            () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ActivityScreen(
                type: ActivityType.likes))),
            iconColor: Colors.pink),
          _menuTile(Icons.chat_bubble, 'Posts I Commented On',
            () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ActivityScreen(
                type: ActivityType.comments))),
            iconColor: Colors.blue),
          _menuTile(Icons.handshake, 'My Partnerships',
            () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ActivityScreen(
                type: ActivityType.partnerships))),
            iconColor: Colors.green),

          _sectionHeader('Privacy'),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('Show Online Status'),
            subtitle: const Text('Others can see when you\'re online'),
            value: _showOnlineStatus,
            onChanged: (v) {
              setState(() => _showOnlineStatus = v);
              _saveSetting('showOnlineStatus', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.chat_outlined),
            title: const Text('Allow Chat from Anyone'),
            subtitle: const Text('If off, only partners can chat'),
            value: _allowChatFromAnyone,
            onChanged: (v) {
              setState(() => _allowChatFromAnyone = v);
              _saveSetting('allowChatFromAnyone', v);
            },
          ),

          _sectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.favorite_outline),
            title: const Text('Likes'),
            value: _notifyLikes,
            onChanged: (v) {
              setState(() => _notifyLikes = v);
              _saveSetting('notifyLikes', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.chat_bubble_outline),
            title: const Text('Comments'),
            value: _notifyComments,
            onChanged: (v) {
              setState(() => _notifyComments = v);
              _saveSetting('notifyComments', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.handshake_outlined),
            title: const Text('Partnerships'),
            value: _notifyPartnerships,
            onChanged: (v) {
              setState(() => _notifyPartnerships = v);
              _saveSetting('notifyPartnerships', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.report_outlined),
            title: const Text('Reports'),
            value: _notifyReports,
            onChanged: (v) {
              setState(() => _notifyReports = v);
              _saveSetting('notifyReports', v);
            },
          ),

          _sectionHeader('Contract'),
          _menuTile(Icons.description_outlined, 'View My Contract',
            () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ViewContractScreen()))),

          _sectionHeader('App'),
          // ---- DARK MODE (instant) ----
          AnimatedBuilder(
            animation: themeCtrl,
            builder: (context, _) {
              return SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark Mode'),
                subtitle: const Text('Applies instantly'),
                value: themeCtrl.isDarkMode,
                onChanged: (v) => themeCtrl.setDarkMode(v),
              );
            },
          ),
          _menuTile(Icons.language_outlined, 'Language',
            _showLanguagePicker,
            subtitle: 'English'),
          _menuTile(Icons.cleaning_services_outlined, 'Clear Cache',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared!'),
                  backgroundColor: Colors.green,
                ));
            }),

          _sectionHeader('Privacy & Safety'),
          _menuTile(Icons.block, 'Blocked Users',
            () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const BlockedUsersScreen())),
            iconColor: Colors.red),

          _sectionHeader('Account Actions'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              )),
            onTap: _logout,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete My Account',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              )),
            subtitle: const Text(
              'Permanently removes all your data',
              style: TextStyle(fontSize: 11),
            ),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const DeleteAccountScreen())),
          ),

          _sectionHeader('Support'),
          _menuTile(Icons.help_outline, 'Help Center',
            () => _infoDialog('Help Center',
              'For help, contact support@partnerup.com')),
          _menuTile(Icons.bug_report_outlined, 'Report a Bug',
            () => _infoDialog('Report a Bug',
              'Send bug reports to bugs@partnerup.com')),
          _menuTile(Icons.contact_support_outlined, 'Contact Support',
            () => _infoDialog('Contact Support',
              'Email: support@partnerup.com')),
        ],
      ),
    );
  }

  void _infoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
          letterSpacing: 0.5,
        )),
    );
  }

  Widget _menuTile(
    IconData icon,
    String label,
    VoidCallback onTap, {
    String? subtitle,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label,
        style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

