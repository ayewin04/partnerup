import 'package:flutter/material.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Search Screen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Coming in Screen 5',
              style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
