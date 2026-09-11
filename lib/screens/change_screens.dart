import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// CHANGE EMAIL
// ============================================================
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});
  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Re-authenticate
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);

      // Use verifyBeforeUpdateEmail (Firebase 6.x+)
      await user.verifyBeforeUpdateEmail(_newEmailCtrl.text.trim());

      // Note: Firestore email will update after user verifies via the link.
      // We store the pending email separately so admin/analytics can see it.
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .update({
        'pendingEmail': _newEmailCtrl.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification email sent! Click the link to confirm the change.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
          msg = 'Current password is incorrect.';
          break;
        case 'email-already-in-use':
          msg = 'That email is already used by another account.';
          break;
        case 'invalid-email':
          msg = 'Please enter a valid email.';
          break;
        case 'requires-recent-login':
          msg = 'Please logout and login again before changing email.';
          break;
        default:
          msg = e.message ?? 'Update failed.';
      }
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _newEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Email')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your current password, then your new email.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                      ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'New Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email required';
                  final regex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!regex.hasMatch(v.trim())) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(_error!,
                    style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                    : const Text('Update Email',
                        style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CHANGE PASSWORD
// ============================================================
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newCtrl.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
          msg = 'Current password is incorrect.';
          break;
        case 'weak-password':
          msg = 'New password is too weak.';
          break;
        case 'requires-recent-login':
          msg = 'Please logout and login again.';
          break;
        default:
          msg = e.message ?? 'Update failed.';
      }
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password required';
    if (v.length < 8) return 'At least 8 characters';
    if (!v.contains(RegExp(r'[A-Z]'))) return 'Needs 1 uppercase';
    if (!v.contains(RegExp(r'[a-z]'))) return 'Needs 1 lowercase';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Needs 1 number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentCtrl,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent
                      ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(
                      () => _obscureCurrent = !_obscureCurrent),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) =>
                  (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newCtrl,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  hintText: 'Min 8, 1 upper, 1 lower, 1 number',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew
                      ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(
                      () => _obscureNew = !_obscureNew),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) =>
                  (v != _newCtrl.text) ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(_error!,
                    style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                    : const Text('Update Password',
                        style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CHANGE USERNAME
// ============================================================
class ChangeUsernameScreen extends StatefulWidget {
  const ChangeUsernameScreen({super.key});
  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    _ctrl.text = doc.data()?['username'] ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newUsername = _ctrl.text.trim();

    try {
      // Check if username is taken by someone else
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: newUsername)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty &&
          existing.docs.first.id != user.uid) {
        setState(() {
          _error = 'Username already taken';
          _loading = false;
        });
        return;
      }

      // Check last change date
      final myDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final lastChange = myDoc.data()?['lastUsernameChange'] as Timestamp?;
      if (lastChange != null) {
        final daysSince = DateTime.now()
            .difference(lastChange.toDate()).inDays;
        if (daysSince < 30) {
          setState(() {
            _error = 'You can only change username once per month. '
                'Try again in ${30 - daysSince} days.';
            _loading = false;
          });
          return;
        }
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .update({
        'username': newUsername,
        'usernameLower': newUsername.toLowerCase(),
        'lastUsernameChange': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username updated!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Username')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                'You can change your username once per month.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _ctrl,
                decoration: InputDecoration(
                  labelText: 'New Username',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 3) return 'Min 3 characters';
                  if (v.trim().length > 20) return 'Max 20 characters';
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                    return 'Only letters, numbers, underscore';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(_error!,
                    style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                    : const Text('Update Username',
                        style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// VIEW CONTRACT
// ============================================================
class ViewContractScreen extends StatelessWidget {
  const ViewContractScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partnership Contract')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('PARTNERSHIP AGREEMENT',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('By using PartnerUp, you agree to the following:',
              style: TextStyle(fontSize: 14)),
            SizedBox(height: 14),
            Text('1. PARTNERSHIP RULE:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('Once you and another user agree to a partnership by both '
              'clicking "PARTNER" in the 15-minute partnership popup, you '
              'are entering a binding agreement.',
              style: TextStyle(fontSize: 13)),
            SizedBox(height: 14),
            Text('2. NO BACKING OUT:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('You cannot cancel or back out of a partnership agreement '
              'without the mutual written consent of both parties.',
              style: TextStyle(fontSize: 13)),
            SizedBox(height: 14),
            Text('3. CONSEQUENCES OF VIOLATION:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('If you back out without mutual agreement, the other party '
              'may report you.\n'
              '- You will have 80 hours to submit proof of your innocence.\n'
              '- If you fail to submit proof, your account will be flagged '
              'as CHEATER and displayed on the Cheater Board.\n'
              '- After 36 hours on the board, your account will be '
              'permanently deleted.\n'
              '- All your past partners will be notified.',
              style: TextStyle(fontSize: 13)),
            SizedBox(height: 14),
            Text('4. REPORTING:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('If you believe someone violated this agreement, you must '
              'submit both a reason and proof with your report.',
              style: TextStyle(fontSize: 13)),
            SizedBox(height: 14),
            Text('5. ACCOUNT TERMINATION:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('PartnerUp reserves the right to terminate any account '
              'that violates this agreement without prior notice.',
              style: TextStyle(fontSize: 13)),
            SizedBox(height: 14),
            Text('6. DATA USAGE:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('Your data will be stored securely and used only for app '
              'functionality.',
              style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

