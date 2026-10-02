import 'dart:async';
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
  StreamSubscription<User?>? _authSub;
  Timer? _fallbackTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // ---- Safety net: if nothing happens in 8 seconds, go to Login ----
    _fallbackTimer = Timer(const Duration(seconds: 8), () {
      debugPrint('[Splash] FALLBACK triggered — going to Login');
      _goToLogin();
    });

    // ---- Listen to auth state. Fires immediately with the restored user. ----
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      (user) async {
        debugPrint('[Splash] auth state: ${user?.uid ?? "null"}');

        if (user == null) {
          // No session → Login
          await Future.delayed(const Duration(milliseconds: 400));
          _goToLogin();
          return;
        }

        // User restored → check ban status
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 4));

          if (!userDoc.exists) {
            // User doc missing → logout
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

          // Mark online (best-effort, don't block navigation)
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'isOnline': true,
            'lastSeenAt': FieldValue.serverTimestamp(),
          }).catchError((e) {
            debugPrint('[Splash] online update error: $e');
          });

          _goToFeed();
        } catch (e) {
          debugPrint('[Splash] check error: $e');
          // On error → still go to feed (offline mode)
          _goToFeed();
        }
      },
      onError: (e) {
        debugPrint('[Splash] auth error: $e');
        _goToLogin();
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  void _goToLogin({String? message}) {
    if (!mounted || _navigated) return;
    _navigated = true;
    _fallbackTimer?.cancel();

    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      });
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _goToFeed() {
    if (!mounted || _navigated) return;
    _navigated = true;
    _fallbackTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
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
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              )),
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
