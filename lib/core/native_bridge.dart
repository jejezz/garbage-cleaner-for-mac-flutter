import 'package:flutter/services.dart';

/// Dart side of the Swift bridge (macos/Runner/NativeBridge.swift).
/// One static method per Swift `case`. Keep these thin: no logic, just types.
class NativeBridge {
  static const _ch = MethodChannel('garbage_cleaner/native');

  /// Moves paths to the Trash. Returns paths that failed with their error.
  static Future<Map<String, String>> moveToTrash(List<String> paths) async {
    final r = await _ch.invokeMapMethod<String, dynamic>('moveToTrash', {'paths': paths});
    return Map<String, String>.from(r?['failed'] as Map? ?? {});
  }

  static Future<bool> hasFullDiskAccess() async =>
      await _ch.invokeMethod<bool>('hasFullDiskAccess') ?? false;

  static Future<void> openFullDiskAccessSettings() =>
      _ch.invokeMethod('openFullDiskAccessSettings');

  static Future<VolumeInfo> volumeInfo([String path = '/']) async {
    final r = await _ch.invokeMapMethod<String, dynamic>('volumeInfo', {'path': path});
    return VolumeInfo(total: (r?['total'] as num).toInt(), free: (r?['free'] as num).toInt());
  }

  static Future<AppInfo?> appInfo(String appPath) async {
    final r = await _ch.invokeMapMethod<String, dynamic>('appInfo', {'path': appPath});
    if (r == null) return null;
    return AppInfo(
      path: appPath,
      bundleId: r['bundleId'] as String?,
      name: r['name'] as String?,
      version: r['version'] as String?,
    );
  }

  /// Called when the app is launched again while already running.
  static void onReopen(void Function() callback) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'reopen') callback();
    });
  }

  static Future<void> revealInFinder(String path) =>
      _ch.invokeMethod('revealInFinder', {'path': path});
}

class VolumeInfo {
  const VolumeInfo({required this.total, required this.free});
  final int total;
  final int free;
  int get used => total - free;
  double get usedRatio => total == 0 ? 0 : used / total;
}

class AppInfo {
  const AppInfo({required this.path, this.bundleId, this.name, this.version});
  final String path;
  final String? bundleId;
  final String? name;
  final String? version;
}
