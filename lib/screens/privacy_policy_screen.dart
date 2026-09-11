import 'package:flutter/material.dart';
import 'contact_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String supportEmail = 'nextgenlearningmyanmar@gmail.com';
  static const String founder = 'Wedawon';
  static const String country = 'Myanmar';
  static const String lastUpdated = 'September 11, 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: const [
                Icon(Icons.privacy_tip, color: Colors.blue, size: 32),
                SizedBox(width: 10),
                Expanded(
                  child: Text('PartnerUp Privacy Policy',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    )),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Last updated: $lastUpdated',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              )),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            _section('1. Introduction',
              'PartnerUp ("we", "our", "us") is a social platform that '
              'helps users find partners for various activities. '
              'This Privacy Policy explains what information we collect, '
              'how we use it, how we protect it, and your rights.\n\n'
              'By using PartnerUp, you agree to this policy. '
              'If you do not agree, please do not use the app.'),

            _section('2. Information We Collect',
              'When you use PartnerUp, we collect:\n\n'
              '• **Account Information:** Username, email address, '
              'password (encrypted), and profile bio.\n\n'
              '• **Content:** Posts, comments, messages, and partnership '
              'information you create.\n\n'
              '• **Activity Data:** Likes, views, partnerships, reports, '
              'and login timestamps.\n\n'
              '• **Device Information:** Basic info needed to run the app '
              '(operating system, app version).\n\n'
              'We do NOT collect: phone numbers, addresses, photos, '
              'location, contacts, or payment information.'),

            _section('3. How We Use Your Information',
              'We use your information to:\n\n'
              '• Create and manage your account\n'
              '• Enable posting, chatting, and partnerships\n'
              '• Show your posts and profile to other users\n'
              '• Enforce our partnership rules and Cheater Board\n'
              '• Send you relevant notifications\n'
              '• Improve the app and fix bugs\n'
              '• Comply with legal obligations'),

            _section('4. Data Storage & Security',
              'Your data is stored on Google Firebase (Firestore and '
              'Firebase Authentication), which uses industry-standard '
              'encryption and security practices.\n\n'
              'We use:\n'
              '• Encrypted HTTPS connections\n'
              '• Firestore security rules\n'
              '• Firebase Authentication for password security\n\n'
              'No method of transmission over the internet is 100% secure. '
              'We cannot guarantee absolute security, but we take '
              'reasonable measures to protect your data.'),

            _section('5. Data Sharing',
              'We do NOT sell your data to third parties.\n\n'
              'Your data is shared only with:\n\n'
              '• **Other Users:** Your username, bio, posts, and public '
              'activity are visible to other users.\n\n'
              '• **Service Providers:** Google Firebase (our hosting '
              'provider).\n\n'
              '• **Legal Authorities:** If required by law.'),

            _section('6. Your Rights',
              'You have the right to:\n\n'
              '• Access your data through the app\n'
              '• Update your profile information\n'
              '• Delete your account (Settings → Delete My Account)\n'
              '• Opt out of notifications\n'
              '• Contact us with privacy concerns\n\n'
              'When you delete your account, we permanently delete your '
              'profile, posts, comments, chat messages, and partnerships.'),

            _section('7. Data Retention',
              'We retain your data while your account is active. '
              'When you delete your account:\n\n'
              '• Your personal data is deleted immediately\n'
              '• Reports involving you are anonymized (kept for records)\n'
              '• Backups are cleared within 30 days'),

            _section('8. Children\'s Privacy',
              'PartnerUp is not intended for users under 13 years old. '
              'We do not knowingly collect data from children under 13. '
              'If we discover such data, we will delete it immediately.\n\n'
              'If you are between 13 and 18, please use PartnerUp only '
              'with parental consent.'),

            _section('9. International Users',
              'PartnerUp is developed by $founder in $country. '
              'Your data may be stored on servers located outside your '
              'country (Google Firebase servers). By using PartnerUp, '
              'you consent to this transfer.'),

            _section('10. Changes to This Policy',
              'We may update this Privacy Policy from time to time. '
              'We will notify you of significant changes through the app. '
              'Continued use of PartnerUp after changes means you accept '
              'the updated policy.'),

            _section('11. Contact Us',
              'For privacy questions or concerns, contact us at:\n\n'
              'Email: $supportEmail\n'
              'Developer: $founder\n'
              'Country: $country'),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),

            // Contact button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                    builder: (_) => const ContactScreen())),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Contact Us'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

            const SizedBox(height: 30),
            Center(
              child: Text(
                '© ${DateTime.now().year} PartnerUp. All rights reserved.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            )),
          const SizedBox(height: 8),
          Text(body,
            style: const TextStyle(fontSize: 13, height: 1.6)),
        ],
      ),
    );
  }
}
