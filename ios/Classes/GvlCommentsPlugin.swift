import Foundation
import Flutter
import UIKit
import Security

/// Native bridge for gvl_comments.
///
/// Exposes the app install binding used by the backend to prevent API key reuse
/// across unrelated apps.
///
/// Methods:
/// - getInstallBinding -> { packageName: String, teamId: String? }
/// - getPlatformVersion -> "iOS <version>" (legacy)
public final class GvlCommentsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "gvl_comments",
      binaryMessenger: registrar.messenger()
    )
    let instance = GvlCommentsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getInstallBinding":
      // Best-effort: never throw, keep payload stable.
      let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
      let teamId = Self.getTeamIdBestEffort()

      result([
        "packageName": bundleId,
        "teamId": teamId
      ])

    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Attempts to read the Team ID from entitlements.
  ///
  /// Strategy:
  /// 1) Try `com.apple.developer.team-identifier`
  /// 2) Fallback: parse `application-identifier` (format: TEAMID.bundleId)
  ///
  /// Returns nil when unavailable (simulator / unusual signing / missing entitlements).
  private static func getTeamIdBestEffort() -> String? {
    // This works only when the app is code signed (device builds).
    // On simulator it will usually return nil, which is fine.
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: "gvl_comments_teamid_probe",
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]

    // 1) Try read existing item (no write needed if already there)
    var item: CFTypeRef?
    var status = SecItemCopyMatching(query as CFDictionary, &item)

    // 2) If not found, add a throwaway item so we can read back access group
    if status == errSecItemNotFound {
      query[kSecValueData as String] = Data("1".utf8)
      status = SecItemAdd(query as CFDictionary, &item)
    }

    guard status == errSecSuccess else { return nil }

    // The access group is usually like: TEAMID.bundleId (or TEAMID.*)
    if let dict = item as? [String: Any],
       let ag = dict[kSecAttrAccessGroup as String] as? String {
      let trimmed = ag.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty { return nil }

      if let dot = trimmed.firstIndex(of: ".") {
        let team = String(trimmed[..<dot])
        return team.isEmpty ? nil : team
      }
      return trimmed
    }

    return nil
  }
}
