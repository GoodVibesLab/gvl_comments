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
  final String externalUserId;
  final String? authorName;
  final String body;
  final DateTime createdAt;
  final String? avatarUrl;

  CommentModel({
    required this.id,
    required this.externalUserId,
    this.authorName,
    required this.body,
    required this.createdAt,
    this.avatarUrl,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      externalUserId: json['external_user_id'] as String,
      authorName: json['author_name'] as String?,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      avatarUrl: json['avatar_url_canonical'] as String?,
    );
  }
}

class UserProfile {
  final String id;
  final String? name;
  final String? avatarUrl;
  const UserProfile({required this.id, this.name, this.avatarUrl});
}