import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

/// Shared by the Home mic and the voice screen's mic so the button flies from
/// one to the other, turning from a rounded square into a circle on the way.
const micHeroTag = 'cryonis-mic';

/// The silver mic / send button: a gradient shape with dark content.
class AccentMic extends StatelessWidget {
  const AccentMic({
    super.key,
    required this.size,
    required this.radius,
    this.icon = Icons.mic_rounded,
    this.iconSize,
    this.dimmed = false,
  });

  final double size;
  final double radius;
  final IconData icon;
  final double? iconSize;

  /// Voice paused: a dark graphite colour and a fainter icon.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: dimmed ? null : AppGradients.mic,
        color: dimmed ? AppColors.accentMuted : null,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        size: iconSize ?? size * 0.5,
        color: dimmed
            ? AppColors.text2.withValues(alpha: 0.65)
            : AppColors.onAccent,
      ),
    );
  }
}

/// Wraps [child] in the shared mic [Hero]; [fromRadius] / [toRadius] are the
/// corner radii of the two ends of the flight.
class MicHero extends StatelessWidget {
  const MicHero({
    super.key,
    required this.child,
    required this.squareRadius,
    required this.circleRadius,
    required this.isCircle,
  });

  final Widget child;
  final double squareRadius;
  final double circleRadius;

  /// This end of the flight is the round one (the voice screen's mic).
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: micHeroTag,
      flightShuttleBuilder: (context, animation, direction, from, to) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            // 0 at the Home mic, 1 at the voice mic, whichever way we fly.
            final t = direction == HeroFlightDirection.push
                ? animation.value
                : 1 - animation.value;
            return Container(
              decoration: BoxDecoration(
                gradient: AppGradients.mic,
                borderRadius: BorderRadius.circular(
                  squareRadius + (circleRadius - squareRadius) * t,
                ),
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: AppColors.onAccent,
                size: 22,
              ),
            );
          },
        );
      },
      child: child,
    );
  }
}

/// Keyboard (left), mic with a pulsing halo (centre), close (right): the row of
/// controls along the bottom of voice mode.
class VoiceControls extends StatelessWidget {
  const VoiceControls({
    super.key,
    required this.onKeyboard,
    required this.onMic,
    required this.onClose,
    this.micOn = true,
    this.dimmed = false,
    this.level = 0,
    this.leftIcon = Icons.keyboard_alt_outlined,
    this.leftTooltip = 'Type instead',
  });

  /// The left button: "keyboard" in a live call, "send" when dictating.
  final IconData leftIcon;
  final String leftTooltip;

  final VoidCallback? onKeyboard;
  final VoidCallback? onMic;
  final VoidCallback? onClose;

  /// False while the microphone is muted.
  final bool micOn;

  /// Voice is paused (the answer is being generated).
  final bool dimmed;

  /// 0..1 loudness, swelling the halo.
  final double level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundControl(
            icon: leftIcon,
            tooltip: leftTooltip,
            onPressed: onKeyboard,
          ),
          _CentreMic(
            onPressed: onMic,
            micOn: micOn,
            dimmed: dimmed,
            level: level,
          ),
          _RoundControl(
            icon: Icons.close_rounded,
            tooltip: 'End voice and continue in chat',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: onPressed == null ? 0.45 : 1,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x26FFFFFF),
            ),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _CentreMic extends StatefulWidget {
  const _CentreMic({
    required this.onPressed,
    required this.micOn,
    required this.dimmed,
    required this.level,
  });

  final VoidCallback? onPressed;
  final bool micOn;
  final bool dimmed;
  final double level;

  @override
  State<_CentreMic> createState() => _CentreMicState();
}

class _CentreMicState extends State<_CentreMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  bool get _pulsing => widget.micOn && !widget.dimmed;

  @override
  void initState() {
    super.initState();
    if (_pulsing) _breath.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_CentreMic old) {
    super.didUpdateWidget(old);
    if (_pulsing && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!_pulsing && _breath.isAnimating) {
      _breath.stop();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.micOn ? 'Mute microphone' : 'Unmute microphone',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: SizedBox(
          width: 77,
          height: 77,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _breath,
                builder: (context, _) {
                  final swell = 1 + 0.06 * _breath.value + 0.14 * widget.level;
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _pulsing ? 1 : 0,
                    child: Transform.scale(
                      scale: swell,
                      child: Container(
                        width: 71,
                        height: 71,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent.withValues(alpha: 0.18),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.42),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              MicHero(
                squareRadius: 6,
                circleRadius: 26.5,
                isCircle: true,
                child: AccentMic(
                  size: 53,
                  radius: 26.5,
                  icon: widget.micOn
                      ? Icons.mic_rounded
                      : Icons.mic_off_rounded,
                  iconSize: 22,
                  dimmed: widget.dimmed || !widget.micOn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ear icon and "I'm Listening…" with dots that count up, as in the design.
class ListeningCaption extends StatefulWidget {
  const ListeningCaption({
    super.key,
    required this.text,
    this.animateDots = true,
    this.icon = Icons.hearing_rounded,
  });

  /// The words before the dots, e.g. "I'm Listening".
  final String text;
  final bool animateDots;
  final IconData icon;

  @override
  State<ListeningCaption> createState() => _ListeningCaptionState();
}

class _ListeningCaptionState extends State<ListeningCaption>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animateDots) _dots.repeat();
  }

  @override
  void didUpdateWidget(ListeningCaption old) {
    super.didUpdateWidget(old);
    if (widget.animateDots && !_dots.isAnimating) {
      _dots.repeat();
    } else if (!widget.animateDots && _dots.isAnimating) {
      _dots.stop();
    }
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppText.voiceCaption;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, size: 26, color: const Color(0xB3FFFFFF)),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _dots,
          builder: (context, _) {
            // One to three dots; unlit ones stay in the layout so the text
            // does not shift sideways.
            final lit = widget.animateDots
                ? 1 + (_dots.value * 3).floor().clamp(0, 2)
                : 0;
            return Text.rich(
              TextSpan(
                text: widget.text,
                style: style,
                children: [
                  if (widget.animateDots)
                    for (var i = 0; i < 3; i++)
                      TextSpan(
                        text: '.',
                        style: style.copyWith(
                          color: i < lit ? style.color : Colors.transparent,
                        ),
                      ),
                ],
              ),
              textAlign: TextAlign.center,
            );
          },
        ),
      ],
    );
  }
}

/// Shows [text] and fades every newly arrived word from grey to white, like the
/// live transcript in the design. Words that were already there stay white.
class WordRevealText extends StatefulWidget {
  const WordRevealText({
    super.key,
    required this.text,
    required this.style,
    this.pendingColor = const Color(0xFF6B6B6B),
    this.revealDuration = const Duration(milliseconds: 350),
    this.stagger = const Duration(milliseconds: 70),
  });

  final String text;
  final TextStyle style;

  /// What a word looks like the instant it arrives.
  final Color pendingColor;
  final Duration revealDuration;

  /// Delay between words that arrive together, so they do not flash at once.
  final Duration stagger;

  @override
  State<WordRevealText> createState() => _WordRevealTextState();
}

class _WordRevealTextState extends State<WordRevealText>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  List<String> _words = const [];

  /// When each word starts turning white, on this widget's own clock. The
  /// ticker's clock restarts from zero every time it is restarted, so time is
  /// accumulated here instead.
  List<Duration> _starts = const [];
  Duration _now = Duration.zero;
  Duration _lastElapsed = Duration.zero;

  static List<String> _split(String text) =>
      text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    _words = _split(widget.text);
    // What is there on first build is not "new": show it in full.
    _starts = List.filled(_words.length, const Duration(days: -1));
  }

  @override
  void didUpdateWidget(WordRevealText old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;

    final next = _split(widget.text);
    var keep = 0;
    while (keep < next.length &&
        keep < _words.length &&
        next[keep] == _words[keep]) {
      keep++;
    }
    final starts = <Duration>[..._starts.take(keep)];
    for (var i = keep; i < next.length; i++) {
      starts.add(_now + widget.stagger * (i - keep));
    }
    _words = next;
    _starts = starts;
    if (keep < next.length && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    _now += elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    setState(() {});
    final done = _starts.every((s) => _now - s >= widget.revealDuration);
    if (done) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final white = widget.style.color ?? Colors.white;
    final spans = <InlineSpan>[];
    for (var i = 0; i < _words.length; i++) {
      final progress = widget.revealDuration.inMicroseconds == 0
          ? 1.0
          : ((_now - _starts[i]).inMicroseconds /
                    widget.revealDuration.inMicroseconds)
                .clamp(0.0, 1.0);
      spans.add(
        TextSpan(
          text: i == 0 ? _words[i] : ' ${_words[i]}',
          style: TextStyle(
            color: Color.lerp(
              widget.pendingColor,
              white,
              Curves.easeOut.transform(progress),
            ),
          ),
        ),
      );
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

/// The 8-ray spinner next to "Generating".
class SparkSpinner extends StatefulWidget {
  const SparkSpinner({
    super.key,
    this.size = 14,
    this.color = const Color(0xFF9E9E9E),
  });

  final double size;
  final Color color;

  @override
  State<SparkSpinner> createState() => _SparkSpinnerState();
}

class _SparkSpinnerState extends State<SparkSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) =>
            CustomPaint(painter: _SparkPainter(_spin.value, widget.color)),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.turn, this.color);

  final double turn;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = outer * 0.5;
    for (var i = 0; i < 8; i++) {
      // The brightest ray trails round the circle; the others fade behind it.
      final behind = ((turn * 8 - i) % 8 + 8) % 8;
      final alpha = 0.18 + 0.82 * (1 - behind / 8);
      final angle = i * math.pi / 4 - math.pi / 2;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        centre + direction * inner,
        centre + direction * outer,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..strokeWidth = size.width / 9
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.turn != turn || old.color != color;
}

/// "Generating ✳": shown under an answer while it is still arriving.
class GenerateLoading extends StatelessWidget {
  const GenerateLoading({super.key, this.label = 'Generating'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: inter(size: 14, color: const Color(0xFF9E9E9E))),
        const SizedBox(width: 8),
        const SparkSpinner(),
      ],
    );
  }
}
