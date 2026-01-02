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

  /// Known moderation status values returned by the API.
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  // ---------------------------------------------------------------------------
  // Reactions (optional)
  // ---------------------------------------------------------------------------

  /// The reaction selected by the current viewer, if any.
  ///
  /// This value is computed server-side and returned alongside hydrated
  /// comments. When not available, it defaults to `null`.
  final String? viewerReaction;

  /// Aggregated reaction counts for this comment.
  ///
  /// Keys are reaction identifiers (e.g. `like`, `love`) and values are the
  /// corresponding counts.
  final Map<String, int> reactionCounts;

  /// Total number of reactions for this comment.
  ///
  /// This value is redundant with [reactionCounts], but is convenient for UI.
  final int reactionTotal;

  /// Creates an immutable comment model with optional author details.
  const CommentModel({
    required this.id,
    required this.externalUserId,
    this.authorName,
    required this.body,
    required this.createdAt,
    this.avatarUrl,
    this.isFlagged = false,
    this.status = statusPending,

    // Reactions are optional and may be omitted by the backend.
    this.viewerReaction,
    this.reactionCounts = const <String, int>{},
    this.reactionTotal = 0,
  });

  /// Factory constructor for JSON deserialization.
  ///
  /// Missing values default to safe fallbacks, keeping the object usable even
  /// when the backend omits optional fields.
  factory CommentModel.fromJson(Map<String, dynamic> json) {
    // Parse counts from JSON (jsonb object -> Map<String, dynamic> -> Map<String,int>).
    final rawCounts = json['reaction_counts'];
    final Map<String, int> counts = <String, int>{};

    if (rawCounts is Map) {
      rawCounts.forEach((k, v) {
        if (k is String) {
          final numVal = v is num ? v : null;
          if (numVal != null) {
            final asInt = numVal.toInt();
            if (asInt > 0) counts[k] = asInt;
          }
        }
      });
    }

    final viewer = json['viewer_reaction'] as String?;
    final total = (json['reaction_total'] as num?)?.toInt() ??
        counts.values.fold<int>(0, (a, b) => a + b);

    final rawCreatedAt = json['created_at'];
    final DateTime createdAt;
    if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt.toUtc();
    } else if (rawCreatedAt is String) {
      // DateTime.parse supports ISO-8601. If the string has no timezone, it is treated as local.
      // We keep it as-is but normalize to UTC when possible.
      createdAt = DateTime.parse(rawCreatedAt).toUtc();
    } else if (rawCreatedAt is int) {
      // Support epoch millis (best-effort).
      createdAt =
          DateTime.fromMillisecondsSinceEpoch(rawCreatedAt, isUtc: true);
    } else {
      // Fallback: avoid crash, use epoch.
      createdAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    return CommentModel(
      id: json['id'] as String,
      externalUserId: json['external_user_id'] as String,
      authorName: json['author_name'] as String?,
      body: json['body'] as String? ?? '',
      createdAt: createdAt,
      avatarUrl: json['avatar_url_canonical'] as String?,
      isFlagged: json['is_flagged'] as bool? ?? false,
      status: (json['status'] as String?) ?? statusPending,
      viewerReaction:
          (viewer != null && viewer.trim().isNotEmpty) ? viewer.trim() : null,
      reactionCounts: counts,
      reactionTotal: total,
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
  bool get isReported => status == statusPending && isFlagged;

  /// Returns `true` if the comment has been explicitly moderated and marked
  /// as `"rejected"`.
  ///
  /// Rejected comments remain visible in the thread structure, but their
  /// content must be replaced by:
  /// *"This comment has been moderated."*
  bool get isModerated => status == statusRejected;

  /// Returns `true` when the comment body can be displayed as-is
  /// (i.e. the comment is neither reported nor moderated).
  ///
  /// Use this property to decide whether to render [body] or an alternate
  /// placeholder in your UI.
  bool get isVisibleNormally => !isReported && !isModerated;

  /// Returns a copy of this model with selectively overridden fields.
  ///
  /// This is used by the widget layer for optimistic updates.
  static const Object _unset = Object();
  CommentModel copyWith({
    String? id,
    String? externalUserId,
    String? authorName,
    String? body,
    DateTime? createdAt,
    String? avatarUrl,
    bool? isFlagged,
    String? status,
    Object? viewerReaction = _unset,
    Map<String, int>? reactionCounts,
    int? reactionTotal,
  }) {
    return CommentModel(
      id: id ?? this.id,
      externalUserId: externalUserId ?? this.externalUserId,
      authorName: authorName ?? this.authorName,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isFlagged: isFlagged ?? this.isFlagged,
      status: status ?? this.status,
      viewerReaction: viewerReaction == _unset
          ? this.viewerReaction
          : viewerReaction as String?,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      reactionTotal: reactionTotal ?? this.reactionTotal,
    );
  }
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
