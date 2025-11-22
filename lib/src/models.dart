/// Minimal configuration passed when loading comments for a user.
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

/// Comment returned by the API and rendered by the widgets.
class CommentModel {
  /// Unique identifier for the comment.
  final String id;

  /// Identifier of the author supplied by the host app.
  final String externalUserId;

  /// Optional author display name.
  final String? authorName;

  /// Body of the comment.
  final String body;

  /// Creation timestamp for the comment.
  final DateTime createdAt;

  /// Optional avatar URL associated with the author.
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

/// Representation of the current user interacting with the SDK.
class UserProfile {
  /// Stable identifier for the user.
  final String id;

  /// Optional display name that can be synchronized with the backend.
  final String? name;

  /// Optional avatar URL for the user.
  final String? avatarUrl;

  const UserProfile({required this.id, this.name, this.avatarUrl});
}