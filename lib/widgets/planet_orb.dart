import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The glowing planet from the voice screen: a shaded sphere with slowly
/// drifting blurred swirls. [level] (0..1) makes it swell with the user's
/// voice. Pass `glow: false, animate: false` for the tiny chat avatar.
class PlanetOrb extends StatefulWidget {
  const PlanetOrb({
    super.key,
    required this.size,
    this.level = 0,
    this.glow = true,
    this.animate = true,
  });

  /// Edge of the square the orb is drawn in. With [glow] the sphere takes up
  /// roughly 70% of it and the halo fills the rest.
  final double size;
  final double level;
  final bool glow;
  final bool animate;

  @override
  State<PlanetOrb> createState() => _PlanetOrbState();
}

class _PlanetOrbState extends State<PlanetOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _spin.repeat();
  }

  @override
  void didUpdateWidget(PlanetOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    widget.animate ? _spin.repeat() : _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.level),
        duration: const Duration(milliseconds: 140),
        builder: (context, level, _) => AnimatedBuilder(
          animation: _spin,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _OrbPainter(
              t: _spin.value * 2 * math.pi,
              level: level,
              glow: widget.glow,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.t, required this.level, required this.glow});

  final double t;
  final double level;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = glow ? size.width * 0.35 : size.width / 2;
    final r = base * (1 + 0.025 * math.sin(t * 3) + 0.1 * level);
    final rect = Rect.fromCircle(center: center, radius: r);

    if (glow) {
      // Stays inside the widget's own box (size * 0.35 * 1.4 = 0.49 * size).
      final haloRadius = r * 1.4;
      canvas.drawCircle(
        center,
        haloRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.45 + 0.25 * level),
              AppColors.accent.withValues(alpha: 0),
            ],
            stops: const [0.5, 1],
          ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
      );
    }

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // Body: a light source up-left that wanders slowly.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            -0.35 + 0.12 * math.sin(t),
            -0.4 + 0.12 * math.cos(t),
          ),
          radius: 1.05,
          colors: const [
            Color(0xFFF3F3EF),
            Color(0xFFC8C8C4),
            Color(0xFF8B8B87),
            Color(0xFF4B4B49),
            Color(0xFF171716),
          ],
          stops: const [0, 0.18, 0.45, 0.78, 1],
        ).createShader(rect),
    );

    // Soft swirls drifting across the surface.
    void blob(Offset offset, double radius, Color color) {
      canvas.drawCircle(
        center + offset,
        radius,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.28),
      );
    }

    blob(
      Offset(math.cos(t) * r * 0.45, math.sin(t * 2) * r * 0.35),
      r * 0.38,
      AppColors.accentStrong.withValues(alpha: 0.55),
    );
    blob(
      Offset(-math.cos(t * 2 + 1) * r * 0.5, math.sin(t + 2) * r * 0.45),
      r * 0.34,
      AppColors.accentMuted.withValues(alpha: 0.7),
    );
    blob(
      Offset(math.sin(t * 3) * r * 0.3, math.cos(t) * r * 0.5 + r * 0.1),
      r * 0.25,
      AppColors.accentSoft.withValues(alpha: 0.65),
    );

    // Darken the limb so it reads as a sphere.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.25),
          radius: 1.0,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.75),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.t != t || old.level != level || old.glow != glow;
}
