import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _showOnlineStatus = true;
  bool _allowChatFromAnyone = true;
  bool _notifyLikes = true;
  bool _notifyComments = true;
  bool _notifyPartnerships = true;
  bool _notifyReports = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          _sectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Change Email'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _comingSoon(),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _comingSoon(),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Change Username'),
            subtitle: const Text('Max 1 change per month'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _comingSoon(),
          ),

          _sectionHeader('Privacy'),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('Show Online Status'),
            value: _showOnlineStatus,
            onChanged: (v) => setState(() => _showOnlineStatus = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.chat_outlined),
            title: const Text('Allow Chat from Anyone'),
            subtitle: const Text('If off, only partners can chat'),
            value: _allowChatFromAnyone,
            onChanged: (v) => setState(() => _allowChatFromAnyone = v),
          ),

          _sectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.favorite_outline),
            title: const Text('Likes'),
            value: _notifyLikes,
            onChanged: (v) => setState(() => _notifyLikes = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.chat_bubble_outline),
            title: const Text('Comments'),
            value: _notifyComments,
            onChanged: (v) => setState(() => _notifyComments = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.handshake_outlined),
            title: const Text('Partnerships'),
            value: _notifyPartnerships,
            onChanged: (v) => setState(() => _notifyPartnerships = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.report_outlined),
            title: const Text('Reports'),
            value: _notifyReports,
            onChanged: (v) => setState(() => _notifyReports = v),
          ),

          _sectionHeader('Contract'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('View My Contract'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _comingSoon(),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Download Contract (PDF)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _comingSoon(),
          ),

          _sectionHeader('App'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v),
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('Language'),
            subtitle: const Text('English'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _comingSoon(),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear Cache'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared!')));
            },
          ),

          _sectionHeader('Support'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help Center'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _comingSoon(),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Report a Bug'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _comingSoon(),
          ),
          ListTile(
            leading: const Icon(Icons.contact_support_outlined),
            title: const Text('Contact Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _comingSoon(),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
        )),
    );
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon!')));
  }
}
