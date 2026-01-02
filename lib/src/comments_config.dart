import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:gvl_comments/src/utils/comments_logger.dart';

/// Runtime configuration detected from the host platform and app metadata.
class CommentsConfig {
  /// Your GoodVibesLab install key (for example `cmt_live_xxx`).
  final String installKey;

  /// Base API endpoint used by the SDK.
  final Uri apiBase;

  /// Platform identifier (`android`, `ios`, `web`, or `unknown`).
  final String platform;

  /// Host app package/bundle identifier if available.
  final String packageName;

  /// Host app version string if available.
  final String appVersion;

  /// Android signing certificate SHA-256 (hex, uppercase) if available.
  ///
  /// Populated via the native plugin when running on Android.
  final String? androidSha256;

  /// iOS Team ID if available.
  ///
  /// Populated via the native plugin when running on iOS.
  final String? iosTeamId;

  CommentsConfig._({
    required this.installKey,
    required this.apiBase,
    required this.platform,
    required this.packageName,
    required this.appVersion,
    this.androidSha256,
    this.iosTeamId,
  });

  /// Detects platform, package, and version metadata.
  static Future<CommentsConfig> detect({required String installKey}) async {
    // Base API can be overridden via --dart-define, but remains opaque to apps.
    final apiBase = Uri.parse(
      const String.fromEnvironment(
        'GVL_API_BASE',
        defaultValue: 'https://api.goodvibeslab.cloud/comments/v1/',
      ),
    );
    final String platformName;
    if (kIsWeb) {
      platformName = 'web';
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          platformName = 'android';
          break;
        case TargetPlatform.iOS:
          platformName = 'ios';
          break;
        default:
          platformName = 'unknown';
      }
    }

    String pkg = 'unknown';
    String ver = '0.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      pkg = info.packageName;
      ver = info.version;
    } catch (_) {}

    // Best-effort native binding (Android SHA-256 / iOS TeamID).
    String? androidSha256;
    String? iosTeamId;

    if (!kIsWeb && (platformName == 'android' || platformName == 'ios')) {
      try {
        const channel = MethodChannel('gvl_comments');
        final map =
            await channel.invokeMapMethod<String, dynamic>('getInstallBinding');
        if (map != null) {
          final pkgFromNative = (map['packageName'] as String?)?.trim();
          final shaFromNative = (map['sha256'] as String?)?.trim();
          final teamFromNative = (map['teamId'] as String?)?.trim();

          // If native provides a package/bundle id, prefer it.
          if (pkgFromNative != null && pkgFromNative.isNotEmpty) {
            pkg = pkgFromNative;
          }

          if (shaFromNative != null && shaFromNative.isNotEmpty) {
            androidSha256 = shaFromNative;
          }
          if (teamFromNative != null && teamFromNative.isNotEmpty) {
            iosTeamId = teamFromNative;
          }
        }
      } catch (e) {
        CommentsLogger.error('native install binding not available: $e');
        // Keep best-effort: do not fail SDK init if the native side is absent.
      }
    }

    if (kDebugMode) {
      CommentsLogger.debug(
        'GVL Comments Config: platform=$platformName, package=$pkg, version=$ver, '
        'androidSha256=${androidSha256 ?? "null"}, iosTeamId=${iosTeamId ?? "null"}',
      );
    }

    return CommentsConfig._(
      installKey: installKey,
      apiBase: apiBase,
      platform: platformName,
      packageName: pkg,
      appVersion: ver,
      androidSha256: androidSha256,
      iosTeamId: iosTeamId,
    );
  }
}

extension CommentsConfigTokenHeaders on CommentsConfig {
  /// Headers required by the token endpoint to validate app bindings.
  ///
  /// - Always includes platform, package name and app version.
  /// - Adds Android SHA-256 or iOS Team ID when available.
  Map<String, String> tokenHeaders() {
    final headers = <String, String>{
      'x-platform': platform,
      'x-package-name': packageName,
      'x-app-version': appVersion,
    };

    if (platform == 'android' &&
        androidSha256 != null &&
        androidSha256!.trim().isNotEmpty) {
      headers['x-android-sha256'] = androidSha256!.trim();
    }

    if (platform == 'ios' &&
        iosTeamId != null &&
        iosTeamId!.trim().isNotEmpty) {
      headers['x-ios-team-id'] = iosTeamId!.trim();
    }

    return headers;
  }
}
