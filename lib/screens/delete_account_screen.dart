import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/account_deletion_service.dart';
import 'splash_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _confirmed =>
      _confirmCtrl.text.trim().toUpperCase() == 'DELETE';

  Future<void> _delete() async {
    if (!_confirmed) {
      setState(() => _error = 'Type DELETE in the box to confirm.');
      return;
    }

    final sure = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Final Warning'),
        content: const Text(
          'This will PERMANENTLY delete your account and all your data:\n\n'
          '• Your posts\n'
          '• Your likes and comments\n'
          '• Your chats and messages\n'
          '• Your partnerships\n'
          '• Your notifications\n\n'
          'This action CANNOT be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE FOREVER'),
          ),
        ],
      ),
    );
    if (sure != true) return;

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    String? errorMsg;
    try {
      await AccountDeletionService.deleteMyAccount();
    } catch (e) {
      errorMsg = '$e'.replaceFirst('Exception: ', '');
      debugPrint('[Delete] error: $errorMsg');
    }

    // Ensure signed out regardless
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    if (!mounted) return;

    if (errorMsg != null) {
      // Show error but still allow retry
      setState(() {
        _loading = false;
        _error = errorMsg;
      });
      return;
    }

    // ---- SUCCESS: Show confirmation and redirect ----
    // Reset loading to avoid hanging spinner
    setState(() => _loading = false);

    // Show a quick dialog / SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your account has been deleted.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );

    // Small delay so user sees the message
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete My Account',
          style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.warning_amber,
                        color: Colors.red, size: 24),
                      SizedBox(width: 8),
                      Text('This action is permanent',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Deleting your account will remove ALL your data from '
                    'PartnerUp:\n\n'
                    '• Your profile\n'
                    '• All your posts\n'
                    '• All your likes and comments\n'
                    '• All your chat messages\n'
                    '• All your partnerships\n'
                    '• Your notifications\n\n'
                    'This cannot be undone. If you want to use PartnerUp '
                    'again later, you will need to create a new account.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Type DELETE to confirm:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              )),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmCtrl,
              enabled: !_loading,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'DELETE',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_confirmed && !_loading) ? _delete : null,
                icon: _loading
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.delete_forever),
                label: Text(_loading
                  ? 'Deleting...' : 'Delete My Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
