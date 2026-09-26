import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart' show ProgressCircle;

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/native_bridge.dart';
import '../../core/scan_targets.dart';
import '../../core/scanner.dart';
import '../../theme/broom_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/glass.dart';
import '../../widgets/safety_badge.dart';

class JunkPage extends StatelessWidget {
  const JunkPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final byTarget = <ScanTarget, List<JunkItem>>{};
    for (final j in state.junk) {
      byTarget.putIfAbsent(j.target, () => []).add(j);
    }
    final targets = scanTargets.where(byTarget.containsKey).toList();
    final groups = <String, List<ScanTarget>>{};
    for (final t in targets) {
      groups.putIfAbsent(t.group, () => []).add(t);
    }

    return Column(
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Junk Files', style: Broom.h1),
                  const SizedBox(height: 4),
                  if (state.junk.isEmpty && !state.scanning)
                    const Text('Caches, logs and build artifacts that are safe to clear.', style: Broom.caption)
                  else
                    Row(children: [
                      GradientText(formatBytes(state.totalJunkBytes), style: Broom.display.copyWith(fontSize: 28)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(state.scanning ? 'found so far…' : 'in ${state.junk.length} items', style: Broom.caption),
                      ),
                    ]),
                ]),
              ),
              if (state.scanning) const Padding(padding: EdgeInsets.only(right: 10, bottom: 4), child: ProgressCircle(radius: 8)),
              GhostButton(label: state.junk.isEmpty ? 'Scan' : 'Rescan', icon: CupertinoIcons.arrow_clockwise, small: true, onPressed: state.scanning ? null : state.scanJunk),
            ],
          ),
        ),
        if (state.lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
            child: Text(state.lastError!, style: Broom.caption.copyWith(color: Broom.rose)),
          ),

        // ── List ──
        Expanded(
          child: state.junk.isEmpty && !state.scanning
              ? _Empty(onScan: state.scanJunk)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 16),
                  children: [
                    for (final g in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                        child: Text(g.key.toUpperCase(), style: Broom.caption.copyWith(letterSpacing: 1.2, fontSize: 10.5, color: Broom.faint)),
                      ),
                      for (final t in g.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TargetCard(state: state, target: t, items: byTarget[t]!),
                        ),
                    ],
                  ],
                ),
        ),

        // ── Footer ──
        Container(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Broom.border)), color: Color(0x33070A16)),
          child: Row(children: [
            Expanded(
              child: Row(children: [
                Text(formatBytes(state.selectedBytes), style: Broom.mono.copyWith(fontSize: 16)),
                const SizedBox(width: 6),
                const Text('selected', style: Broom.caption),
              ]),
            ),
            GradientButton(
              label: state.cleaning ? 'Cleaning…' : 'Clean',
              icon: CupertinoIcons.sparkles,
              large: true,
              onPressed: state.selected.isEmpty || state.cleaning ? null : () => _confirmClean(context),
            ),
          ]),
        ),
      ],
    );
  }

  Future<void> _confirmClean(BuildContext context) async {
    final ok = await showConfirm(
      context,
      title: 'Permanently delete ${formatBytes(state.selectedBytes)}?',
      message: '${state.selected.length} items will be deleted permanently, not moved to the Trash. This cannot be undone.',
      action: 'Clean',
    );
    if (ok) await state.cleanSelected();
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onScan});
  final VoidCallback onScan;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(gradient: Broom.accentGradient, shape: BoxShape.circle, boxShadow: Broom.glow(Broom.pink, blur: 44, alpha: 0.6)),
            child: const Icon(CupertinoIcons.sparkles, size: 36, color: Color(0xFFFFFFFF)),
          ),
          const SizedBox(height: 22),
          const Text('Ready to sweep', style: Broom.h1),
          const SizedBox(height: 6),
          const Text('Scan finds caches, logs and developer build junk.', style: Broom.caption),
          const SizedBox(height: 22),
          GradientButton(label: 'Smart Scan', icon: CupertinoIcons.sparkles, large: true, onPressed: onScan),
        ]),
      );
}

class _TargetCard extends StatefulWidget {
  const _TargetCard({required this.state, required this.target, required this.items});
  final AppState state;
  final ScanTarget target;
  final List<JunkItem> items;
  @override
  State<_TargetCard> createState() => _TargetCardState();
}

class _TargetCardState extends State<_TargetCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final items = widget.items;
    final total = items.fold(0, (s, j) => s + j.bytes);
    final selectedCount = items.where((j) => state.selected.contains(j.path)).length;
    final all = selectedCount == items.length, none = selectedCount == 0;
    final accent = SafetyBadge.colorOf(widget.target.safety);

    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 14,
      child: Column(children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                BroomCheckbox(value: all ? true : (none ? false : null), onChanged: (_) => state.toggleTarget(widget.target, !all)),
                const SizedBox(width: 12),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_iconFor(widget.target), size: 16, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(widget.target.title, style: Broom.h2),
                      const SizedBox(width: 8),
                      SafetyBadge(widget.target.safety),
                    ]),
                    const SizedBox(height: 2),
                    Text(widget.target.description, style: Broom.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const SizedBox(width: 12),
                Text(formatBytes(total), style: Broom.mono.copyWith(fontSize: 14)),
                const SizedBox(width: 10),
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(CupertinoIcons.chevron_right, size: 12, color: Broom.faint),
                ),
              ]),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !expanded
              ? const SizedBox(width: double.infinity)
              : Container(
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Broom.border))),
                  padding: const EdgeInsets.fromLTRB(60, 6, 12, 8),
                  child: Column(children: [
                    for (final j in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          BroomCheckbox(value: state.selected.contains(j.path), onChanged: (v) => state.toggle(j.path, v)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(j.name, style: Broom.body, overflow: TextOverflow.ellipsis)),
                          IconGhostButton(icon: CupertinoIcons.folder, onPressed: () => NativeBridge.revealInFinder(j.path)),
                          const SizedBox(width: 6),
                          SizedBox(width: 76, child: Text(formatBytes(j.bytes), style: Broom.mono.copyWith(color: Broom.muted), textAlign: TextAlign.right)),
                        ]),
                      ),
                  ]),
                ),
        ),
      ]),
    );
  }

  IconData _iconFor(ScanTarget t) => switch (t.id) {
        'user_caches' => CupertinoIcons.archivebox_fill,
        'user_logs' => CupertinoIcons.doc_text_fill,
        'trash' => CupertinoIcons.trash_fill,
        'saved_state' => CupertinoIcons.macwindow,
        'xcode_derived' || 'xcode_archives' || 'ios_device_support' => CupertinoIcons.hammer_fill,
        'simulators' => CupertinoIcons.device_phone_portrait,
        'gradle' => CupertinoIcons.cube_box_fill,
        'pub_cache' => CupertinoIcons.cube_fill,
        'homebrew' => CupertinoIcons.tortoise_fill,
        _ => CupertinoIcons.folder_fill,
      };
}
