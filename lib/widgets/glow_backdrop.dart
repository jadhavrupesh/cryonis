import 'package:flutter/material.dart';

/// The soft graphite light rising from the bottom edge in voice mode: nearly
/// black while listening, silver while someone is speaking. It fills its parent and
/// glides between colours and strengths instead of jumping.
///
/// The vertical profile was measured from the design: nothing above 58 % of the
/// height, ~10 % strength at 67 %, ~35 % at 79 % and full strength from 92 % down.
class GlowBackdrop extends StatelessWidget {
  const GlowBackdrop({
    super.key,
    this.color = const Color(0xFF20201F),
    this.intensity = 1,
    this.leftBias = 0,
  });

  /// The colour at full strength along the very bottom.
  final Color color;

  /// 0 (dark) to 1 (as designed).
  final double intensity;

  /// 0 to 1: extra brightness in the bottom-left corner in the active state.
  final double leftBias;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (context, animatedColor, _) => TweenAnimationBuilder<double>(
          tween: Tween(end: intensity),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          builder: (context, strength, _) => TweenAnimationBuilder<double>(
            tween: Tween(end: leftBias),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (context, bias, _) => CustomPaint(
              painter: _GlowPainter(animatedColor ?? color, strength, bias),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.color, this.strength, this.bias);

  final Color color;
  final double strength;
  final double bias;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || strength <= 0) return;
    final top = size.height * 0.58;
    final rect = Rect.fromLTRB(0, top, size.width, size.height);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.10 * strength),
            color.withValues(alpha: 0.35 * strength),
            color.withValues(alpha: strength),
            color.withValues(alpha: strength),
          ],
          stops: const [0, 0.214, 0.5, 0.81, 1],
        ).createShader(rect),
    );

    if (bias > 0) {
      final centre = Offset(size.width * 0.2, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.5 * bias * strength),
              color.withValues(alpha: 0),
            ],
            // Reaches zero exactly at the top of the glow, so it has no visible edge.
          ).createShader(Rect.fromCircle(center: centre, radius: rect.height)),
      );
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.color != color || old.strength != strength || old.bias != bias;
}
