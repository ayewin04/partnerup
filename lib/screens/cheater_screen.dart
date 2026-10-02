import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CheaterScreen extends StatefulWidget {
  const CheaterScreen({super.key});

  @override
  State<CheaterScreen> createState() => _CheaterScreenState();
}

class _CheaterScreenState extends State<CheaterScreen> {
  List<DocumentSnapshot> _allDocs = [];
  int _visibleCount = 20;
  bool _loading = true;
  String? _error;

  static const int _fetchLimit = 100;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // NO INDEX: single-field query only
      final snap = await FirebaseFirestore.instance
          .collection('reports')
          .limit(_fetchLimit)
          .get();

      // Filter + sort in Dart
      var docs = snap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['status'] == 'cheater';
      }).toList();

      docs.sort((a, b) {
        final ta = (a.data() as Map<String, dynamic>)['cheaterAt']
            as Timestamp?;
        final tb = (b.data() as Map<String, dynamic>)['cheaterAt']
            as Timestamp?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      if (mounted) {
        setState(() {
          _allDocs = docs;
          _visibleCount = _pageSize;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[CheaterBoard] error: $e');
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  void _loadMore() {
    setState(() {
      _visibleCount = (_visibleCount + _pageSize).clamp(0, _allDocs.length);
    });
  }

  bool get _hasMore => _visibleCount < _allDocs.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cheater Board',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadAll,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_allDocs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user, size: 80, color: Colors.green),
              SizedBox(height: 16),
              Text('Cheater Board is empty',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
              SizedBox(height: 8),
              Text('No users have been flagged recently.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final visible = _allDocs.take(_visibleCount).toList();
    final itemCount = visible.length + (_hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber,
                  color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'These users broke the partnership contract. '
                    'Their accounts will be deleted after 36 hours.',
                    style: TextStyle(fontSize: 12, color: Colors.red[900]),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: itemCount,
              itemBuilder: (context, i) {
                if (i == visible.length) return _buildFooter();
                return _cheaterCard(visible[i]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            Text(
              'Showing $_visibleCount of ${_allDocs.length}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadMore,
              icon: const Icon(Icons.expand_more, size: 18),
              label: const Text('Load More'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cheaterCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final reportedUsername = data['reportedUsername'] ?? 'Unknown';
    final reason = data['reason'] ?? '';
    final reporterUsername = data['reporterUsername'] ?? 'Unknown';
    final cheaterAt = data['cheaterAt'] as Timestamp?;
    final deleteAt = data['deleteAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red[100]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.red[100],
                  child: Text(
                    reportedUsername.isNotEmpty
                      ? reportedUsername[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('@$reportedUsername',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.red,
                        )),
                      if (cheaterAt != null)
                        Text(
                          'Flagged ${_timeAgo(cheaterAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('CHEATER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    )),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reason:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    )),
                  const SizedBox(height: 4),
                  Text(reason, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Reported by @$reporterUsername',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            if (deleteAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    'Account deletes in ${_remaining(deleteAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _remaining(Timestamp ts) {
    final diff = ts.toDate().difference(DateTime.now());
    if (diff.isNegative) return 'soon';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }
}
