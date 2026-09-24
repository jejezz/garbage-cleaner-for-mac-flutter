import 'package:flutter/cupertino.dart';

import '../l10n/app_localizations.dart';
import '../theme/broom_theme.dart';

class NavItem {
  const NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Left rail: logo, icon buttons with a glowing gradient pill on the active one.
class NavRail extends StatelessWidget {
  const NavRail({super.key, required this.index, required this.onChanged, required this.items, required this.onAbout, required this.onHide, required this.onQuit});
  final int index;
  final ValueChanged<int> onChanged;
  final List<NavItem> items;
  final VoidCallback onAbout;
  final VoidCallback onHide;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      decoration: const BoxDecoration(
        color: Broom.railBg,
        border: Border(right: BorderSide(color: Broom.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const _Logo(),
          const SizedBox(height: 26),
          for (var i = 0; i < items.length; i++) _RailButton(item: items[i], active: i == index, onTap: () => onChanged(i)),
          const Spacer(),
          _RailButton(item: NavItem(icon: CupertinoIcons.info_circle, label: AppLocalizations.of(context).aboutTooltip), active: false, onTap: onAbout, dim: true),
          // Hide = collapse back into the menubar; the app keeps running.
          _RailButton(item: const NavItem(icon: CupertinoIcons.chevron_up_circle, label: 'Hide'), active: false, onTap: onHide, dim: true),
          _RailButton(item: const NavItem(icon: CupertinoIcons.power, label: 'Quit'), active: false, onTap: onQuit, dim: true),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: Broom.accentGradient,
          borderRadius: BorderRadius.circular(13),
          boxShadow: Broom.glow(Broom.pink, blur: 22, alpha: 0.55),
        ),
        padding: const EdgeInsets.all(9),
        child: Image.asset('assets/broom_glyph.png', filterQuality: FilterQuality.medium),
      );
}

class _RailButton extends StatefulWidget {
  const _RailButton({required this.item, required this.active, required this.onTap, this.dim = false});
  final NavItem item;
  final bool active;
  final VoidCallback onTap;
  final bool dim;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final fg = active ? const Color(0xFFFFFFFF) : (hover ? Broom.text : (widget.dim ? Broom.faint : Broom.muted));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: active ? Broom.accentGradient : null,
                  color: active ? null : (hover ? Broom.glass : const Color(0x00000000)),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: active ? Broom.glow(Broom.violet, blur: 20, alpha: 0.6) : null,
                ),
                child: Icon(widget.item.icon, size: 19, color: fg),
              ),
              const SizedBox(height: 4),
              Text(widget.item.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
