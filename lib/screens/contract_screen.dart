import 'package:flutter/material.dart';
import 'signup_screen.dart';

class ContractScreen extends StatefulWidget {
  const ContractScreen({super.key});
  @override
  State<ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends State<ContractScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50) {
        if (!_hasScrolledToBottom) {
          setState(() => _hasScrolledToBottom = true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partnership Contract')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('PARTNERSHIP AGREEMENT',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  Text('By using PartnerUp, you agree to the following:',
                    style: TextStyle(fontSize: 16)),
                  SizedBox(height: 15),
                  Text('1. PARTNERSHIP RULE:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Once you and another user agree to a partnership by both clicking "PARTNER" in the 15-minute partnership popup, you are entering a binding agreement.',
                    style: TextStyle(fontSize: 14)),
                  SizedBox(height: 15),
                  Text('2. NO BACKING OUT:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('You cannot cancel or back out of a partnership agreement without the mutual written consent of both parties.',
                    style: TextStyle(fontSize: 14)),
                  SizedBox(height: 15),
                  Text('3. CONSEQUENCES OF VIOLATION:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('If you back out without mutual agreement, the other party may report you.\n- You will have 48 hours to submit proof of your innocence.\n- If you fail to submit proof, your account will be permanently deleted.\n- Your username will be displayed on the Cheater Board.\n- All your past partners will be notified.',
                    style: TextStyle(fontSize: 14)),
                  SizedBox(height: 15),
                  Text('4. REPORTING:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('If you believe someone violated this agreement, you must submit proof with your report.',
                    style: TextStyle(fontSize: 14)),
                  SizedBox(height: 15),
                  Text('5. ACCOUNT TERMINATION:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('PartnerUp reserves the right to terminate any account that violates this agreement without prior notice.',
                    style: TextStyle(fontSize: 14)),
                  SizedBox(height: 15),
                  Text('6. DATA USAGE:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Your data will be stored securely and used only for app functionality.',
                    style: TextStyle(fontSize: 14)),
                  SizedBox(height: 40),
                  Text('I have read and agree to the Partnership Contract.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 60),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: _hasScrolledToBottom
                        ? (val) => setState(() => _agreed = val ?? false)
                        : null,
                    ),
                    Expanded(
                      child: Text(
                        _hasScrolledToBottom
                          ? 'I agree to the Partnership Contract'
                          : 'Scroll to bottom to enable',
                        style: TextStyle(
                          color: _hasScrolledToBottom ? Colors.black : Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _agreed ? () {
                      Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()));
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Continue',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
