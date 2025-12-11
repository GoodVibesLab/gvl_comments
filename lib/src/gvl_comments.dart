import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'models.dart' hide CommentsConfig;
import 'token_store.dart';
import 'comments_config.dart';

/// High-level entry point for interacting with GoodVibesLab comments.
///
/// Use [initialize] once during app startup, then access the singleton via
/// [CommentsKit.I]. All network operations are routed through this instance.
class CommentsKit {
  static CommentsKit? _instance;

  /// Returns the previously initialized singleton instance.
  ///
  /// Call [initialize] before invoking this method. Accessing [I] without prior
  /// initialization will throw a runtime error.
  static CommentsKit I() => _instance!;

  final CommentsConfig _config;
  final ApiClient _http;
  final TokenStore _tokens = TokenStore();

  ModerationSettings? _cachedSettings;

  CommentsKit._(this._config, this._http);

  /// Current billing plan for this install (e.g. "free", "starter", "pro").
  ///
  /// The value is populated from the last successful `/token` call and cached
  /// in memory alongside the access token. It becomes `null` again when
  /// [invalidateToken] is called.
  String? get currentPlan => _tokens.plan;

  /// Minimal initialization with install key only.
  ///
  /// Provide your GoodVibesLab [installKey] and an optional custom [httpClient]
  /// if you need advanced networking controls (for example interceptors or
  /// caching). Must be awaited before using [CommentsKit.I].
  static Future<void> initialize({
    required String installKey,
    http.Client? httpClient,
  }) async {
    final cfg = await CommentsConfig.detect(installKey: installKey);
    _instance = CommentsKit._(cfg, ApiClient(httpClient: httpClient));
  }

  /// Clears the cached JWT (for example when the user changes).
  void invalidateToken() {
    _tokens.clear();
    _cachedSettings = null;
  }

  // ===== Internal =====

  Future<String> _getBearer({UserProfile? user}) async {
    final cached = _tokens.validBearer();
    if (cached != null) return cached;

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-platform': _config.platform,
      'x-package-name': _config.packageName,
      'x-app-version': _config.appVersion,
    };

    final body = <String, dynamic>{
      'apiKey': _config.installKey,
      if (user != null)
        'externalUser': {
          'id': user.id,
          if (user.name != null) 'name': user.name,
          if (user.avatarUrl != null) 'avatarUrl': user.avatarUrl,
        },
    };

    final json = await _http.postJson(
      _config.apiBase.resolve('token'),
      body,
      headers: headers,
    );

    //TODO remove debugPrint
    debugPrint('gvl_comments: obtained new token: $json');

    final token = json['access_token'] as String;
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    final plan = json['plan'] as String?;
    _tokens.save(token, expiresIn, plan: plan);
    return token;
  }

  // ===== Public SDK =====

  /// Fetches moderation settings for the current tenant.
  ///
  /// The result is cached in memory for the lifetime of the process. It is
  /// cleared when [invalidateToken] is called (for example when the user
  /// changes or you want to force a refresh).
  Future<ModerationSettings> getModerationSettings({
    UserProfile? user,
  }) async {
    if (_cachedSettings != null) return _cachedSettings!;

    final bearer = await _getBearer(user: user);

    final json = await _http.getJson(
      _config.apiBase.resolve('comments/settings'),
      headers: {'Authorization': 'Bearer $bearer'},
    );

    debugPrint('gvl_comments: moderation settings: $json');

    final settings = ModerationSettings.fromJson(json);
    _cachedSettings = settings;
    return settings;
  }

  /// Lists comments for a thread key.
  ///
  /// [before] is an optional ISO-8601 cursor (created_at). If provided, only
  /// comments with a `created_at` timestamp earlier than [before] are returned.
  /// This method handles pagination and returns comments in reverse
  /// chronological order. [limit] controls the maximum number of comments to
  /// retrieve per call. Throws when network calls fail.
  Future<List<CommentModel>> listByThreadKey(
      String threadKey, {
        required UserProfile user,
        int limit = 50,
        String? before,
  }) async {
    final bearer = await _getBearer(user: user);
    debugPrint('gvl_comments: apiBase=${_config.apiBase}');

    final params = <String, String>{
      'thread': threadKey,
      'limit': '$limit',
      if (before != null) 'before': before,
    };
    final query = Uri(queryParameters: params).query;

    final url = _config.apiBase.resolve('comments?$query');
    debugPrint('gvl_comments: listByThreadKey → $url');

    final list = await _http.getList(
      url,
      headers: {'Authorization': 'Bearer $bearer'},
    );
    return list
        .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Posts a new comment in the specified thread.
  ///
  /// The comment body is sent as-is; perform validation in your UI before
  /// calling this method. Returns the created [CommentModel] populated with
  /// server timestamps and moderation status. Requires the calling [user] to be
  /// authenticated via [initialize].
  Future<CommentModel> post({
    required String threadKey,
    required String body,
    required UserProfile user,
  }) async {
    final bearer = await _getBearer(user: user);
    final json = await _http.postJson(
      _config.apiBase.resolve('comments'),
      {
        'threadKey': threadKey,
        'body': body,
      },
      headers: {'Authorization': 'Bearer $bearer'},
    );
    return CommentModel.fromJson(json as Map<String, dynamic>);
  }

  /// Reports a comment.
  ///
  /// Returns `true` if this comment was already reported by the same user
  /// (duplicate), `false` if the report was freshly recorded by the backend.
  Future<bool> report({
    required String commentId,
    required UserProfile user,
    String? reason,
  }) async {
    final bearer = await _getBearer(user: user);
    final json = await _http.postJson(
      _config.apiBase.resolve('comments/report'),
      {
        'commentId': commentId,
        if (reason != null) 'reason': reason,
      },
      headers: {'Authorization': 'Bearer $bearer'},
    );

    // Two possible shapes:
    // - duplicate: { "status": "ok", "duplicate": true }
    // - fresh: [ { ... row from comment_reports ... } ]
    return json['duplicate'] == true;
  }

  /// Best-effort profile sync (name / avatar) based on the JWT.
  ///
  /// The call is intentionally resilient: errors are logged but not thrown to
  /// avoid disrupting the user experience.
  Future<void> identify(UserProfile user) async {
    try {
      final bearer = await _getBearer(user: user);

      await _http.postJson(
        _config.apiBase.resolve('profile/upsert'),
        {
          if (user.name != null) 'displayName': user.name,
          if (user.avatarUrl != null) 'avatarUrl': user.avatarUrl,
        },
        headers: {
          'Authorization': 'Bearer $bearer',
        },
      );
    } catch (e) {
      debugPrint('gvl_comments: error during identify(): $e');
    }
  }
}