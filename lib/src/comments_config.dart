import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' show Platform;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';

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

    String platform;
    if (kIsWeb) {
      platform = 'web';
    } else if (Platform.isAndroid) {
      platform = 'android';
    } else if (Platform.isIOS) {
      platform = 'ios';
    } else {
      platform = 'unknown';
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

    if (!kIsWeb && platform != 'unknown') {
      try {
        const channel = MethodChannel('gvl_comments');
        final map = await channel.invokeMapMethod<String, dynamic>('getInstallBinding');
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
        debugPrint('GVL Comments: native install binding not available ($e)');
        // Keep best-effort: do not fail SDK init if the native side is absent.
      }
    }

    debugPrint('GVL Comments Config: platform=$platform, package=$pkg, version=$ver, '
        'androidSha256=${androidSha256 ?? "null"}, iosTeamId=${iosTeamId ?? "null"}');

    return CommentsConfig._(
      installKey: installKey,
      apiBase: apiBase,
      platform: platform,
      packageName: pkg,
      appVersion: ver,
      androidSha256: androidSha256,
      iosTeamId: iosTeamId,
    );
  }
}
