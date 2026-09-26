import Cocoa
import FlutterMacOS

/// The ONLY Swift code in this project. Everything here is something Dart
/// cannot do by itself on macOS. Each `case` below is one method that Dart
/// calls through `NativeBridge` (lib/core/native_bridge.dart).
///
/// Adding a new method = add a `case "name":` here + a Dart wrapper. That's it.
class NativeBridge {
  static let channelName = "garbage_cleaner/native"
  private static var channel: FlutterMethodChannel?

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler(handle)
    self.channel = channel
  }

  // Swift -> Dart: the app was launched again while already running (Finder,
  // Spotlight, `open`). Dart rebuilds the tray icon and shows the window.
  static func notifyReopen() {
    channel?.invokeMethod("reopen", arguments: nil)
  }

  private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {

    // Move files/folders to the Trash (reversible, like Finder's ⌘⌫).
    // args: { "paths": [String] }  ->  { "trashed": [String], "failed": {path: error} }
    case "moveToTrash":
      let paths = args["paths"] as? [String] ?? []
      var trashed: [String] = []
      var failed: [String: String] = [:]
      for p in paths {
        do {
          try FileManager.default.trashItem(at: URL(fileURLWithPath: p), resultingItemURL: nil)
          trashed.append(p)
        } catch {
          failed[p] = error.localizedDescription
        }
      }
      result(["trashed": trashed, "failed": failed])

    // Permanently delete files/folders (NOT reversible — bypasses the Trash).
    // The user's Trash folder itself (~/.Trash) is emptied in place rather
    // than removed, so Finder keeps a working Trash.
    // args: { "paths": [String] }  ->  { "deleted": [String], "failed": {path: error} }
    case "deletePermanently":
      let paths = args["paths"] as? [String] ?? []
      let fm = FileManager.default
      let trashDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").standardizedFileURL.path
      var deleted: [String] = []
      var failed: [String: String] = [:]
      for p in paths {
        let url = URL(fileURLWithPath: p).standardizedFileURL
        do {
          if url.path == trashDir {
            for child in try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
              try fm.removeItem(at: child)
            }
          } else {
            try fm.removeItem(at: url)
          }
          deleted.append(p)
        } catch {
          failed[p] = error.localizedDescription
        }
      }
      result(["deleted": deleted, "failed": failed])

    // Full Disk Access check. TCC has no public API, so the standard trick is
    // to actually open a file that TCC protects. (isReadableFile/access(2)
    // only checks POSIX bits and ignores TCC, so it must be a real open().)
    case "hasFullDiskAccess":
      let home = FileManager.default.homeDirectoryForCurrentUser
      let probes = ["Library/Application Support/com.apple.TCC/TCC.db",
                    "Library/Safari/Bookmarks.plist"]
      let granted = probes.contains { rel in
        FileHandle(forReadingAtPath: home.appendingPathComponent(rel).path) != nil
      }
      result(granted)

    // Deep-link into System Settings > Privacy & Security > Full Disk Access.
    case "openFullDiskAccessSettings":
      let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
      NSWorkspace.shared.open(url)
      result(nil)

    // Disk capacity. `volumeAvailableCapacityForImportantUsage` is what the
    // Finder / "About This Mac" show: it counts purgeable space as free.
    // -> { "total": Int64, "free": Int64 }
    case "volumeInfo":
      let url = URL(fileURLWithPath: args["path"] as? String ?? "/")
      do {
        let v = try url.resourceValues(forKeys: [.volumeTotalCapacityKey,
                                                 .volumeAvailableCapacityForImportantUsageKey])
        result(["total": v.volumeTotalCapacity ?? 0,
                "free": v.volumeAvailableCapacityForImportantUsage ?? 0])
      } catch {
        result(FlutterError(code: "volumeInfo", message: error.localizedDescription, details: nil))
      }

    // Read an .app bundle's identity. Bundle IDs are what tie an app to its
    // leftovers in ~/Library (e.g. com.spotify.client -> Caches/com.spotify.client).
    // -> { "bundleId": String?, "name": String?, "version": String? }
    case "appInfo":
      guard let path = args["path"] as? String, let bundle = Bundle(path: path) else {
        result(nil); return
      }
      let info = bundle.infoDictionary ?? [:]
      result(["bundleId": bundle.bundleIdentifier as Any,
              "name": (info["CFBundleDisplayName"] ?? info["CFBundleName"] ?? NSNull()) as Any,
              "version": info["CFBundleShortVersionString"] as Any])

    // Show the file in Finder.
    case "revealInFinder":
      if let path = args["path"] as? String {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
      }
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
