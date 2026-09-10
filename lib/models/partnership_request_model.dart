import 'package:cloud_firestore/cloud_firestore.dart';

class PartnershipRequestModel {
  final String id;
  final String userA;         // initiator
  final String userB;         // receiver
  final String usernameA;
  final String usernameB;
  final String postId;        // optional - can be ''
  final String postContent;   // optional - can be ''
  final String status;        // pending / accepted / cancelled / expired
  final bool userAAccepted;
  final bool userBAccepted;
  final Timestamp createdAt;
  final Timestamp expiresAt;

  PartnershipRequestModel({
    required this.id,
    required this.userA,
    required this.userB,
    required this.usernameA,
    required this.usernameB,
    required this.postId,
    required this.postContent,
    required this.status,
    required this.userAAccepted,
    required this.userBAccepted,
    required this.createdAt,
    required this.expiresAt,
  });

  factory PartnershipRequestModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PartnershipRequestModel(
      id: doc.id,
      userA: d['userA'] ?? '',
      userB: d['userB'] ?? '',
      usernameA: d['usernameA'] ?? 'Unknown',
      usernameB: d['usernameB'] ?? 'Unknown',
      postId: d['postId'] ?? '',
      postContent: d['postContent'] ?? '',
      status: d['status'] ?? 'pending',
      userAAccepted: d['userAAccepted'] ?? false,
      userBAccepted: d['userBAccepted'] ?? false,
      createdAt: d['createdAt'] ?? Timestamp.now(),
      expiresAt: d['expiresAt'] ?? Timestamp.now(),
    );
  }
}
