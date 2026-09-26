import 'dart:io';

/// How risky it is to delete a category. Drives default-checked state and UI colour.
enum Safety {
  /// Regenerated automatically; deleting only costs a slower next launch.
  safe,

  /// Safe, but the next build/install will re-download (dev caches).
  rebuild,

  /// Review before deleting (may contain data you want).
  review,
}

/// A directory (or glob-like set of children) we know is junk.
///
/// This list IS the product. Add an entry here and it shows up in the UI,
/// gets scanned, and can be cleaned — no other code changes needed.
class ScanTarget {
  const ScanTarget({
    required this.id,
    required this.title,
    required this.description,
    required this.paths,
    required this.safety,
    this.group = 'System',
    this.listChildren = true,
  });

  final String id;
  final String title;
  final String description;
  final String group;
  final Safety safety;

  /// Paths relative to home (`~/…`) or absolute.
  final List<String> paths;

  /// When true, each child of the path becomes its own selectable row
  /// (e.g. ~/Library/Caches/Google) instead of one row for the whole folder.
  final bool listChildren;

  List<String> get resolvedPaths {
    final home = Platform.environment['HOME'] ?? '';
    return paths.map((p) => p.startsWith('~') ? p.replaceFirst('~', home) : p).toList();
  }
}

const scanTargets = <ScanTarget>[
  // ── System / user ────────────────────────────────────────────────────────
  ScanTarget(
    id: 'user_caches',
    title: 'User Caches',
    description: 'App caches in ~/Library/Caches. Apps rebuild these on demand.',
    paths: ['~/Library/Caches'],
    safety: Safety.safe,
  ),
  ScanTarget(
    id: 'user_logs',
    title: 'User Logs',
    description: 'Diagnostic logs in ~/Library/Logs.',
    paths: ['~/Library/Logs'],
    safety: Safety.safe,
  ),
  ScanTarget(
    id: 'trash',
    title: 'Trash',
    description: 'Items already in the Trash. Cleaning empties the Trash.',
    paths: ['~/.Trash'],
    safety: Safety.safe,
    listChildren: false,
  ),
  ScanTarget(
    id: 'saved_state',
    title: 'Saved Application State',
    description: 'Window positions restored on relaunch.',
    paths: ['~/Library/Saved Application State'],
    safety: Safety.safe,
    listChildren: false,
  ),

  // ── Developer ────────────────────────────────────────────────────────────
  ScanTarget(
    id: 'xcode_derived',
    title: 'Xcode DerivedData',
    description: 'Intermediate build products. Next build is a clean build.',
    group: 'Developer',
    paths: ['~/Library/Developer/Xcode/DerivedData'],
    safety: Safety.rebuild,
  ),
  ScanTarget(
    id: 'xcode_archives',
    title: 'Xcode Archives',
    description: 'Archived builds (.xcarchive) used for App Store uploads.',
    group: 'Developer',
    paths: ['~/Library/Developer/Xcode/Archives'],
    safety: Safety.review,
  ),
  ScanTarget(
    id: 'ios_device_support',
    title: 'iOS Device Support',
    description: 'Debug symbols per iOS version. Re-downloaded when you plug the device in.',
    group: 'Developer',
    paths: ['~/Library/Developer/Xcode/iOS DeviceSupport'],
    safety: Safety.rebuild,
  ),
  ScanTarget(
    id: 'simulators',
    title: 'iOS Simulator Devices',
    description: 'Simulator disk images. Delete unused ones via "xcrun simctl delete unavailable".',
    group: 'Developer',
    paths: ['~/Library/Developer/CoreSimulator/Devices'],
    safety: Safety.review,
  ),
  ScanTarget(
    id: 'gradle',
    title: 'Gradle Caches',
    description: 'Android dependency + build caches in ~/.gradle/caches.',
    group: 'Developer',
    paths: ['~/.gradle/caches'],
    safety: Safety.rebuild,
  ),
  ScanTarget(
    id: 'pub_cache',
    title: 'Dart Pub Cache',
    description: 'Downloaded Dart/Flutter packages. Re-fetched by "flutter pub get".',
    group: 'Developer',
    paths: ['~/.pub-cache/hosted'],
    safety: Safety.rebuild,
  ),
  ScanTarget(
    id: 'cocoapods',
    title: 'CocoaPods Cache',
    description: 'Downloaded pods.',
    group: 'Developer',
    paths: ['~/Library/Caches/CocoaPods', '~/.cocoapods/repos'],
    safety: Safety.rebuild,
    listChildren: false,
  ),
  ScanTarget(
    id: 'npm',
    title: 'npm / Yarn / pnpm Cache',
    description: 'Package manager download caches.',
    group: 'Developer',
    paths: ['~/.npm/_cacache', '~/Library/Caches/Yarn', '~/Library/pnpm/store'],
    safety: Safety.rebuild,
    listChildren: false,
  ),
  ScanTarget(
    id: 'homebrew',
    title: 'Homebrew Cache',
    description: 'Downloaded bottles/formulae. Same as "brew cleanup --prune=all".',
    group: 'Developer',
    paths: ['~/Library/Caches/Homebrew'],
    safety: Safety.rebuild,
    listChildren: false,
  ),
  ScanTarget(
    id: 'pip',
    title: 'pip Cache',
    description: 'Python package downloads.',
    group: 'Developer',
    paths: ['~/Library/Caches/pip'],
    safety: Safety.rebuild,
    listChildren: false,
  ),
];
