import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String username;
  final String content;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final Timestamp createdAt;

  PostModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    required this.likesCount,
    required this.commentsCount,
    required this.viewsCount,
    required this.createdAt,
  });

  factory PostModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Unknown',
      content: data['content'] ?? '',
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      viewsCount: data['viewsCount'] ?? 0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'username': username,
    'content': content,
    'likesCount': likesCount,
    'commentsCount': commentsCount,
    'viewsCount': viewsCount,
    'createdAt': createdAt,
  };
}
