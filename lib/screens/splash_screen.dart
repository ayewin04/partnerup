import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Small delay so splash shows nicely
    await Future.delayed(const Duration(milliseconds: 1200));

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _goToLogin();
      return;
    }

    try {
      // Check if user is banned
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // User doc missing (deleted) → force logout
        await FirebaseAuth.instance.signOut();
        _goToLogin();
        return;
      }

      final data = userDoc.data()!;
      if (data['isBanned'] == true) {
        await FirebaseAuth.instance.signOut();
        _goToLogin(message: 'Your account has been banned.');
        return;
      }

      // Mark user online
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isOnline': true,
        'lastSeenAt': FieldValue.serverTimestamp(),
      });

      _goToFeed();
    } catch (_) {
      // Any error → just go to feed (offline mode still works)
      _goToFeed();
    }
  }

  void _goToLogin({String? message}) {
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    Navigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _goToFeed() {
    if (!mounted) return;
    Navigator.pushReplacement(context,
      MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[700],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.handshake, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            const Text('PartnerUp',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                color: Colors.white)),
            const SizedBox(height: 10),
            const Text('Find your perfect partner',
              style: TextStyle(fontSize: 16, color: Colors.white70)),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

