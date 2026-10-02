import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tabs = ['Pending', 'Under Review', 'Cheater', 'All'];
  final _statuses = [
    'pending_proof',
    'under_review',
    'cheater',
    null,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, size: 22),
            SizedBox(width: 8),
            Text('Admin Panel',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses.map((status) => _ReportsList(
          key: ValueKey(status ?? 'all'),
          status: status,
        )).toList(),
      ),
    );
  }
}

// ============================================================
// A single paginated list for one status filter
// ============================================================
class _ReportsList extends StatefulWidget {
  final String? status;
  const _ReportsList({super.key, required this.status});

  @override
  State<_ReportsList> createState() => _ReportsListState();
}

class _ReportsListState extends State<_ReportsList> {
  // All fetched reports for this filter (cached in memory)
  List<DocumentSnapshot> _allDocs = [];
  // How many to display currently
  int _visibleCount = 20;

  bool _loading = true;
  String? _error;

  static const int _fetchLimit = 100; // fetch once, paginate client-side
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

      var docs = snap.docs.toList();

      // Filter in Dart
      if (widget.status != null) {
        docs = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['status'] == widget.status;
        }).toList();
      }

      // Sort by createdAt desc in Dart
      docs.sort((a, b) {
        final ta = (a.data() as Map<String, dynamic>)['createdAt']
            as Timestamp?;
        final tb = (b.data() as Map<String, dynamic>)['createdAt']
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
      debugPrint('[Admin] load error: $e');
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 60, color: Colors.grey),
            SizedBox(height: 12),
            Text('No reports in this category',
              style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final visible = _allDocs.take(_visibleCount).toList();
    final itemCount = visible.length + (_hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: itemCount,
        itemBuilder: (context, i) {
          if (i == visible.length) return _buildFooter();
          return _reportCard(visible[i]);
        },
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

  // ============ REPORT CARD ============
  Widget _reportCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'pending_proof';
    final reporterUsername = data['reporterUsername'] ?? 'Unknown';
    final reportedUsername = data['reportedUsername'] ?? 'Unknown';
    final reason = data['reason'] ?? '';
    final reporterProof = data['reporterProof'] ?? '';
    final reportedProof = data['reportedProof'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final deadline = data['proofDeadline'] as Timestamp?;
    final deleteAt = data['deleteAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusBadge(status),
                const Spacer(),
                if (createdAt != null)
                  Text(_timeAgo(createdAt),
                    style: TextStyle(
                      fontSize: 11, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _userBlock(
                    label: 'Reporter',
                    username: reporterUsername,
                    color: Colors.blue,
                  ),
                ),
                const Icon(Icons.arrow_forward,
                  size: 16, color: Colors.grey),
                Expanded(
                  child: _userBlock(
                    label: 'Reported',
                    username: reportedUsername,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section('Reason', reason),
            const SizedBox(height: 8),
            _section('Reporter Proof', reporterProof),
            const SizedBox(height: 8),
            if (reportedProof.isNotEmpty)
              _section('Accused Proof', reportedProof, highlight: true),
            const SizedBox(height: 10),
            if (status == 'pending_proof' && deadline != null)
              Row(
                children: [
                  const Icon(Icons.timer, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Proof deadline: ${_remaining(deadline)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            if (status == 'cheater' && deleteAt != null)
              Row(
                children: [
                  const Icon(Icons.delete_forever,
                    size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    'Account deletion in: ${_remaining(deleteAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            _actionRow(doc, status),
          ],
        ),
      ),
    );
  }

  Widget _userBlock({
    required String label,
    required String username,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: TextStyle(
            fontSize: 10, color: color,
            fontWeight: FontWeight.bold,
          )),
        Text('@$username',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _section(String title, String content, {bool highlight = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: highlight ? Border.all(color: Colors.green[200]!) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.green[800] : Colors.grey[700],
            )),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'pending_proof':
        color = Colors.orange; label = 'PENDING PROOF';
        icon = Icons.hourglass_top; break;
      case 'under_review':
        color = Colors.blue; label = 'UNDER REVIEW';
        icon = Icons.search; break;
      case 'cheater':
        color = Colors.red; label = 'CHEATER';
        icon = Icons.warning_amber; break;
      case 'resolved':
        color = Colors.green; label = 'RESOLVED';
        icon = Icons.check_circle; break;
      case 'deleted':
        color = Colors.grey; label = 'DELETED';
        icon = Icons.delete; break;
      default:
        color = Colors.grey; label = status.toUpperCase();
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _actionRow(DocumentSnapshot doc, String status) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (status == 'pending_proof' || status == 'under_review') ...[
          _actionBtn(
            icon: Icons.check_circle, label: 'Resolve',
            color: Colors.green,
            onTap: () => _resolve(doc),
          ),
          _actionBtn(
            icon: Icons.warning_amber, label: 'Force Cheater',
            color: Colors.red,
            onTap: () => _forceCheater(doc),
          ),
          if (status == 'pending_proof')
            _actionBtn(
              icon: Icons.timer, label: 'Extend +24h',
              color: Colors.orange,
              onTap: () => _extendDeadline(doc),
            ),
        ],
        if (status == 'cheater') ...[
          _actionBtn(
            icon: Icons.restore, label: 'Restore',
            color: Colors.green,
            onTap: () => _restoreUser(doc),
          ),
          _actionBtn(
            icon: Icons.delete_forever, label: 'Delete Now',
            color: Colors.red,
            onTap: () => _deleteNow(doc),
          ),
        ],
        _actionBtn(
          icon: Icons.delete_outline, label: 'Remove Report',
          color: Colors.grey,
          onTap: () => _deleteReport(doc),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
              style: TextStyle(
                fontSize: 11, color: color,
                fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ============ ACTIONS ============

  Future<void> _resolve(DocumentSnapshot doc) async {
    final confirmed = await _confirm('Resolve Report',
      'Mark this report as resolved? The reported user will not be penalized.');
    if (confirmed != true) return;
    final data = doc.data() as Map<String, dynamic>;
    try {
      await doc.reference.update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (data['reportedId'] != null) {
        await FirebaseFirestore.instance.collection('users')
            .doc(data['reportedId']).update({
          'isBanned': false, 'isCheater': false,
        }).catchError((_) {});
      }
      await _notify(data['reporterId'], 'Report resolved',
        'Your report against @${data['reportedUsername']} has been resolved.');
      await _notify(data['reportedId'], 'Report resolved',
        'The report against you has been resolved.');
      _showSnack('Report resolved', Colors.green);
      if (mounted) setState(() => _allDocs.remove(doc));
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }

  Future<void> _forceCheater(DocumentSnapshot doc) async {
    final confirmed = await _confirm('Force Cheater Status',
      'Immediately mark as cheater? Account deleted in 36 hours.',
      confirmColor: Colors.red);
    if (confirmed != true) return;
    final data = doc.data() as Map<String, dynamic>;
    final reportedId = data['reportedId'] as String;
    final reportedUsername = data['reportedUsername'] as String;
    try {
      final deleteAt = DateTime.now().add(const Duration(hours: 36));
      await doc.reference.update({
        'status': 'cheater',
        'cheaterAt': FieldValue.serverTimestamp(),
        'deleteAt': Timestamp.fromDate(deleteAt),
        'forcedByAdmin': true,
      });
      await FirebaseFirestore.instance.collection('users')
          .doc(reportedId).update({
        'isBanned': true, 'isCheater': true,
      });
      await _notifyPartners(reportedId, reportedUsername);
      await _notify(data['reporterId'], 'Report accepted',
        '@$reportedUsername has been marked as a cheater.');
      _showSnack('User marked as cheater', Colors.red);
      if (mounted) setState(() => _allDocs.remove(doc));
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }

  Future<void> _extendDeadline(DocumentSnapshot doc) async {
    final confirmed = await _confirm('Extend Deadline',
      'Add 24 more hours to the proof deadline?');
    if (confirmed != true) return;
    final data = doc.data() as Map<String, dynamic>;
    final current = (data['proofDeadline'] as Timestamp?)?.toDate()
        ?? DateTime.now();
    final newDeadline = current.add(const Duration(hours: 24));
    try {
      await doc.reference.update({
        'proofDeadline': Timestamp.fromDate(newDeadline),
      });
      _showSnack('Deadline extended by 24h', Colors.orange);
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }

  Future<void> _restoreUser(DocumentSnapshot doc) async {
    final confirmed = await _confirm('Restore User',
      'Remove cheater status and restore the user?');
    if (confirmed != true) return;
    final data = doc.data() as Map<String, dynamic>;
    try {
      await doc.reference.update({
        'status': 'resolved',
        'restoredAt': FieldValue.serverTimestamp(),
        'restoredByAdmin': true,
      });
      await FirebaseFirestore.instance.collection('users')
          .doc(data['reportedId']).update({
        'isBanned': false, 'isCheater': false,
      });
      await _notify(data['reportedId'], 'Account restored',
        'Your cheater status has been removed.');
      _showSnack('User restored', Colors.green);
      if (mounted) setState(() => _allDocs.remove(doc));
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }

  Future<void> _deleteNow(DocumentSnapshot doc) async {
    final confirmed = await _confirm('Delete Account Now',
      'This immediately deletes the user account. Cannot be undone.',
      confirmColor: Colors.red);
    if (confirmed != true) return;
    final data = doc.data() as Map<String, dynamic>;
    try {
      await doc.reference.update({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedByAdmin': true,
      });
      await FirebaseFirestore.instance.collection('users')
          .doc(data['reportedId']).delete();
      _showSnack('Account deleted', Colors.red);
      if (mounted) setState(() => _allDocs.remove(doc));
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }

  Future<void> _deleteReport(DocumentSnapshot doc) async {
    final confirmed = await _confirm('Remove Report',
      'This deletes the report entirely. Use only for spam or abuse.',
      confirmColor: Colors.grey);
    if (confirmed != true) return;
    try {
      await doc.reference.delete();
      _showSnack('Report removed', Colors.grey);
      if (mounted) setState(() => _allDocs.remove(doc));
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }

  // ============ HELPERS ============

  Future<bool?> _confirm(String title, String body,
      {Color confirmColor = Colors.blue}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _notify(String? uid, String title, String body) async {
    if (uid == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid)
            .collection('notifications').doc(),
        {
          'type': 'admin_action',
          'title': title,
          'body': body,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {'unreadNotificationCount': FieldValue.increment(1)},
      );
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _notifyPartners(String cheaterId, String cheaterUsername) async {
    try {
      final asA = await FirebaseFirestore.instance
          .collection('partnerships')
          .where('userA', isEqualTo: cheaterId).get();
      final asB = await FirebaseFirestore.instance
          .collection('partnerships')
          .where('userB', isEqualTo: cheaterId).get();

      final partnerIds = <String>{};
      for (final p in asA.docs) {
        partnerIds.add(p.data()['userB']);
      }
      for (final p in asB.docs) {
        partnerIds.add(p.data()['userA']);
      }
      partnerIds.remove(cheaterId);

      for (final pid in partnerIds) {
        await _notify(pid, 'A past partner was flagged',
          '@$cheaterUsername has been marked as a cheater.');
      }
    } catch (_) {}
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(ts.toDate());
  }

  String _remaining(Timestamp ts) {
    final diff = ts.toDate().difference(DateTime.now());
    if (diff.isNegative) return 'expired';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    return '${diff.inHours}h';
  }
}
