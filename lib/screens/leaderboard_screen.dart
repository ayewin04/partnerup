import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Leaderboard Screen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Coming in Screen 6',
              style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
