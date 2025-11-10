class CommentsConfig {
  /// Your GoodVibesLab project API key (starts with `cmt_live_`).
  final String installKey;

  /// A unique ID for the end-user in your app (e.g. user ID, UUID, Firebase ID).
  final String externalUserId;

  /// Optional display name for this user.
  final String? externalUserName;

  const CommentsConfig({
    required this.installKey,
    required this.externalUserId,
    this.externalUserName,
  });
}

class CommentModel {
  final String id;
  final String threadId;
  final String externalUserId;
  final String? authorName;
  final String body;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.threadId,
    required this.externalUserId,
    this.authorName,
    required this.body,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> j) => CommentModel(
    id: j['id'] as String,
    threadId: j['thread_id'] as String,
    externalUserId: j['external_user_id'] as String,
    authorName: j['author_name'] as String?,
    body: j['body'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}