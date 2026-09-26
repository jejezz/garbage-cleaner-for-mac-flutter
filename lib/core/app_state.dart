import 'package:flutter/foundation.dart';

import 'app_scanner.dart';
import 'native_bridge.dart';
import 'scan_targets.dart';
import 'scanner.dart';

/// Single source of truth for the UI. Pages read from this and call its
/// methods; it notifies listeners whenever something changes.
class AppState extends ChangeNotifier {
  // ── Disk ──────────────────────────────────────────────────────────────────
  VolumeInfo? volume;
  bool? fullDiskAccess;

  Future<void> refreshDisk() async {
    volume = await NativeBridge.volumeInfo();
    fullDiskAccess = await NativeBridge.hasFullDiskAccess();
    notifyListeners();
  }

  // ── Junk ──────────────────────────────────────────────────────────────────
  bool scanning = false;
  List<JunkItem> junk = [];
  final Set<String> selected = {};
  String? lastError;

  int get selectedBytes =>
      junk.where((j) => selected.contains(j.path)).fold(0, (s, j) => s + j.bytes);
  int get totalJunkBytes => junk.fold(0, (s, j) => s + j.bytes);

  Future<void> scanJunk() async {
    if (scanning) return;
    scanning = true;
    junk = [];
    selected.clear();
    lastError = null;
    notifyListeners();
    try {
      await for (final items in JunkScanner.scan(scanTargets)) {
        junk = items;
        // Pre-select what is safe to delete; leave "review" items unchecked.
        for (final j in items) {
          if (j.target.safety != Safety.review) selected.add(j.path);
        }
        notifyListeners();
      }
    } catch (e) {
      lastError = '$e';
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  void toggle(String path, bool on) {
    on ? selected.add(path) : selected.remove(path);
    notifyListeners();
  }

  void toggleTarget(ScanTarget t, bool on) {
    for (final j in junk.where((j) => j.target == t)) {
      on ? selected.add(j.path) : selected.remove(j.path);
    }
    notifyListeners();
  }

  bool cleaning = false;

  /// Bytes freed by the last clean; the UI shows a celebration while non-null.
  int? lastFreed;

  /// Whether the last clean went to the Trash (app uninstall) or was a
  /// permanent delete (junk).
  bool lastFreedToTrash = false;
  void dismissFreed() {
    lastFreed = null;
    notifyListeners();
  }

  /// Permanently deletes selected items (bypasses the Trash; a selected Trash
  /// item empties it). Returns bytes freed.
  Future<int> cleanSelected() async {
    cleaning = true;
    notifyListeners();
    final paths = selected.toList();
    final failed = await NativeBridge.deletePermanently(paths);
    final freed = junk
        .where((j) => selected.contains(j.path) && !failed.containsKey(j.path))
        .fold(0, (s, j) => s + j.bytes);
    junk = junk.where((j) => !selected.contains(j.path) || failed.containsKey(j.path)).toList();
    selected.retainAll(failed.keys);
    lastError = failed.isEmpty ? null : 'Could not remove ${failed.length} item(s): ${failed.values.first}';
    cleaning = false;
    lastFreed = freed;
    lastFreedToTrash = false;
    notifyListeners();
    await refreshDisk();
    return freed;
  }

  // ── Apps ──────────────────────────────────────────────────────────────────
  bool loadingApps = false;
  List<InstalledApp> apps = [];
  InstalledApp? selectedApp;
  List<Leftover> leftovers = [];
  final Set<String> selectedLeftovers = {};
  bool removeAppBundle = true;

  Future<void> loadApps() async {
    if (loadingApps) return;
    loadingApps = true;
    notifyListeners();
    apps = await AppScanner.listApps();
    loadingApps = false;
    notifyListeners();
  }

  Future<void> selectApp(InstalledApp? app) async {
    selectedApp = app;
    leftovers = [];
    selectedLeftovers.clear();
    removeAppBundle = true;
    notifyListeners();
    if (app == null) return;
    leftovers = await AppScanner.findLeftovers(app);
    selectedLeftovers.addAll(leftovers.map((l) => l.path));
    notifyListeners();
  }

  void toggleLeftover(String path, bool on) {
    on ? selectedLeftovers.add(path) : selectedLeftovers.remove(path);
    notifyListeners();
  }

  void setRemoveAppBundle(bool on) {
    removeAppBundle = on;
    notifyListeners();
  }

  int get uninstallBytes =>
      (removeAppBundle ? selectedApp?.bytes ?? 0 : 0) +
      leftovers.where((l) => selectedLeftovers.contains(l.path)).fold(0, (s, l) => s + l.bytes);

  Future<void> uninstallSelectedApp() async {
    final app = selectedApp;
    if (app == null) return;
    cleaning = true;
    notifyListeners();
    final paths = [...selectedLeftovers, if (removeAppBundle) app.info.path];
    final freedBefore = uninstallBytes;
    final failed = await NativeBridge.moveToTrash(paths);
    lastError = failed.isEmpty ? null : 'Could not remove: ${failed.values.first}';
    cleaning = false;
    if (failed.isEmpty) {
      lastFreed = freedBefore;
      lastFreedToTrash = true;
    }
    if (removeAppBundle && !failed.containsKey(app.info.path)) {
      apps.remove(app);
      selectedApp = null;
      leftovers = [];
      selectedLeftovers.clear();
    } else {
      leftovers = leftovers.where((l) => failed.containsKey(l.path)).toList();
      selectedLeftovers.retainAll(failed.keys);
    }
    notifyListeners();
    await refreshDisk();
  }
}
