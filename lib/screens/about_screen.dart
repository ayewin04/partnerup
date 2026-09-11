import 'package:flutter/material.dart';
import 'contact_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String appName = 'PartnerUp';
  static const String version = '1.0.0';
  static const String founder = 'Wedawon';
  static const String country = 'Myanmar';
  static const String website = 'wedawon.com';
  static const String tagline = 'Find your perfect partner';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // App icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.handshake,
                size: 60,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),

            // App name
            const Text(appName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              )),
            const SizedBox(height: 6),

            // Tagline
            Text(tagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              )),

            const SizedBox(height: 8),

            // Version badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text('Version $version',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                )),
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),

            // What is PartnerUp
            _section(
              title: 'What is PartnerUp?',
              body:
                'PartnerUp is a real-time social app that helps you find '
                'partners for anything — sports, study, work, or hobbies. '
                'Post what you\'re looking for, chat with interested people, '
                'and form binding partnerships.\n\n'
                'Once both users confirm a partnership, they enter a mutual '
                'agreement. Breaking a partnership without consent is '
                'enforced by our Cheater Board and admin moderation.',
            ),

            const SizedBox(height: 20),

            // Key features
            _section(
              title: 'Key Features',
              body:
                '• Post what you want to partner for\n'
                '• Chat with anyone in real-time\n'
                '• Form binding partnerships\n'
                '• 15-minute confirmation window\n'
                '• Leaderboard of top partners\n'
                '• Cheater Board for violations\n'
                '• Real-time notifications',
            ),

            const SizedBox(height: 20),

            // About the founder
            _section(
              title: 'About the Developer',
              body:
                'PartnerUp was created by $founder, based in $country, '
                'with a vision to make finding the right partner easier '
                'and more trustworthy. Every partnership on our platform '
                'is protected by a mutual agreement to ensure fairness.',
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            // Info rows
            _infoRow('App Name', appName),
            _infoRow('Version', version),
            _infoRow('Founder', founder),
            _infoRow('Country', country),
            _infoRow('Website', website),

            const SizedBox(height: 20),

            // Contact button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                    builder: (_) => const ContactScreen())),
                icon: const Icon(Icons.contact_support),
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

            const SizedBox(height: 40),

            // Copyright
            Text(
              '© ${DateTime.now().year} $appName. All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required String body}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          )),
        const SizedBox(height: 8),
        Text(body,
          style: const TextStyle(fontSize: 13, height: 1.5)),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              )),
          ),
          Expanded(
            child: SelectableText(value,
              style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
