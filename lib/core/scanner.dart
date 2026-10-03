import 'dart:io';

import 'package:path/path.dart' as p;

import 'scan_targets.dart';

/// One selectable row in the junk list: a path with its measured size.
class JunkItem {
  JunkItem({required this.target, required this.path, required this.bytes});
  final ScanTarget target;
  final String path;
  final int bytes;
  String get name => p.basename(path) == '.Trash' && path.contains('/Mobile Documents/') ? 'iCloud Drive Trash' : p.basename(path) == '.Trash' ? 'Trash' : p.basename(path);
}

/// Measures scan targets. Uses `du -sk` rather than walking the tree in Dart:
/// ~/Library/Caches alone can hold 500k+ files, and `du` is 5–10× faster than
/// stat()-ing each one from Dart. `du` is part of every macOS install.
class JunkScanner {
  /// Scan roots that exist but could not be read during the last [scan]
  /// (no permission, iCloud not available…). The UI surfaces these instead of
  /// silently showing nothing.
  static final List<String> unreadable = [];

  /// Scans every target and reports progress as each finishes.
  /// Items are sorted largest-first within the returned list.
  static Stream<List<JunkItem>> scan(List<ScanTarget> targets) async* {
    // Paths owned by a dedicated target must not also appear as a child of a
    // broader one (e.g. ~/Library/Caches/pip is "pip Cache", not "User Caches").
    final claimed = {for (final t in targets) ...t.resolvedPaths};

    unreadable.clear();
    final results = <JunkItem>[];
    for (final target in targets) {
      final paths = <String>[];
      for (final root in target.resolvedPaths) {
        if (!Directory(root).existsSync()) continue;
        if (!target.listChildren) {
          // Probe first: an unreadable root would otherwise measure as 0 bytes
          // and vanish from the list without any explanation.
          try {
            Directory(root).listSync(followLinks: false);
          } on FileSystemException {
            unreadable.add(root);
            continue;
          }
          paths.add(root);
          continue;
        }
        try {
          for (final child in Directory(root).listSync(followLinks: false)) {
            if (claimed.contains(child.path)) continue;
            if (p.basename(child.path).startsWith('.')) continue;
            paths.add(child.path);
          }
        } on FileSystemException {
          // No permission (Full Disk Access not granted) — skip quietly.
        }
      }
      if (paths.isEmpty) continue;

      final sizes = await _du(paths);
      results.addAll([
        for (final e in sizes.entries)
          if (e.value > 0) JunkItem(target: target, path: e.key, bytes: e.value),
      ]);
      results.sort((a, b) => b.bytes.compareTo(a.bytes));
      yield List.unmodifiable(results);
    }
  }

  /// Runs `du -sk` over [paths]. Returns bytes per path (0 if unreadable).
  static Future<Map<String, int>> _du(List<String> paths) async {
    final r = await Process.run('du', ['-sk', ...paths]);
    final out = <String, int>{for (final p in paths) p: 0};
    for (final line in (r.stdout as String).split('\n')) {
      final tab = line.indexOf('\t');
      if (tab < 0) continue;
      final kb = int.tryParse(line.substring(0, tab).trim()) ?? 0;
      out[line.substring(tab + 1)] = kb * 1024;
    }
    return out;
  }

  /// Sizes of arbitrary paths (used by the app-uninstaller for leftovers).
  static Future<Map<String, int>> sizeOf(List<String> paths) =>
      paths.isEmpty ? Future.value({}) : _du(paths);
}
