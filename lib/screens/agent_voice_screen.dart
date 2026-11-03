import 'dart:async';

import 'package:flutter/material.dart';

import '../services/voice_backend.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/dot_ring.dart';
import '../widgets/glow_backdrop.dart';
import '../widgets/voice_widgets.dart';

/// A live voice call with the voice agent. Pops with the call's turns when the
/// user leaves voice mode. Completed turns are always preserved so ending a
/// call continues naturally in text chat.
class AgentVoiceScreen extends StatefulWidget {
  const AgentVoiceScreen({super.key, required this.createBackend});

  /// Called to open a call, and again when the user starts a new one.
  final VoiceBackend Function() createBackend;

  @override
  State<AgentVoiceScreen> createState() => _AgentVoiceScreenState();
}

class _AgentVoiceScreenState extends State<AgentVoiceScreen>
    with SingleTickerProviderStateMixin {
  late VoiceBackend _backend;
  String? _operationError;
  bool _switchingCall = false;
  bool _closing = false;

  /// Fades the ring, caption and controls in when the screen opens.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void initState() {
    super.initState();
    _openCall();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _backend.removeListener(_onChanged);
    _backend.dispose();
    super.dispose();
  }

  void _openCall() {
    _backend = widget.createBackend();
    _backend.addListener(_onChanged);
    unawaited(_startBackend(_backend));
  }

  /// Backends normally expose failures through [VoiceBackend.error], but the
  /// screen still guards the future so an unexpected plugin exception cannot
  /// escape as an unhandled asynchronous error.
  Future<void> _startBackend(VoiceBackend backend) async {
    try {
      await backend.start();
    } catch (error) {
      if (!mounted || !identical(backend, _backend)) return;
      setState(
        () => _operationError = "Couldn't start the call: ${_short(error)}",
      );
    }
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _startNewCall() async {
    if (_switchingCall || _closing) return;
    setState(() {
      _switchingCall = true;
      _operationError = null;
    });

    final old = _backend;
    old.removeListener(_onChanged);
    try {
      await old.end();
    } catch (_) {
      // The old call is being discarded. Its failure must not prevent retrying.
    }
    if (!mounted) {
      old.dispose();
      return;
    }

    try {
      final next = widget.createBackend();
      next.addListener(_onChanged);
      old.dispose();
      setState(() {
        _backend = next;
        _switchingCall = false;
      });
      unawaited(_startBackend(next));
    } catch (error) {
      // Keep the ended backend alive as a safe placeholder. A later retry can
      // still create a replacement, and widget disposal remains single-shot.
      old.addListener(_onChanged);
      setState(() {
        _switchingCall = false;
        _operationError = "Couldn't create a new call: ${_short(error)}";
      });
    }
  }

  Future<void> _finishVoice() async {
    if (_closing) return;
    _closing = true;
    final turns = conversationFrom(_backend.lines);
    try {
      await _backend.end();
    } catch (_) {
      // Closing should always return control to the caller, even if the
      // transport has already failed.
    }
    if (!mounted) return;
    Navigator.of(context).pop(turns);
  }

  Future<void> _toggleMic() async {
    if (_switchingCall || _closing) return;
    try {
      await _backend.setMicEnabled(!_backend.micEnabled);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _operationError =
            "Couldn't update the microphone: ${_short(error)}",
      );
    }
  }

  /// The words of the latest turn: consecutive segments from whoever spoke last.
  String get _currentTurn {
    final lines = _backend.lines;
    if (lines.isEmpty) return '';
    final side = lines.last.fromUser;
    final parts = <String>[];
    for (var i = lines.length - 1; i >= 0 && lines[i].fromUser == side; i--) {
      final text = lines[i].text.trim();
      if (text.isNotEmpty) parts.add(text);
    }
    return parts.reversed.join(' ');
  }

  /// "I'm Listening", "Thinking", ... and whether the dots after it move.
  ({String text, IconData icon, bool dots}) get _caption {
    final backend = _backend;
    if (!backend.micEnabled && backend.phase == AgentPhase.listening) {
      return (text: 'Mic is muted', icon: Icons.mic_off_rounded, dots: false);
    }
    return switch (backend.phase) {
      AgentPhase.connecting => (
        text: 'Connecting',
        icon: Icons.graphic_eq_rounded,
        dots: true,
      ),
      AgentPhase.listening => (
        text: "I'm Listening",
        icon: Icons.hearing_rounded,
        dots: true,
      ),
      AgentPhase.thinking => (
        text: 'Thinking',
        icon: Icons.auto_awesome_rounded,
        dots: true,
      ),
      AgentPhase.speaking => (
        text: 'Speaking',
        icon: Icons.graphic_eq_rounded,
        dots: true,
      ),
    };
  }

  DotRingMood _mood({required bool failed}) {
    if (failed || !_backend.micEnabled) return DotRingMood.muted;
    return switch (_backend.phase) {
      AgentPhase.connecting => DotRingMood.connecting,
      AgentPhase.listening => DotRingMood.listening,
      AgentPhase.thinking => DotRingMood.thinking,
      AgentPhase.speaking => DotRingMood.speaking,
    };
  }

  @override
  Widget build(BuildContext context) {
    final backend = _backend;
    final error = _operationError ?? backend.error;
    final failed = error != null;
    final inCall =
        !failed && !backend.ended && backend.phase != AgentPhase.connecting;
    final turn = failed ? '' : _currentTurn;
    final hasWords = turn.isNotEmpty;
    final busy = _switchingCall || _closing;

    // Graphite while waiting, silver once anyone is speaking or being answered.
    final active =
        !failed &&
        backend.micEnabled &&
        (hasWords || backend.phase == AgentPhase.speaking);
    final glowColor = active ? AppColors.glowActive : AppColors.glowIdle;
    final glowStrength = failed || !backend.micEnabled
        ? 0.45
        : backend.phase == AgentPhase.connecting
        ? 0.6
        : 1.0;

    return AppScaffold(
      backdrop: GlowBackdrop(
        color: glowColor,
        intensity: glowStrength,
        leftBias: active ? 0.8 : 0,
      ),
      child: Column(
        children: [
          const AppHeader(interactive: false),
          Expanded(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _entrance,
                curve: Curves.easeOut,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => _Stage(
                  height: constraints.maxHeight,
                  compact: hasWords,
                  ring: DotRing(
                    mood: _mood(failed: failed),
                    level: inCall ? backend.level : 0,
                    // Words are coming in: the ring draws them towards itself.
                    converging:
                        hasWords && backend.phase == AgentPhase.listening,
                  ),
                  entrance: _entrance,
                  below: failed
                      ? _FailureNotice(
                          message: error,
                          retrying: _switchingCall,
                          onRetry: _startNewCall,
                        )
                      : hasWords
                      ? _TranscriptBlock(
                          text: turn,
                          label: _caption.text == 'Mic is muted'
                              ? 'Mic is muted'
                              : _caption.text.replaceFirst("I'm ", ''),
                        )
                      : ListeningCaption(
                          text: _caption.text,
                          icon: _caption.icon,
                          animateDots: _caption.dots,
                        ),
                ),
              ),
            ),
          ),
          SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: _entrance, curve: Curves.easeOut),
                ),
            child: FadeTransition(
              opacity: _entrance,
              child: VoiceControls(
                level: inCall && backend.micEnabled ? backend.level : 0,
                micOn: backend.micEnabled,
                // Inert while failure recovery is in progress.
                onMic: failed || busy ? null : _toggleMic,
                onKeyboard: backend.lines.isEmpty || busy ? null : _finishVoice,
                onClose: _closing ? null : _finishVoice,
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }

  static String _short(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > 140 ? '${text.substring(0, 140)}…' : text;
  }
}

/// The ring above and the caption / transcript below it. When words arrive the
/// ring contracts and moves up, as in the design.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.height,
    required this.compact,
    required this.ring,
    required this.below,
    required this.entrance,
  });

  final double height;
  final bool compact;
  final Widget ring;
  final Widget below;
  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: compact ? 1 : 0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
          builder: (context, t, child) {
            // Centre at 40 % of the stage, rising to 22 % when compact.
            final centre = height * (0.40 - 0.18 * t);
            final scale = 1 - 0.38 * t;
            return Positioned(
              left: 0,
              right: 0,
              top: centre - 152,
              height: 304,
              child: Center(
                child: AnimatedBuilder(
                  animation: entrance,
                  builder: (context, child) => Opacity(
                    opacity: entrance.value,
                    child: Transform.scale(
                      scale: scale * (0.82 + 0.18 * entrance.value),
                      child: child,
                    ),
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: ring,
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 14,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: KeyedSubtree(key: ValueKey(below.runtimeType), child: below),
          ),
        ),
      ],
    );
  }
}

/// What is being said (white as it arrives) with a small status label under it.
class _TranscriptBlock extends StatelessWidget {
  const _TranscriptBlock({required this.text, required this.label});

  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black],
              stops: [0, 0.18],
            ).createShader(bounds),
            // Long turns keep the newest words in view.
            child: SingleChildScrollView(
              reverse: true,
              child: WordRevealText(text: text, style: AppText.transcript),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          label,
          textAlign: TextAlign.center,
          style: inter(
            size: 12,
            weight: FontWeight.w500,
            color: const Color(0xB3FFFFFF),
          ),
        ),
        const SizedBox(height: 26),
      ],
    );
  }
}

/// The call failed: say why and offer another try.
class _FailureNotice extends StatelessWidget {
  const _FailureNotice({
    required this.message,
    required this.retrying,
    required this.onRetry,
  });

  final String message;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: inter(size: 15, color: const Color(0xCCFFFFFF), height: 1.4),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: retrying ? null : onRetry,
          child: Opacity(
            opacity: retrying ? 0.5 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    retrying ? 'Reconnecting…' : 'Try again',
                    style: inter(size: 14, weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}
