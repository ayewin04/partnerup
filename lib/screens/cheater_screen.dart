import 'package:flutter/material.dart';

class CheaterScreen extends StatelessWidget {
  const CheaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cheater Board',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Cheater Board Screen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Coming in Screen 7',
              style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
