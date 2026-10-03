import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart' show ProgressCircle;
import 'package:path/path.dart' as p;

import '../../core/app_scanner.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/native_bridge.dart';
import '../../theme/broom_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/glass.dart';

/// Master/detail: app list on the left, leftovers for the selected app on the right.
class AppsPage extends StatefulWidget {
  const AppsPage({super.key, required this.state});
  final AppState state;

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  String filter = '';

  @override
  void initState() {
    super.initState();
    // Defer: notifying listeners synchronously inside initState would fire during build.
    // Always rescan on entry so the list is never stale.
    Future.microtask(widget.state.loadApps);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final apps = state.apps.where((a) => a.name.toLowerCase().contains(filter.toLowerCase())).toList();

    return Row(
      children: [
        // ── App list ──
        SizedBox(
          width: 250,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 12, 10),
              child: Row(children: [
                const Expanded(child: Text('Apps', style: Broom.h1)),
                Text('${state.apps.length}', style: Broom.caption),
                const SizedBox(width: 6),
                IconGhostButton(icon: CupertinoIcons.refresh, onPressed: () {
                  if (!state.loadingApps) state.loadApps();
                }),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
              child: _SearchField(onChanged: (v) => setState(() => filter = v)),
            ),
            Expanded(
              child: state.loadingApps
                  ? const Center(child: ProgressCircle())
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 8, 12),
                      itemCount: apps.length,
                      itemBuilder: (_, i) => _AppRow(app: apps[i], selected: apps[i] == state.selectedApp, onTap: () => state.selectApp(apps[i])),
                    ),
            ),
          ]),
        ),
        Container(width: 1, color: Broom.border),
        // ── Detail ──
        Expanded(child: state.selectedApp == null ? const _Empty() : _Detail(state: state)),
      ],
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;
  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: Broom.glass, borderRadius: BorderRadius.circular(10), border: Border.all(color: Broom.border)),
        child: Row(children: [
          const Icon(CupertinoIcons.search, size: 13, color: Broom.muted),
          const SizedBox(width: 6),
          Expanded(
            child: EditableText(
              controller: _controller,
              focusNode: _focus,
              style: Broom.body,
              cursorColor: Broom.violet,
              backgroundCursorColor: Broom.faint,
              onChanged: widget.onChanged,
            ),
          ),
        ]),
      );
}

class _AppRow extends StatefulWidget {
  const _AppRow({required this.app, required this.selected, required this.onTap});
  final InstalledApp app;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_AppRow> createState() => _AppRowState();
}

class _AppRowState extends State<_AppRow> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            gradient: sel ? Broom.accentGradient : null,
            color: sel ? null : (hover ? Broom.glass : const Color(0x00000000)),
            borderRadius: BorderRadius.circular(10),
            boxShadow: sel ? Broom.glow(Broom.violet, blur: 16, alpha: 0.45) : null,
          ),
          child: Row(children: [
            Expanded(child: Text(widget.app.name, style: Broom.body.copyWith(color: sel ? const Color(0xFFFFFFFF) : Broom.text), overflow: TextOverflow.ellipsis)),
            Text(formatBytes(widget.app.bytes), style: Broom.caption.copyWith(color: sel ? const Color(0xDDFFFFFF) : Broom.faint, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(CupertinoIcons.square_grid_2x2, size: 40, color: Broom.faint),
          SizedBox(height: 12),
          Text('Select an app to see its leftover files', style: Broom.caption),
        ]),
      );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.state});
  final AppState state;

  static String get _home => Platform.environment['HOME'] ?? '';

  @override
  Widget build(BuildContext context) {
    final app = state.selectedApp!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(gradient: Broom.coolGradient, borderRadius: BorderRadius.circular(14), boxShadow: Broom.glow(Broom.cyan, blur: 18)),
            child: const Icon(CupertinoIcons.app_fill, size: 22, color: Color(0xFFFFFFFF)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.name, style: Broom.h1.copyWith(fontSize: 20), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${app.info.bundleId ?? 'no bundle id'}  ·  v${app.info.version ?? '?'}', style: Broom.caption, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          children: [
            GlassCard(
              padding: EdgeInsets.zero,
              radius: 12,
              child: _row(checked: state.removeAppBundle, onChanged: state.setRemoveAppBundle, title: p.basename(app.info.path), subtitle: p.dirname(app.info.path), bytes: app.bytes, path: app.info.path, bold: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text('LEFTOVERS IN ~/LIBRARY · ${state.leftovers.length}', style: Broom.caption.copyWith(letterSpacing: 1.2, fontSize: 10.5, color: Broom.faint)),
            ),
            if (state.leftovers.isEmpty)
              const Padding(padding: EdgeInsets.all(8), child: Text('Nothing found.', style: Broom.caption))
            else
              GlassCard(
                padding: EdgeInsets.zero,
                radius: 12,
                child: Column(children: [
                  for (var i = 0; i < state.leftovers.length; i++) ...[
                    if (i > 0) Container(height: 1, color: Broom.border),
                    _row(
                      checked: state.selectedLeftovers.contains(state.leftovers[i].path),
                      onChanged: (v) => state.toggleLeftover(state.leftovers[i].path, v),
                      title: p.basename(state.leftovers[i].path),
                      subtitle: p.dirname(state.leftovers[i].path).replaceFirst(_home, '~'),
                      bytes: state.leftovers[i].bytes,
                      path: state.leftovers[i].path,
                    ),
                  ],
                ]),
              ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Broom.border)), color: Color(0x33070A16)),
        child: Row(children: [
          Expanded(
            child: Row(children: [
              Text(formatBytes(state.uninstallBytes), style: Broom.mono.copyWith(fontSize: 16)),
              const SizedBox(width: 6),
              const Text('to remove', style: Broom.caption),
            ]),
          ),
          GradientButton(
            label: state.cleaning ? 'Removing…' : 'Uninstall',
            icon: CupertinoIcons.trash_fill,
            gradient: Broom.dangerGradient,
            large: true,
            onPressed: state.cleaning || state.uninstallBytes == 0 ? null : () => _confirm(context),
          ),
        ]),
      ),
    ]);
  }

  Widget _row({required bool checked, required ValueChanged<bool> onChanged, required String title, required String subtitle, required int bytes, required String path, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(children: [
        BroomCheckbox(value: checked, onChanged: onChanged),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: bold ? Broom.h2 : Broom.body, overflow: TextOverflow.ellipsis),
            Text(subtitle, style: Broom.caption.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis),
          ]),
        ),
        IconGhostButton(icon: CupertinoIcons.folder, onPressed: () => NativeBridge.revealInFinder(path)),
        const SizedBox(width: 6),
        SizedBox(width: 76, child: Text(formatBytes(bytes), style: Broom.mono.copyWith(color: Broom.muted), textAlign: TextAlign.right)),
      ]),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final app = state.selectedApp!;
    final ok = await showConfirm(
      context,
      title: 'Uninstall ${app.name}?',
      message: '${formatBytes(state.uninstallBytes)} will be moved to the Trash.',
      action: 'Uninstall',
    );
    if (ok) await state.uninstallSelectedApp();
  }
}
