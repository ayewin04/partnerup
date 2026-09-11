import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return 'Username is required';
    if (value.trim().length < 3) return 'Username must be at least 3 characters';
    if (value.trim().length > 20) return 'Username must be under 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
      return 'Only letters, numbers, and underscore allowed';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain at least 1 uppercase letter';
    if (!value.contains(RegExp(r'[a-z]'))) return 'Must contain at least 1 lowercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain at least 1 number';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();
    setState(() { _error = null; });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    debugPrint('=== SIGNUP START ===');

    try {
      // STEP 1: Check if username exists
      debugPrint('STEP 1: Checking username...');
      final usernameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim())
          .limit(1)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        debugPrint('STEP 1 FAILED: Username taken');
        setState(() {
          _error = 'Username already taken. Try another.';
          _loading = false;
        });
        return;
      }
      debugPrint('STEP 1 OK');

      // STEP 2: Create auth user
      debugPrint('STEP 2: Creating Firebase Auth user...');
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      debugPrint('STEP 2 OK: UID = ${cred.user!.uid}');

      // STEP 3: Write to Firestore
      debugPrint('STEP 3: Writing to Firestore...');
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'username': _usernameController.text.trim(),
        'usernameLower': _usernameController.text.trim().toLowerCase(),
        'email': _emailController.text.trim(),
        'bio': '',
        'avatarUrl': '',
        'partnershipCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'isBanned': false,
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
      debugPrint('STEP 3 OK');

      // STEP 4: Send verification email
      try {
        await cred.user!.sendEmailVerification();
        debugPrint('STEP 4 OK: Verification email sent');
      } catch (e) {
        debugPrint('STEP 4 WARNING: $e');
      }

      // STEP 5: Sign out
      await FirebaseAuth.instance.signOut();
      debugPrint('STEP 5 OK: Signed out');

      if (!mounted) return;
      setState(() => _loading = false);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              SizedBox(height: 10),
              Text('Account Created!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Your PartnerUp account has been created successfully.\n\nPlease login to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Go to Login',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('=== AUTH EXCEPTION ===');
      debugPrint('Code: ${e.code}');
      debugPrint('Message: ${e.message}');
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'This email is already registered. Try logging in.'; break;
        case 'invalid-email':
          msg = 'Invalid email address.'; break;
        case 'weak-password':
          msg = 'Password is too weak.'; break;
        case 'network-request-failed':
          msg = 'No internet connection.'; break;
        case 'operation-not-allowed':
          msg = 'Email/Password sign-in is not enabled in Firebase Console.'; break;
        default:
          msg = 'Auth error [${e.code}]: ${e.message}';
      }
      setState(() => _error = msg);
    } on FirebaseException catch (e) {
      debugPrint('=== FIRESTORE EXCEPTION ===');
      debugPrint('Code: ${e.code}');
      debugPrint('Message: ${e.message}');
      String msg;
      switch (e.code) {
        case 'permission-denied':
          msg = 'Firestore permission denied. Check your rules.'; break;
        case 'unavailable':
          msg = 'Firestore unavailable. Check internet.'; break;
        case 'not-found':
          msg = 'Firestore database not found. Create it in Firebase Console.'; break;
        default:
          msg = 'Firestore error [${e.code}]: ${e.message}';
      }
      setState(() => _error = msg);
    } catch (e, stack) {
      debugPrint('=== UNKNOWN EXCEPTION ===');
      debugPrint('Type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack: $stack');
      setState(() => _error = 'Error: ${e.runtimeType} - $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.handshake, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text('Create Account',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),

              TextFormField(
                controller: _usernameController,
                validator: _validateUsername,
                enabled: !_loading,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                validator: _validateEmail,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                validator: _validatePassword,
                enabled: !_loading,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Min 8 chars, 1 upper, 1 lower, 1 number',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                      ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmController,
                validator: _validateConfirm,
                enabled: !_loading,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signup(),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                      ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(
                      () => _obscureConfirm = !_obscureConfirm),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),

              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: SelectableText(_error!,
                        style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                    : const Text('Sign Up', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

