library comments_client;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// Roles supported by the Comments SaaS backend for authenticated users.
enum CommentsUserRole {
  user,
  mod,
  admin,
}

/// Lightweight description of the end-user interacting with the comment UI.
class CommentsExternalUser {
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

  Map<String, dynamic> toJson() => {
        'id': id,
        if (name != null) 'name': name,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };
}

/// Immutable representation of a comment returned by the API.
@immutable
class Comment {
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

  final String id;
  final String threadId;
  final String body;
  final String authorId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? status;
  final bool isDeleted;
  final bool isFlagged;
  final Map<String, dynamic> metadata;
}

/// Exception thrown when the backend answers with an error payload.
class CommentsApiException implements Exception {
  CommentsApiException(this.statusCode, this.message, {this.details});

  final int statusCode;
  final String message;
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
class CommentsClient {
  CommentsClient({
    required this.baseUrl,
    required this.apiKey,
    required this.externalUser,
    this.role = CommentsUserRole.user,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final CommentsExternalUser externalUser;
  final CommentsUserRole role;
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

  /// Creates a comment inside a thread. The method automatically injects the
  /// tenant and external user identifiers required by the backend.
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

  /// Manually refreshes the cached token. Useful when you update the local user
  /// representation and want the claims to be refreshed immediately.
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
