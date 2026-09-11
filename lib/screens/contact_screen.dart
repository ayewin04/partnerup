import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const String supportEmail = 'nextgenlearningmyanmar@gmail.com';
  static const String website = 'wedawon.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.contact_support,
                size: 50,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),

            const Text('We\'re here to help',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              )),
            const SizedBox(height: 8),
            Text(
              'Have a question, bug report, or feedback? Reach out to us.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 30),

            // Support email card
            _contactCard(
              context,
              icon: Icons.support_agent,
              color: Colors.blue,
              title: 'General Support',
              subtitle: supportEmail,
              buttonLabel: 'Send Email',
              onTap: () => _sendEmail(
                context, supportEmail, 'PartnerUp Support'),
            ),

            const SizedBox(height: 12),

            // Bug report card
            _contactCard(
              context,
              icon: Icons.bug_report,
              color: Colors.orange,
              title: 'Report a Bug',
              subtitle: supportEmail,
              buttonLabel: 'Send Bug Report',
              onTap: () => _sendEmail(
                context, supportEmail, 'PartnerUp Bug Report'),
            ),

            const SizedBox(height: 12),

            // Privacy
            _contactCard(
              context,
              icon: Icons.privacy_tip,
              color: Colors.purple,
              title: 'Privacy Inquiry',
              subtitle: supportEmail,
              buttonLabel: 'Contact Privacy Team',
              onTap: () => _sendEmail(
                context, supportEmail, 'PartnerUp Privacy Inquiry'),
            ),

            const SizedBox(height: 12),

            // Website
            _contactCard(
              context,
              icon: Icons.language,
              color: Colors.green,
              title: 'Website',
              subtitle: website,
              buttonLabel: 'Visit Website',
              onTap: () => _openWebsite(context),
            ),

            const SizedBox(height: 30),

            // Copy email button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Quick Copy',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          supportEmail,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy email',
                        onPressed: () async {
                          await Clipboard.setData(
                            const ClipboardData(text: supportEmail));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email copied'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            Text(
              'We typically respond within 24-48 hours.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(buttonLabel,
                style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmail(
      BuildContext context, String email, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback: copy email
        await Clipboard.setData(ClipboardData(text: email));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email copied: $email'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: email));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email copied: $email'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse('https://$website');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: website));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Website URL copied'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      await Clipboard.setData(const ClipboardData(text: website));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Website URL copied'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
