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

/// Model representing a single comment returned by the Comments API.
class CommentModel {
  /// Unique identifier for the comment.
  final String id;

  /// Identifier of the end-user who authored the comment.
  final String externalUserId;

  /// Optional display name for the author.
  final String? authorName;

  /// Raw body text of the comment.
  /// May be hidden in the UI depending on moderation status.
  final String body;

  /// Timestamp when the comment was created.
  final DateTime createdAt;

  /// Optional avatar URL for the author.
  final String? avatarUrl;

  /// Whether this comment has been flagged by AI or user reports.
  ///
  /// Flagged comments are still visible, but may trigger a "reported"
  /// state depending on the moderation status.
  final bool isFlagged;

  /// Moderation status for the comment.
  ///
  /// Possible values include:
  /// - `"pending"`   → awaiting moderation
  /// - `"approved"`  → safe and fully visible
  /// - `"rejected"`  → moderated; content should be hidden in the UI
  final String status;

  const CommentModel({
    required this.id,
    required this.externalUserId,
    this.authorName,
    required this.body,
    required this.createdAt,
    this.avatarUrl,
    this.isFlagged = false,
    this.status = 'pending',
  });

  /// Factory constructor for JSON deserialization.
  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      externalUserId: json['external_user_id'] as String,
      authorName: json['author_name'] as String?,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      avatarUrl: json['avatar_url_canonical'] as String?,
      isFlagged: json['is_flagged'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
    );
  }

  // ---------------------------------------------------------------------------
  // Moderation helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` if the comment has been flagged (by AI or reports)
  /// **and** is still pending moderation.
  ///
  /// In this case, the UI should replace the comment body with a message such as:
  /// *"This comment has been reported."*
  bool get isReported => status == 'pending' && isFlagged;

  /// Returns `true` if the comment has been explicitly moderated and marked
  /// as `"rejected"`.
  ///
  /// Rejected comments remain visible in the thread structure, but their
  /// content must be replaced by:
  /// *"This comment has been moderated."*
  bool get isModerated => status == 'rejected';

  /// Returns `true` when the comment body can be displayed as-is
  /// (i.e. the comment is neither reported nor moderated).
  bool get isVisibleNormally => !isReported && !isModerated;
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