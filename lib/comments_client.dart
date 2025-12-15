library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Roles supported by the Comments SaaS backend for authenticated users.
///
/// The role influences what the backend allows the caller to do (for example
/// moderating content or listing flagged comments). Use [CommentsUserRole.user]
/// for regular end-users unless your API key is explicitly scoped for
/// moderation.
enum CommentsUserRole {
  /// Regular end-user who can read and publish comments.
  user,

  /// Moderator account with elevated permissions to handle reports.
  mod,

  /// Administrator account with full control over the comment project.
  admin,
}

/// Lightweight description of the end-user interacting with the comment UI.
class CommentsExternalUser {
  /// Creates an external user representation passed to the backend for JWT
  /// generation.
  ///
  /// * [id] must be a stable identifier from your application.
  /// * [name] and [avatarUrl] are optional and can be omitted when not known.
  CommentsExternalUser({
    required this.id,
    this.name,
    this.avatarUrl,
  });

  /// Stable identifier of the user inside your application.
  final String id;

  /// Optional display name shown next to comments.
  final String? name;

  /// Optional avatar URL that will be stored on the platform.
  final String? avatarUrl;

  /// Serializes the user into the payload expected by the token endpoint.
  Map<String, dynamic> toJson() => {
        'id': id,
        if (name != null) 'name': name,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };
}

/// Immutable representation of a comment returned by the API.
@immutable
class Comment {
  /// Builds a new [Comment] instance.
  ///
  /// Most fields are provided by the backend; [metadata] defaults to an empty
  /// map if none is present in the payload.
  const Comment({
    required this.id,
    required this.threadId,
    required this.body,
    required this.authorId,
    this.authorName,
    this.authorAvatarUrl,
    this.parentId,
    required this.createdAt,
    required this.updatedAt,
    this.status,
    this.isDeleted = false,
    this.isFlagged = false,
    this.metadata = const <String, dynamic>{},
  });

  /// Constructs a [Comment] from a JSON object returned by the API.
  ///
  /// This parser is forgiving and treats missing optional fields as `null`.
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      body: json['body'] as String,
      authorId: json['external_user_id'] as String,
      authorName: json['author_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      parentId: json['parent_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      status: json['status'] as String?,
      isDeleted: json['is_deleted'] == true,
      isFlagged: json['is_flagged'] == true,
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.unmodifiable(
              Map<String, dynamic>.from(json['metadata'] as Map))
          : const {},
    );
  }

  /// Unique identifier of the comment.
  final String id;

  /// Identifier of the thread that contains this comment.
  final String threadId;

  /// Raw text body of the comment.
  final String body;

  /// Identifier of the external user who authored the comment.
  final String authorId;

  /// Optional display name of the author when provided.
  final String? authorName;

  /// Optional avatar URL associated with the author.
  final String? authorAvatarUrl;

  /// Identifier of the parent comment when this entry is a reply.
  final String? parentId;

  /// Timestamp when the comment was created.
  final DateTime createdAt;

  /// Timestamp when the comment was last updated.
  final DateTime updatedAt;

  /// Moderation status returned by the backend (for example `pending`,
  /// `approved`, or `rejected`).
  final String? status;

  /// Indicates whether the comment has been deleted server-side.
  final bool isDeleted;

  /// Indicates whether the comment has been flagged by reports or automation.
  final bool isFlagged;

  /// Arbitrary key/value metadata associated with the comment.
  final Map<String, dynamic> metadata;
}

/// Exception thrown when the backend answers with an error payload.
class CommentsApiException implements Exception {
  /// Builds an exception with the HTTP status code, a stable error message and
  /// optional details from the backend response.
  CommentsApiException(this.statusCode, this.message, {this.details});

  /// HTTP status code returned by the API.
  final int statusCode;

  /// Machine-readable error message (for example `invalid_token_response`).
  final String message;

  /// Additional information returned by the backend when available.
  final Object? details;

  @override
  String toString() =>
      'CommentsApiException(statusCode: $statusCode, message: $message, details: $details)';
}

class _AuthToken {
  _AuthToken({required this.token, required this.expiresAt, required this.tenantId});

  final String token;
  final DateTime expiresAt;
  final String tenantId;

  bool get isExpired => DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 2)));
}

/// High level client that wraps the HTTP API exposed by the Comments backend.
///
/// The client handles authentication, token caching, and JSON parsing so that
/// you can focus on rendering comments in your Flutter app. Use a single
/// instance per user session and call [close] when it is no longer needed.
class CommentsClient {
  /// Creates a new client configured for your Comments project.
  ///
  /// * [baseUrl] should point to the backend root (e.g. `https://api.example`).
  /// * [apiKey] is your project API key used to obtain JWTs.
  /// * [externalUser] identifies the current user and is embedded in tokens.
  /// * [role] defaults to [CommentsUserRole.user] for regular usage.
  /// * [httpClient] can be provided to reuse an existing HTTP client.
  CommentsClient({
    required this.baseUrl,
    required this.apiKey,
    required this.externalUser,
    this.role = CommentsUserRole.user,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Base URL of the Comments backend.
  final String baseUrl;

  /// Project API key used to exchange for short-lived tokens.
  final String apiKey;

  /// Representation of the current end-user used for token generation.
  final CommentsExternalUser externalUser;

  /// Permission level assigned to the generated tokens.
  final CommentsUserRole role;

  /// Underlying HTTP client used for all requests.
  final http.Client _http;

  _AuthToken? _cachedToken;

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final uri = Uri.parse(normalizedBase).resolve(path.startsWith('/') ? path.substring(1) : path);
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  /// Issues a fresh access token or reuses an existing one if it is still valid.
  Future<_AuthToken> _ensureToken() async {
    final token = _cachedToken;
    if (token != null && !token.isExpired) {
      return token;
    }

    final uri = _uri('/api/token');
    final response = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'apiKey': apiKey,
        'externalUser': externalUser.toJson(),
        'role': role.name,
      }),
    );

    if (response.statusCode >= 400) {
      throw _mapError(response);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final expiresIn = payload['expires_in'] as int? ?? 3600;
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    final tokenType = payload['token_type'] as String? ?? 'bearer';
    final tokenValue = payload['access_token'] as String?;
    final tenantId = payload['tenant_id'] as String?;

    if (tokenValue == null || tenantId == null) {
      throw CommentsApiException(response.statusCode, 'invalid_token_response', details: payload);
    }

    final cached = _AuthToken(
      token: tokenType.toLowerCase() == 'bearer' ? 'Bearer $tokenValue' : tokenValue,
      expiresAt: expiresAt,
      tenantId: tenantId,
    );

    _cachedToken = cached;
    return cached;
  }

  /// Lists approved comments for a given thread.
  ///
  /// The returned collection is ordered according to [order]. By default the
  /// backend sorts by `created_at` descending. Pass a PostgREST-style order
  /// string (e.g. `"created_at.asc"`) to change the sorting. Throws
  /// [CommentsApiException] when the request fails or the response cannot be
  /// parsed.
  Future<List<Comment>> listComments({
    required String threadId,
    String order = 'created_at.desc',
  }) async {
    final token = await _ensureToken();
    final uri = _uri('/api/comments', {
      'thread_id': threadId,
      'order': order,
    });

    final response = await _http.get(uri, headers: {
      'Authorization': token.token,
    });

    if (response.statusCode >= 400) {
      throw _mapError(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw CommentsApiException(
        response.statusCode,
        'invalid_response',
        details: decoded,
      );
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Comment.fromJson)
        .toList(growable: false);
  }

  /// Creates a comment inside a thread.
  ///
  /// The method automatically injects the tenant and external user identifiers
  /// required by the backend. Returns the created [Comment] as acknowledged by
  /// the server or throws [CommentsApiException] if the call fails. Provide
  /// [parentId] to create a reply, [metadata] for custom attributes, and
  /// override [authorName] or [authorAvatarUrl] to bypass the defaults taken
  /// from [externalUser].
  Future<Comment> createComment({
    required String threadId,
    required String body,
    String? parentId,
    Map<String, dynamic>? metadata,
    String? authorName,
    String? authorAvatarUrl,
  }) async {
    final token = await _ensureToken();

    final uri = _uri('/api/comments');
    final response = await _http.post(
      uri,
      headers: {
        'Authorization': token.token,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'tenant_id': token.tenantId,
        'thread_id': threadId,
        'external_user_id': externalUser.id,
        'author_name': authorName ?? externalUser.name,
        'author_avatar_url': authorAvatarUrl ?? externalUser.avatarUrl,
        'body': body,
        if (parentId != null) 'parent_id': parentId,
        if (metadata != null) 'metadata': metadata,
      }),
    );

    if (response.statusCode >= 400) {
      throw _mapError(response);
    }

    final payload = jsonDecode(response.body);

    if (payload is List && payload.isNotEmpty && payload.first is Map<String, dynamic>) {
      return Comment.fromJson(payload.first as Map<String, dynamic>);
    }
    if (payload is Map<String, dynamic>) {
      return Comment.fromJson(payload);
    }

    throw CommentsApiException(response.statusCode, 'unexpected_response', details: payload);
  }

  /// Manually refreshes the cached token.
  ///
  /// Useful when you update the local user representation and want the claims
  /// to be refreshed immediately.
  Future<void> refreshToken() async {
    _cachedToken = null;
    await _ensureToken();
  }

  /// Releases the underlying HTTP client when you are done with the instance.
  void close() {
    _http.close();
  }

  CommentsApiException _mapError(http.Response response) {
    Object? details;
    String message = 'http_error';

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        message = decoded['error'] as String? ?? message;
        details = decoded['details'] ?? decoded['message'];
      }
    } catch (_) {
      message = response.reasonPhrase ?? message;
    }

    return CommentsApiException(response.statusCode, message, details: details);
  }
}
