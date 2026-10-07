import 'dart:io';

import 'package:flutter/services.dart';

/// Dart side of the Swift bridge (macos/Runner/NativeBridge.swift).
/// One static method per Swift `case`. Keep these thin: no logic, just types.
class NativeBridge {
  static const _ch = MethodChannel('garbage_cleaner/native');

  /// Moves paths to the Trash. Returns paths that failed with their error.
  static Future<Map<String, String>> moveToTrash(List<String> paths) async {
    final r = await _ch.invokeMapMethod<String, dynamic>('moveToTrash', {'paths': paths});
    final failed = Map<String, String>.from(r?['failed'] as Map? ?? {});
    // Root-owned items (e.g. App Store / pkg-installed apps) can't be trashed
    // by us; Finder can, after asking the user for admin authorization.
    for (final path in failed.keys.toList()) {
      if (await _trashViaFinder(path)) failed.remove(path);
    }
    return failed;
  }

  static Future<bool> _trashViaFinder(String path) async {
    final escaped = path.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    try {
      final r = await Process.run('osascript', ['-e', 'tell application "Finder" to delete POSIX file "$escaped"']);
      // Trust the filesystem, not the exit code: a cancelled auth must not count as success.
      return r.exitCode == 0 && FileSystemEntity.typeSync(path, followLinks: false) == FileSystemEntityType.notFound;
    } on ProcessException {
      return false;
    }
  }

  /// Permanently deletes paths (bypasses the Trash). `~/.Trash` itself is
  /// emptied rather than removed. Returns paths that failed with their error.
  static Future<Map<String, String>> deletePermanently(List<String> paths) async {
    final r = await _ch.invokeMapMethod<String, dynamic>('deletePermanently', {'paths': paths});
    final failed = Map<String, String>.from(r?['failed'] as Map? ?? {});
    // Root-owned leftovers (e.g. an app trashed via Finder after admin auth)
    // can only be removed by Finder, which asks for authorization itself.
    final home = Platform.environment['HOME'] ?? '';
    if (failed.keys.any((p) => p == '$home/.Trash') && await _emptyTrashViaFinder()) {
      failed.remove('$home/.Trash');
    }
    return failed;
  }

  static Future<bool> _emptyTrashViaFinder() async {
    try {
      final r = await Process.run('osascript', ['-e', 'tell application "Finder" to empty the trash']);
      if (r.exitCode != 0) return false;
      final dir = Directory('${Platform.environment['HOME']}/.Trash');
      return dir.listSync().where((e) => !e.path.endsWith('/.DS_Store')).isEmpty;
    } on FileSystemException {
      return false;
    } on ProcessException {
      return false;
    }
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
