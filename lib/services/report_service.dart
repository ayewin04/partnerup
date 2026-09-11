import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ReportService {
  static final _db = FirebaseFirestore.instance;

  /// User 1 submits a report against User 2.
  /// Both reason and proof are required — this prevents revenge reporting.
  static Future<String> submitReport({
    required String reportedId,
    required String reportedUsername,
    required String reason,
    required String reporterProof,
  }) async {
    final me = FirebaseAuth.instance.currentUser!;
    if (me.uid == reportedId) {
      throw Exception('You cannot report yourself');
    }

    // ---- CHECK: Must have at least 1 partnership with the reported user ----
    final p1 = await _db.collection('partnerships')
        .where('userA', isEqualTo: me.uid)
        .where('userB', isEqualTo: reportedId)
        .limit(1)
        .get();
    final p2 = await _db.collection('partnerships')
        .where('userA', isEqualTo: reportedId)
        .where('userB', isEqualTo: me.uid)
        .limit(1)
        .get();

    if (p1.docs.isEmpty && p2.docs.isEmpty) {
      throw Exception(
        'You can only report users you have partnered with before');
    }

    // Check if User 2 already has an active report against them
    final existing = await _db.collection('reports')
        .where('reportedId', isEqualTo: reportedId)
        .where('status', whereIn: [
          'pending_proof',
          'under_review',
          'expired_proof',
          'cheater',
        ])
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('This user already has an active report');
    }

    // Get my username
    final meDoc = await _db.collection('users').doc(me.uid).get();
    final myUsername = meDoc.data()?['username'] ?? 'Unknown';

    final now = DateTime.now();
    final proofDeadline = now.add(const Duration(hours: 80));

    final ref = await _db.collection('reports').add({
      'reporterId': me.uid,
      'reporterUsername': myUsername,
      'reportedId': reportedId,
      'reportedUsername': reportedUsername,
      'reason': reason,
      'reporterProof': reporterProof,
      'reportedProof': '',
      'status': 'pending_proof',
      'createdAt': FieldValue.serverTimestamp(),
      'proofDeadline': Timestamp.fromDate(proofDeadline),
      'cheaterAt': null,
      'deleteAt': null,
      'deletedAt': null,
    });

    // Notify reporter
    await _db.collection('users').doc(me.uid)
        .collection('notifications').add({
      'type': 'report_submitted',
      'title': 'Report submitted',
      'body':
          'Your report against $reportedUsername has been submitted. '
          'You will be notified of the outcome.',
      'data': {'reportId': ref.id},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notify reported user
    await _db.collection('users').doc(reportedId)
        .collection('notifications').add({
      'type': 'report_received',
      'title': '⚠️ You have been reported',
      'body':
          'You have 80 hours to submit proof of your innocence. '
          'Otherwise your account will be flagged.',
      'data': {'reportId': ref.id},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[Report] submitted ${ref.id}');
    return ref.id;
  }

  /// User 2 submits their proof (counter-evidence).
  static Future<void> submitProof({
    required String reportId,
    required String proof,
  }) async {
    final me = FirebaseAuth.instance.currentUser!;
    if (proof.trim().length < 10) {
      throw Exception('Proof must be at least 10 characters');
    }

    final ref = _db.collection('reports').doc(reportId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Report not found');
    final data = snap.data()!;
    if (data['reportedId'] != me.uid) {
      throw Exception('You are not the reported user');
    }
    if (data['status'] != 'pending_proof') {
      throw Exception('This report is no longer accepting proof');
    }

    await ref.update({
      'reportedProof': proof,
      'status': 'under_review',
      'proofSubmittedAt': FieldValue.serverTimestamp(),
    });

    // Notify reporter
    await _db.collection('users').doc(data['reporterId'])
        .collection('notifications').add({
      'type': 'report_proof_submitted',
      'title': 'Report update',
      'body':
          '${data['reportedUsername']} has submitted a response to your report. '
          'An admin will review both sides.',
      'data': {'reportId': reportId},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[Report] proof submitted for $reportId');
  }

  /// Called by admin OR by a scheduled job when 80 hours elapse without proof.
  /// Marks user as cheater + notifies their past partners.
  static Future<void> markAsCheater(String reportId) async {
    final ref = _db.collection('reports').doc(reportId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    if (data['status'] != 'pending_proof') return;

    final reportedId = data['reportedId'] as String;
    final reportedUsername = data['reportedUsername'] as String;

    final now = DateTime.now();
    final deleteAt = now.add(const Duration(hours: 36));

    // Update report
    await ref.update({
      'status': 'cheater',
      'cheaterAt': FieldValue.serverTimestamp(),
      'deleteAt': Timestamp.fromDate(deleteAt),
    });

    // Mark user as cheater
    try {
      await _db.collection('users').doc(reportedId).update({
        'isBanned': true,
        'isCheater': true,
      });
    } catch (e) {
      debugPrint('[Report] user update error: $e');
    }

    // Notify past partners (users who have at least 1 partnership with the cheater)
    try {
      final partnerships = await _db.collection('partnerships')
          .where('userA', whereIn: [reportedId])
          .get();
      final partnerships2 = await _db.collection('partnerships')
          .where('userB', whereIn: [reportedId])
          .get();

      final partnerIds = <String>{};
      for (final p in partnerships.docs) {
        partnerIds.add(p.data()['userB']);
      }
      for (final p in partnerships2.docs) {
        partnerIds.add(p.data()['userA']);
      }
      partnerIds.remove(reportedId);

      for (final partnerId in partnerIds) {
        await _db.collection('users').doc(partnerId)
            .collection('notifications').add({
          'type': 'partner_became_cheater',
          'title': '⚠️ A past partner was flagged',
          'body':
              '$reportedUsername has been added to the Cheater Board. '
              'If you had a partnership with them, review your agreements.',
          'data': {'cheaterId': reportedId},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      debugPrint('[Report] notified ${partnerIds.length} partners');
    } catch (e) {
      debugPrint('[Report] partner notify error: $e');
    }

    // Notify reporter
    try {
      await _db.collection('users').doc(data['reporterId'])
          .collection('notifications').add({
        'type': 'report_accepted',
        'title': 'Report outcome',
        'body':
            '$reportedUsername failed to submit proof. They have been '
            'added to the Cheater Board.',
        'data': {'reportId': reportId},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    debugPrint('[Report] marked as cheater: $reportId');
  }

  /// Called when 36 hours have passed since cheaterAt.
  /// Deletes the user's account.
  static Future<void> deleteCheaterAccount(String reportId) async {
    final ref = _db.collection('reports').doc(reportId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    if (data['status'] != 'cheater') return;
    if (data['deletedAt'] != null) return; // already deleted

    final reportedId = data['reportedId'] as String;

    // Mark report as deleted
    await ref.update({
      'status': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
    });

    // Delete the user document
    try {
      await _db.collection('users').doc(reportedId).delete();
      debugPrint('[Report] deleted user $reportedId');
    } catch (e) {
      debugPrint('[Report] delete error: $e');
    }
  }

  /// Checks all pending reports and processes any that have passed deadlines.
  /// Call this on app startup or from a scheduled Cloud Function.
  static Future<void> processDeadlines() async {
    final now = DateTime.now();

    // 1. Expire proof deadlines
    try {
      final pending = await _db.collection('reports')
          .where('status', isEqualTo: 'pending_proof')
          .get();

      for (final doc in pending.docs) {
        final data = doc.data();
        final deadline = (data['proofDeadline'] as Timestamp?)?.toDate();
        if (deadline != null && now.isAfter(deadline)) {
          await markAsCheater(doc.id);
        }
      }
    } catch (e) {
      debugPrint('[Report] deadline process error: $e');
    }

    // 2. Delete cheaters past 36h window
    try {
      final cheaters = await _db.collection('reports')
          .where('status', isEqualTo: 'cheater')
          .get();

      for (final doc in cheaters.docs) {
        final data = doc.data();
        final deleteAt = (data['deleteAt'] as Timestamp?)?.toDate();
        if (deleteAt != null && now.isAfter(deleteAt)) {
          await deleteCheaterAccount(doc.id);
        }
      }
    } catch (e) {
      debugPrint('[Report] cheater delete error: $e');
    }
  }
}

