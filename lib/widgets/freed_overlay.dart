import 'dart:math';

import 'package:flutter/cupertino.dart';

import '../core/format.dart';
import '../theme/broom_theme.dart';
import 'buttons.dart';

/// Full-page celebration shown after a clean: count-up of bytes freed,
/// a glowing check, and a burst of particles.
class FreedOverlay extends StatefulWidget {
  const FreedOverlay({super.key, required this.bytes, required this.onDone, this.toTrash = false});
  final int bytes;
  final bool toTrash;
  final VoidCallback onDone;

  @override
  State<FreedOverlay> createState() => _FreedOverlayState();
}

class _FreedOverlayState extends State<FreedOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
  final particles = List.generate(42, (i) => _Particle(Random(i)));

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Broom.bg0.withValues(alpha: 0.94),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: c,
              builder: (_, _) => CustomPaint(painter: _BurstPainter(particles, c.value)),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(parent: c, curve: const Interval(0, 0.5, curve: Curves.elasticOut)),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Broom.successGradient,
                      boxShadow: Broom.glow(Broom.mint, blur: 50, alpha: 0.7),
                    ),
                    child: const Icon(CupertinoIcons.checkmark, size: 48, color: Color(0xFF06231A)),
                  ),
                ),
                const SizedBox(height: 26),
                AnimatedBuilder(
                  animation: c,
                  builder: (_, _) {
                    final t = Curves.easeOutCubic.transform(((c.value - 0.15) / 0.7).clamp(0, 1));
                    return Text(formatBytes((widget.bytes * t).round()),
                        style: Broom.display.copyWith(fontSize: 44, fontFeatures: const [FontFeature.tabularFigures()]));
                  },
                ),
                const SizedBox(height: 6),
                Text(widget.toTrash ? 'moved to Trash' : 'permanently deleted', style: TextStyle(fontSize: 14, color: Broom.muted, fontWeight: FontWeight.w500)),
                const SizedBox(height: 30),
                GradientButton(label: 'Done', gradient: Broom.successGradient, onPressed: widget.onDone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle {
  _Particle(Random r)
      : angle = r.nextDouble() * 2 * pi,
        speed = 120 + r.nextDouble() * 220,
        size = 3 + r.nextDouble() * 5,
        color = [Broom.mint, Broom.cyan, Broom.violet, Broom.pink, const Color(0xFFFFFFFF)][r.nextInt(5)];
  final double angle, speed, size;
  final Color color;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.ps, this.t);
  final List<_Particle> ps;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(const Offset(0, -40));
    final e = Curves.easeOutCubic.transform(t);
    for (final p in ps) {
      final d = p.speed * e;
      final pos = c + Offset(cos(p.angle), sin(p.angle)) * d + Offset(0, 60 * t * t);
      canvas.drawCircle(pos, p.size * (1 - t * 0.6), Paint()..color = p.color.withValues(alpha: (1 - t).clamp(0, 1)));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter o) => o.t != t;
}
