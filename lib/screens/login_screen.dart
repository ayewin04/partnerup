import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contract_screen.dart';
import 'forgot_password_screen.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password is too short';
    return null;
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const MainShell()));
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found': msg = 'No account found with this email.'; break;
        case 'wrong-password': msg = 'Incorrect password. Try again.'; break;
        case 'invalid-email': msg = 'Invalid email address.'; break;
        case 'user-disabled': msg = 'This account has been disabled.'; break;
        case 'too-many-requests': msg = 'Too many attempts. Try later.'; break;
        case 'network-request-failed': msg = 'No internet connection.'; break;
        case 'invalid-credential': msg = 'Invalid email or password.'; break;
        default: msg = e.message ?? 'Login failed. Try again.';
      }
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                const SizedBox(height: 60),
                const Icon(Icons.handshake, size: 100, color: Colors.blue),
                const SizedBox(height: 20),
                const Text('PartnerUp',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Find your perfect partner',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 50),

                TextFormField(
                  controller: _emailController,
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  validator: _validatePassword,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                        ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen())),
                    child: const Text('Forgot Password?'),
                  ),
                ),

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
                        const Icon(Icons.error_outline,
                          color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!,
                          style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
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
                      : const Text('Login', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const ContractScreen())),
                  child: const Text('New here? Sign Up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
