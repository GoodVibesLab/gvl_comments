/// Minimal configuration passed when loading comments for a user.
///
/// This model is used by [CommentsKit.listByThreadKey] and [CommentsKit.post]
/// to authenticate API calls on behalf of the end-user.
class CommentsConfig {
  /// Your GoodVibesLab project API key (starts with `cmt_live_`).
  final String installKey;

  /// A unique ID for the end-user in your app (e.g. user ID, UUID, Firebase ID).
  final String externalUserId;

  /// Optional display name for this user.
  final String? externalUserName;

  /// Builds a new configuration object.
  ///
  /// * [installKey] is the project key provided by GoodVibesLab.
  /// * [externalUserId] uniquely identifies the user in your system.
  /// * [externalUserName] optionally provides a friendly display name.
  const CommentsConfig({
    required this.installKey,
    required this.externalUserId,
    this.externalUserName,
  });
}

/// Model representing a single comment returned by the Comments API.
class CommentModel {
  /// Creates an immutable comment model.
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

  /// Creates an immutable comment model with optional author details.
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
  ///
  /// Missing values default to safe fallbacks, keeping the object usable even
  /// when the backend omits optional fields.
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
  /// In this case, the UI should replace the comment body with a message such as
  /// *"This comment has been reported."*. Flagged comments remain in the
  /// thread so the conversation structure is preserved.
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
  ///
  /// Use this property to decide whether to render [body] or an alternate
  /// placeholder in your UI.
  bool get isVisibleNormally => !isReported && !isModerated;
}

/// Representation of the current user interacting with the SDK.
class UserProfile {
  /// Builds a local user profile synchronized with the backend when necessary.
  /// Stable identifier for the user.
  final String id;

  /// Optional display name that can be synchronized with the backend.
  final String? name;

  /// Optional avatar URL for the user.
  final String? avatarUrl;

  /// Creates a new profile instance used throughout the widget tree.
  const UserProfile({required this.id, this.name, this.avatarUrl});
}

/// Moderation settings exposed by the backend for the current tenant.
class ModerationSettings {
  /// Whether end-users are allowed to report comments.
  final bool userReportsEnabled;

  /// Number of distinct reports before a comment is soft hidden.
  final int softHideAfterReports;

  /// Number of distinct reports before a comment is hard hidden.
  final int hardHideAfterReports;

  /// AI moderation mode (e.g. "none", "basic", "strict").
  final String aiMode;

  /// Whether the AI is allowed to auto-flag comments.
  final bool aiAutoFlag;

  /// Sensitivity threshold for AI moderation (0.0–1.0).
  final double aiSensitivity;

  const ModerationSettings({
    required this.userReportsEnabled,
    required this.softHideAfterReports,
    required this.hardHideAfterReports,
    required this.aiMode,
    required this.aiAutoFlag,
    required this.aiSensitivity,
  });

  factory ModerationSettings.fromJson(Map<String, dynamic> json) {
    return ModerationSettings(
      userReportsEnabled: json['userReportsEnabled'] as bool? ?? true,
      softHideAfterReports:
          (json['softHideAfterReports'] as num?)?.toInt() ?? 3,
      hardHideAfterReports:
          (json['hardHideAfterReports'] as num?)?.toInt() ?? 10,
      aiMode: json['aiMode'] as String? ?? 'none',
      aiAutoFlag: json['aiAutoFlag'] as bool? ?? true,
      aiSensitivity: (json['aiSensitivity'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
