import 'dart:io';

import 'package:path/path.dart' as p;

import 'native_bridge.dart';
import 'scanner.dart';

/// An installed application plus the files it left around ~/Library.
class InstalledApp {
  InstalledApp({required this.info, required this.bytes});
  final AppInfo info;
  final int bytes;
  String get name => info.name ?? p.basenameWithoutExtension(info.path);
}

class Leftover {
  Leftover({required this.path, required this.bytes});
  final String path;
  final int bytes;
}

class AppScanner {
  static List<String> get _appDirs => [
        '/Applications',
        '${Platform.environment['HOME']}/Applications',
      ];

  /// Where macOS apps leave data. `<id>` is the bundle id (com.spotify.client).
  static List<String> get _leftoverDirs => [
        '~/Library/Application Support',
        '~/Library/Caches',
        '~/Library/Preferences',
        '~/Library/Logs',
        '~/Library/Containers',
        '~/Library/Group Containers',
        '~/Library/Saved Application State',
        '~/Library/HTTPStorages',
        '~/Library/WebKit',
        '~/Library/Cookies',
        '~/Library/LaunchAgents',
        '~/Library/Preferences/ByHost',
        '~/Library/Application Scripts',
        '~/Library/Application Support/CrashReporter',
        '~/Library/Internet Plug-Ins',
        '~/Library/PreferencePanes',
        '~/Library/Services',
        '~/Library/Receipts',
        '~/Library/Autosave Information',
        '~/Library/Metadata/CoreSpotlight',
        '~/Library/Daemon Containers',
      ].map((d) => d.replaceFirst('~', Platform.environment['HOME'] ?? '')).toList();

  static List<FileSystemEntity> _list(String dir) {
    try {
      return Directory(dir).listSync(followLinks: false);
    } on FileSystemException {
      return const []; // missing or no permission
    }
  }

  static Future<List<InstalledApp>> listApps() async {
    final bundles = <String>[];
    for (final dir in _appDirs) {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      for (final e in d.listSync(followLinks: false)) {
        if (e.path.endsWith('.app')) bundles.add(e.path);
      }
    }
    final sizes = await JunkScanner.sizeOf(bundles);
    final apps = <InstalledApp>[];
    for (final b in bundles) {
      final info = await NativeBridge.appInfo(b);
      if (info == null) continue;
      apps.add(InstalledApp(info: info, bytes: sizes[b] ?? 0));
    }
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return apps;
  }

  /// Finds files in ~/Library that belong to [app], by bundle id or app name.
  /// Name matching is fuzzy on purpose (many apps use their name, not the id),
  /// which is why the UI lets the user uncheck rows before deleting.
  static Future<List<Leftover>> findLeftovers(InstalledApp app) async {
    final id = app.info.bundleId?.toLowerCase();
    final name = app.name.toLowerCase();
    // Names to look for: display name, bundle file name, and both without spaces.
    final fileName = p.basenameWithoutExtension(app.info.path).toLowerCase();
    final names = <String>{
      for (final n in [name, fileName])
        if (n.length >= 4) ...[n, n.replaceAll(' ', '')],
    };
    // com.google.Chrome -> vendor "google", product "chrome". Many apps nest
    // their data as <vendor>/<product> (e.g. Application Support/Google/Chrome).
    final parts = id?.split('.') ?? const [];
    final vendor = parts.length >= 3 ? parts[1] : null;
    final product = parts.isNotEmpty ? parts.last : null;
    final matches = <String>[];

    bool matchesApp(String base) {
      final byId = id != null && id.isNotEmpty && base.contains(id);
      // Name match only for names long enough to not be noise ("Go", "IINA"…).
      final byName = names.any(base.contains);
      return byId || byName;
    }

    for (final dir in _leftoverDirs) {
      for (final e in _list(dir)) {
        final base = p.basename(e.path).toLowerCase();
        if (matchesApp(base)) {
          matches.add(e.path);
        } else if (vendor != null && base == vendor && e is Directory) {
          // One level deeper inside the vendor folder.
          for (final child in _list(e.path)) {
            final cb = p.basename(child.path).toLowerCase();
            if (matchesApp(cb) || (product != null && product.length >= 4 && cb.contains(product))) {
              matches.add(child.path);
            }
          }
        }
      }
    }
    final sizes = await JunkScanner.sizeOf(matches);
    return [for (final m in matches) Leftover(path: m, bytes: sizes[m] ?? 0)]
      ..sort((a, b) => b.bytes.compareTo(a.bytes));
  }
}
