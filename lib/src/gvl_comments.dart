import 'dart:async';
import 'package:flutter/foundation.dart';
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
  static CommentsKit I() {
    final i = _instance;
    if (i == null) {
      throw StateError(
          'CommentsKit not initialized. Call CommentsKit.initialize() first.');
    }
    return i;
  }

  static CommentsKit get instance => I();

  final CommentsConfig _config;
  final ApiClient _http;
  final TokenStore _tokens = TokenStore();

  ModerationSettings? _cachedSettings;

  CommentsKit._(this._config, this._http);

  // ===== Logging (debug-only) =====

  static const String _logPrefix = 'gvl_comments:';

  static void _log(String message) {
    if (kReleaseMode) return;
    // ignore: avoid_print
    debugPrint('$_logPrefix $message');
  }

  static void _logError(String message, [Object? error]) {
    if (kReleaseMode) return;
    // ignore: avoid_print
    debugPrint(
        '$_logPrefix ERROR – $message${error != null ? " ($error)" : ""}');
  }

  static String _safeKeyPrefix(String key) {
    final k = key.trim();
    if (k.isEmpty) return '(empty)';
    if (k.length <= 10) return '$k…';
    return '${k.substring(0, 10)}…';
  }

  static String _safeUserId(String id) {
    final u = id.trim();
    if (u.isEmpty) return '(empty)';
    if (u.length <= 6) return u;
    return '${u.substring(0, 3)}…${u.substring(u.length - 2)}';
  }

  /// Current billing plan for this install (e.g. "free", "starter", "pro").
  ///
  /// The value is populated from the last successful `/token` call and cached
  /// in memory alongside the access token. It becomes `null` again when
  /// [invalidateToken] is called.
  String? get currentPlan => _tokens.plan;

  /// Last pagination cursor returned by the API (opaque).
  ///
  /// When present, pass it back via `cursor:` to fetch the next page.
  String? lastNextCursor;

  /// Whether the API indicates more pages are available.
  bool lastHasMore = false;

  /// Minimal initialization with install key only.
  ///
  /// Provide your GoodVibesLab [installKey] and an optional custom [httpClient]
  /// if you need advanced networking controls (for example interceptors or
  /// caching). Must be awaited before using [CommentsKit.I].
  static Future<void> initialize({
    required String installKey,
    http.Client? httpClient,
  }) async {
    final trimmedKey = installKey.trim();
    if (trimmedKey.isEmpty) {
      _logError(
        'install key missing. Create one at https://goodvibeslab.cloud and pass it via --dart-define=GVL_INSTALL_KEY="cmt_live_xxx"',
      );
      throw StateError('GVL install key missing');
    }
    final cfg = await CommentsConfig.detect(installKey: trimmedKey);
    _instance = CommentsKit._(cfg, ApiClient(httpClient: httpClient));
    _log(
        'initialized (platform=${cfg.platform}, package=${cfg.packageName}, key=${_safeKeyPrefix(cfg.installKey)})');
  }

  /// Disposes the SDK instance and clears cached tokens.
  void dispose() {
    invalidateToken();
    _http.close();
  }

  /// Clears the cached JWT (for example when the user changes).
  void invalidateToken() {
    _log('token cache cleared');
    lastNextCursor = null;
    lastHasMore = false;
    _tokens.clear();
    _cachedSettings = null;
  }

  // ===== Internal =====

  Future<String> _getBearer({UserProfile? user}) async {
    final cached = _tokens.validBearer();
    if (cached != null) {
      _log('auth token cache hit');
      return cached;
    }

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

    _log('requesting auth token');

    Map<String, dynamic> json;
    try {
      json = await _http.postJson(
        _config.apiBase.resolve('token'),
        body,
        headers: headers,
      );
    } catch (e) {
      _logError(
        'failed to obtain auth token. Check your install key at https://goodvibeslab.cloud (key=${_safeKeyPrefix(_config.installKey)})',
        e,
      );
      rethrow;
    }

    final token = json['access_token'] as String;
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    final plan = json['plan'] as String?;
    _tokens.save(token, expiresIn, plan: plan);
    _log(
        'auth token received (expiresIn=${expiresIn}s, plan=${plan ?? "unknown"})');
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

    final settings = ModerationSettings.fromJson(json);
    _cachedSettings = settings;
    return settings;
  }

  /// Lists comments for a thread key.
  ///
  /// Pagination:
  /// - Prefer [cursor] (opaque) which comes from the `x-next-cursor` response header.
  /// - [before] is legacy (ISO-8601 created_at) and may skip items when multiple
  ///   comments share the same timestamp.
  ///
  /// [limit] controls the maximum number of comments to retrieve per call. Throws when network calls fail.
  Future<List<CommentModel>> listByThreadKey(
    String threadKey, {
    required UserProfile user,
    int limit = 50,
    String? before,
    String? cursor,
  }) async {
    try {
      final bearer = await _getBearer(user: user);
      _log(
          'loading comments (limit=$limit${(cursor != null || before != null) ? ", paginated" : ""})');

      // Build a safe URL using queryParameters (no manual encoding, avoids double-encoding bugs).
      final params = <String, String>{
        'thread': threadKey,
        'limit': '$limit',
        if (cursor != null) 'cursor': cursor,
        if (cursor == null && before != null) 'before': before,
      };

      final url =
          _config.apiBase.resolve('comments').replace(queryParameters: params);

      final res = await _http.getRaw(
        url,
        headers: {'Authorization': 'Bearer $bearer'},
      );

      // Capture pagination headers (best-effort).
      lastNextCursor = res.headers['x-next-cursor'];
      final hm = res.headers['x-has-more']?.toLowerCase();
      lastHasMore = hm == 'true' || hm == '1';

      final list = await _http.decodeListResponse(res);
      return list.map((e) => CommentModel.fromJson(e)).toList();
    } catch (e, stack) {
      if (!kReleaseMode) {
        debugPrintStack(stackTrace: stack);
      }
      _logError('failed to load comments', e);
      throw StateError('Failed to load comments: $e');
    }
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
    _log('posting comment');
    final bearer = await _getBearer(user: user);
    try {
      final json = await _http.postJson(
        _config.apiBase.resolve('comments'),
        {
          'threadKey': threadKey,
          'body': body,
        },
        headers: {'Authorization': 'Bearer $bearer'},
      );
      _log('comment posted');
      return CommentModel.fromJson(json);
    } catch (e) {
      _logError('failed to post comment', e);
      rethrow;
    }
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
    _log('reporting comment');
    Map<String, dynamic> json;
    try {
      json = await _http.postJson(
        _config.apiBase.resolve('comments/report'),
        {
          'commentId': commentId,
          if (reason != null) 'reason': reason,
        },
        headers: {'Authorization': 'Bearer $bearer'},
      );
      _log('report sent');
    } catch (e) {
      _logError('failed to report comment', e);
      rethrow;
    }

    // Two possible shapes:
    // - duplicate: { "status": "ok", "duplicate": true }
    // - fresh: [ { ... row from comment_reports ... } ]
    return json['duplicate'] == true;
  }

  /// Sets (or clears) the current user's reaction on a comment.
  ///
  /// Passing a non-null [reaction] records the reaction for the current user.
  /// Passing `null` clears the existing reaction (if any).
  ///
  /// This call requires a valid user token and will throw if the network call
  /// fails.
  Future<void> setCommentReaction({
    required String commentId,
    required UserProfile user,
    required String? reaction,
  }) async {
    final bearer = await _getBearer(user: user);
    _log(
        'setting reaction comment=$commentId reaction=${reaction ?? "(clear)"}');

    try {
      await _http.postJson(
        _config.apiBase.resolve('comments/react'),
        {
          'commentId': commentId,
          // When null, the API treats it as a "remove".
          'reaction': reaction,
        },
        headers: {'Authorization': 'Bearer $bearer'},
      );
    } catch (e) {
      _logError('failed to set comment reaction', e);
      rethrow;
    }
  }

  /// Best-effort profile sync (name / avatar) based on the JWT.
  ///
  /// The call is intentionally resilient: errors are logged but not thrown to
  /// avoid disrupting the user experience.
  Future<void> identify(UserProfile user) async {
    try {
      _log('identify user=${_safeUserId(user.id)}');
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
    } catch (e, stack) {
      if (!kReleaseMode) {
        debugPrintStack(stackTrace: stack);
      }
      _logError('failed to identify user (non-fatal)', e);
      // Best-effort: do not throw.
    }
  }
}
