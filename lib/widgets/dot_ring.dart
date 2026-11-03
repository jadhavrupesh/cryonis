import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// What the ring is expressing. The four live moods follow the agent's loop,
/// and each has its own motion so you can tell the phase without reading:
///
/// * **observe**: [listening], the ring breathes and soft ripples travel
///   outward when you speak;
/// * **orient**: [listening] with `converging` (words are arriving), ripples run
///   inward and the dots are drawn towards the centre;
/// * **decide**: [thinking], a bright comet arc orbits the ring while the rest
///   dims;
/// * **act**: [speaking], ripples are pushed outward in time with the agent's
///   voice and the whole ring swells with it.
enum DotRingMood {
  /// Waiting for the call: faint, with a slow, dim arc going round.
  connecting,

  /// The caller's turn.
  listening,

  /// The agent is working on an answer.
  thinking,

  /// The agent's turn.
  speaking,

  /// Microphone off, or the call failed: nearly dark and still.
  muted,
}

/// The voice-mode visual from the design: a grid of square dots lit in a ring
/// (outer radius ≈ 144 dp, hole ≈ 59 dp). Each dot's brightness is the ring
/// profile times drifting noise, so the ring "boils"; on top of that each
/// [DotRingMood] adds its own travelling light (see [DotRingMood]).
///
/// The widget is 304 dp square; scale and position it from outside.
class DotRing extends StatefulWidget {
  const DotRing({
    super.key,
    required this.mood,
    this.level = 0,
    this.converging = false,
    this.size = 304,
  });

  final DotRingMood mood;

  /// 0..1 loudness of whoever is speaking.
  final double level;

  /// Words are arriving: ripples run inward instead of outward.
  final bool converging;

  final double size;

  @override
  State<DotRing> createState() => _DotRingState();
}

/// How bright a dot at [angle] is while a comet arc is at [sweepAngle]: 1 at the
/// head, a long tail behind it (the way it came), falling to 0.4 elsewhere so
/// a faint ghost of the ring stays visible.
@visibleForTesting
double sweepFactor(double angle, double sweepAngle) {
  // The signed angle from the head, wrapped to -pi..pi. Negative = behind it.
  final d = (angle - sweepAngle + math.pi) % (2 * math.pi) - math.pi;
  final lead = math.exp(d > 0 ? -d * 5.0 : d * 1.0);
  return 0.4 + 0.6 * lead;
}

/// A ripple across the radius, 0.62..1: crests travel outward (or inward)
/// as [clock] advances.
@visibleForTesting
double rippleFactor(double radius, double clock, {required bool outward}) {
  final phase = radius * 0.085 + (outward ? -1 : 1) * clock * 4.6;
  return 0.62 + 0.38 * math.sin(phase);
}

class _MoodLook {
  const _MoodLook(
    this.brightness,
    this.radius,
    this.band,
    this.speed, {
    this.sweep = 0,
    this.ripple = 0,
  });

  final double brightness;

  /// Radius of the brightest band, in the 304 dp design space.
  final double radius;

  /// Half-width of the band.
  final double band;

  /// How fast the noise drifts.
  final double speed;

  /// 0..1: how much of the orbiting comet arc is applied.
  final double sweep;

  /// 0..1: how much of the outward ripple is applied.
  final double ripple;
}

const _looks = {
  DotRingMood.connecting: _MoodLook(0.4, 100, 28, 0.5, sweep: 0.35),
  DotRingMood.listening: _MoodLook(0.9, 100, 29, 0.9, ripple: 0.5),
  DotRingMood.thinking: _MoodLook(0.8, 94, 27, 1.6, sweep: 1),
  DotRingMood.speaking: _MoodLook(1.0, 104, 32, 1.4, ripple: 1),
  DotRingMood.muted: _MoodLook(0.22, 98, 30, 0.35),
};

class _DotRingState extends State<DotRing> with SingleTickerProviderStateMixin {
  static const _design = 304.0;
  static const _pitch = 7.0;
  static const _cells = 44; // _design / _pitch, rounded

  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<int> _frame = ValueNotifier(0);

  /// A fixed random phase per dot so they twinkle independently.
  late final Float32List _phase = _makePhases();

  Duration _last = Duration.zero;

  /// Drifts the noise; its speed depends on the mood.
  double _time = 0;

  /// Plain seconds, for the orbit, ripples and breathing.
  double _clock = 0;
  double _level = 0;
  double _brightness = 0.35;
  double _radius = 100;
  double _band = 32;
  double _speed = 0.5;

  /// How much of each motion is applied now; they glide between moods.
  double _sweep = 0;
  double _ripple = 0;
  double _inward = 0;

  static Float32List _makePhases() {
    final random = math.Random(11);
    return Float32List.fromList([
      for (var i = 0; i < _cells * _cells; i++)
        random.nextDouble() * math.pi * 2,
    ]);
  }

  @override
  void initState() {
    super.initState();
    final look = _looks[widget.mood]!;
    _brightness = look.brightness;
    _radius = look.radius;
    _band = look.band;
    _speed = look.speed;
    _sweep = look.sweep;
    _ripple = look.ripple;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / 1e6, 0.05);
    _last = elapsed;

    final look = _looks[widget.mood]!;
    final wanted = widget.mood == DotRingMood.muted
        ? 0.0
        : widget.level.clamp(0.0, 1.0);
    // Rises fast and falls slowly, like an audio meter.
    _level +=
        (wanted - _level) * (1 - math.exp(-dt * (wanted > _level ? 16 : 4)));

    final k = 1 - math.exp(-dt * 3.5);
    _brightness += (look.brightness - _brightness) * k;
    _radius += (look.radius - _radius) * k;
    _band += (look.band - _band) * k;
    _speed += (look.speed - _speed) * k;

    // Orienting: the inward ripple replaces the outward one.
    final inward = widget.converging && widget.mood == DotRingMood.listening;
    final kMotion = 1 - math.exp(-dt * 4);
    _sweep += (look.sweep - _sweep) * kMotion;
    _ripple += ((inward ? 0.0 : look.ripple) - _ripple) * kMotion;
    _inward += ((inward ? 1.0 : 0.0) - _inward) * kMotion;

    _time += dt * _speed;
    _clock += dt;
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _RingPainter(this, reduceMotion: reduceMotion),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.s, {required this.reduceMotion}) : super(repaint: s._frame);

  final _DotRingState s;
  final bool reduceMotion;

  /// Dot sizes are drawn in a few buckets so the whole ring is a handful of
  /// draw calls instead of ~2,000.
  static const _buckets = 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = size.width / _DotRingState._design;
    final cells = _DotRingState._cells;
    final centre = _DotRingState._design / 2;
    final t = reduceMotion ? 0.0 : s._time;
    final clock = reduceMotion ? 0.0 : s._clock;
    final lvl = s._level;

    // The ring breathes a little, and swells with the voice.
    final breath = 2.5 * s._brightness * math.sin(clock * 1.7);
    final radius = s._radius + 10 * lvl + breath;
    final band = s._band + 5 * lvl;
    final brightness = s._brightness * (0.82 + 0.12 * lvl) * (1 + 0.3 * s._sweep);

    // Observe / act: ripples grow with the voice. Orient: inward ripples.
    final rippleStrength = s._ripple * (0.35 + 0.65 * lvl);
    final inwardStrength = s._inward * 0.9;
    final sweepAngle = clock * 3.6;

    final points = List.generate(_buckets, (_) => <double>[]);
    for (var iy = 0; iy < cells; iy++) {
      for (var ix = 0; ix < cells; ix++) {
        final x = (ix + 0.5) * _DotRingState._pitch - centre;
        final y = (iy + 0.5) * _DotRingState._pitch - centre;
        final r = math.sqrt(x * x + y * y);
        if (r > 156 || r < 40) continue;

        // The ring's edge wobbles with the angle and time.
        final angle = math.atan2(y, x);
        final wobble =
            math.sin(angle * 3 + t * 1.3) * 9 + math.sin(angle * 7 - t * 1.9) * 5;
        final d = (r - (radius + wobble * (0.6 + lvl))) / band;
        final profile = math.exp(-d * d);
        if (profile < 0.03) continue;

        // Slow, patchy noise makes clumps of bright dots; a quicker per-dot
        // twinkle breaks them up. The contrast curve keeps the faint edge dots
        // almost invisible, as in the design.
        final twinkle =
            0.5 + 0.5 * math.sin(t * 2.4 + s._phase[iy * cells + ix]);
        final clump =
            0.5 +
            0.25 * math.sin(x * 0.075 + y * 0.04 + t * 0.8) +
            0.25 * math.sin(y * 0.085 - x * 0.03 - t * 0.6 + 1.2);
        var texture = ((0.7 * clump + 0.3 * twinkle) - 0.2) / 0.6;
        texture = texture.clamp(0.0, 1.0);
        texture = texture * texture * (3 - 2 * texture);

        // The phase's own motion: light travelling over the dots.
        var motion = 1.0;
        if (s._sweep > 0.01) {
          motion *= 1 + s._sweep * (sweepFactor(angle, sweepAngle) - 1);
        }
        if (rippleStrength > 0.01) {
          motion *=
              1 + rippleStrength * (rippleFactor(r, clock, outward: true) - 1);
        }
        if (inwardStrength > 0.01) {
          motion *=
              1 + inwardStrength * (rippleFactor(r, clock, outward: false) - 1);
        }

        var intensity =
            math.pow(profile, 0.8) *
            (0.45 + 0.7 * texture) *
            brightness *
            motion;
        // Push towards "lit or not": the design's dots are mostly bright.
        final lit = ((intensity - 0.14) / 0.55).clamp(0.0, 1.0);
        intensity = lit * lit * (3 - 2 * lit);
        if (intensity < 0.06) continue;

        final bucket = math.min(
          _buckets - 1,
          (intensity * _buckets).floor(),
        );
        points[bucket]
          ..add((x + centre) * unit)
          ..add((y + centre) * unit);
      }
    }

    final paint = Paint()
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = false;
    for (var b = 0; b < _buckets; b++) {
      if (points[b].isEmpty) continue;
      final strength = (b + 0.5) / _buckets;
      paint
        ..strokeWidth = (1.2 + 2.2 * strength) * unit
        ..color = Colors.white.withValues(alpha: 0.3 + 0.7 * strength);
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(points[b]),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.s != s;
}
