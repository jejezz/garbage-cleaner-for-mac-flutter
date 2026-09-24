import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme, ThemeMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'about/macbroom_about.dart';
import 'app_identity.dart';
import 'core/app_state.dart';
import 'core/native_bridge.dart';
import 'features/apps/apps_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/junk/junk_page.dart';
import 'l10n/app_localizations.dart';
import 'theme/broom_theme.dart';
import 'widgets/freed_overlay.dart';
import 'widgets/nav_rail.dart';

const _windowSize = Size(820, 560);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // No title bar, no traffic lights, not in the Dock (LSUIElement in
  // Info.plist). Shown centered at launch; later opened under the tray icon.
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: _windowSize,
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      skipTaskbar: true,
      alwaysOnTop: true,
      backgroundColor: Color(0x00000000),
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  await _setUpTray();

  runApp(const App());
}

Future<void> _setUpTray() async {
  // The tray menu lives outside the widget tree, so resolve the locale here.
  final l10n = lookupAppLocalizations(
    resolveAppLocale(PlatformDispatcher.instance.locale, AppLocalizations.supportedLocales),
  );
  await trayManager.setIcon('assets/tray/tray_icon.png', isTemplate: true);
  await trayManager.setContextMenu(Menu(items: [
    MenuItem(key: 'open', label: 'Open ${AppIdentity.displayName}'),
    MenuItem(key: 'about', label: l10n.aboutMenuItem(AppIdentity.displayName)),
    MenuItem.separator(),
    MenuItem(key: 'quit', label: 'Quit ${AppIdentity.displayName}'),
  ]));
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with TrayListener, WindowListener {
  final state = AppState();
  final _navigatorKey = GlobalKey<NavigatorState>();
  int page = 0;

  /// True while the window was opened from the tray icon: then it behaves like
  /// a popover and dismisses on blur. At launch (or after "Open" from the menu)
  /// it stays until the user hides or quits it.
  bool popoverMode = false;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    NativeBridge.onReopen(_onReopen);
    state.refreshDisk();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  // ── Tray / window behaviour ──────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() => _toggleWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem item) {
    switch (item.key) {
      case 'open':
        _showUnderTray(popover: false);
      case 'about':
        _showAboutFromTray();
      case 'quit':
        exit(0);
    }
  }

  /// Popover behaviour: clicking anywhere else dismisses the window.
  @override
  void onWindowBlur() {
    if (popoverMode) _hide();
  }

  Future<void> _hide() async {
    popoverMode = false;
    await windowManager.hide();
  }

  Future<void> _toggleWindow() async {
    if (await windowManager.isVisible()) {
      await _hide();
    } else {
      await _showUnderTray();
    }
  }

  /// The app was launched again while running. The tray icon may have been
  /// dropped by the system (it happens after long uptimes), and setIcon alone
  /// reuses the dead status item — so destroy and recreate it, then show.
  /// Centered like at launch: a freshly created status item has no real
  /// position yet, so its bounds would put the window off screen.
  Future<void> _onReopen() async {
    await trayManager.destroy();
    await _setUpTray();
    popoverMode = false;
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
    state.refreshDisk();
  }

  Future<void> _showUnderTray({bool popover = true}) async {
    popoverMode = popover;
    final tray = await trayManager.getBounds();
    if (tray != null) {
      await windowManager.setPosition(
        Offset(tray.center.dx - _windowSize.width / 2, tray.bottom + 6),
      );
    }
    await windowManager.show();
    await windowManager.focus();
    state.refreshDisk();
  }

  Future<void> _showAboutFromTray() async {
    await _showUnderTray(popover: false);
    _showAbout();
  }

  void _showAbout() {
    final context = _navigatorKey.currentContext;
    if (context != null) showMacBroomAbout(context);
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      navigatorKey: _navigatorKey,
      title: AppIdentity.displayName,
      debugShowCheckedModeBanner: false,
      theme: MacosThemeData.dark(),
      darkTheme: MacosThemeData.dark(),
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: resolveAppLocale,
      // The About dialog and licenses page are Material widgets.
      builder: (context, child) => Theme(
        data: aboutMaterialTheme(seed: Broom.violet, surface: Broom.bg1),
        child: child!,
      ),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) => DefaultTextStyle(
          style: Broom.body,
          child: Container(
            decoration: const BoxDecoration(gradient: Broom.bgGradient),
            child: Stack(
              children: [
                // Ambient color blobs behind the glass
                const Positioned(top: -120, right: -80, child: _Blob(color: Broom.violet, size: 360)),
                const Positioned(bottom: -140, left: 60, child: _Blob(color: Broom.cyan, size: 320)),
                Row(
                  children: [
                    NavRail(
                      index: page,
                      onChanged: (i) => setState(() => page = i),
                      items: const [
                        NavItem(icon: CupertinoIcons.chart_pie_fill, label: 'Disk'),
                        NavItem(icon: CupertinoIcons.sparkles, label: 'Junk'),
                        NavItem(icon: CupertinoIcons.square_grid_2x2_fill, label: 'Apps'),
                      ],
                      onAbout: _showAbout,
                      onHide: _hide,
                      onQuit: () => exit(0),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(page),
                          child: switch (page) {
                            0 => DashboardPage(state: state, onGoToJunk: () => setState(() => page = 1), onGoToApps: () => setState(() => page = 2)),
                            1 => JunkPage(state: state),
                            _ => AppsPage(state: state),
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (state.lastFreed != null)
                  Positioned.fill(child: FreedOverlay(bytes: state.lastFreed!, onDone: state.dismissFreed)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)]),
          ),
        ),
      );
}
