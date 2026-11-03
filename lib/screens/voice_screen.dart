import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/speech_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/dot_ring.dart';
import '../widgets/glow_backdrop.dart';
import '../widgets/voice_widgets.dart';

/// Talk to the assistant. Pops with the transcript when the user taps send,
/// or with null when the screen is closed.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final _speech = SpeechService();
  final _transcriptScroll = ScrollController();

  bool _available = false;
  bool _listening = false;
  double _level = 0;
  String? _error;

  /// Words from earlier listening sessions plus the one in progress.
  String _committed = '';
  String _partial = '';

  String get _text =>
      [_committed, _partial].where((s) => s.isNotEmpty).join(' ');

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    if (_available) _speech.cancel();
    _transcriptScroll.dispose();
    super.dispose();
  }

  /// Long transcripts scroll; keep the newest words in view.
  void _followTranscript() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_transcriptScroll.hasClients) return;
      _transcriptScroll.jumpTo(_transcriptScroll.position.maxScrollExtent);
    });
  }

  Future<void> _begin() async {
    final ok = await _speech.init(
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _error = message == 'error_permission'
              ? 'Microphone or speech permission was denied.'
              : 'Speech recognition stopped ($message).';
          _listening = false;
        });
      },
      onListeningChanged: (listening) {
        if (!mounted) return;
        setState(() {
          _listening = listening;
          if (!listening) _level = 0;
        });
      },
    );
    if (!mounted) return;
    if (!ok) {
      setState(
        () => _error = 'Speech recognition is not available. Check microphone and speech permissions.',
      );
      return;
    }
    _available = true;
    await _listen();
  }

  Future<void> _listen() async {
    if (!_available || _speech.isListening) return;
    setState(() {
      _committed = _text;
      _partial = '';
      _error = null;
    });
    await _speech.start(
      onWords: (words, _) {
        if (!mounted) return;
        setState(() => _partial = words);
        _followTranscript();
      },
      onLevel: (level) {
        if (mounted) setState(() => _level = level);
      },
    );
    if (mounted) setState(() => _listening = _speech.isListening);
  }

  Future<void> _toggle() async {
    if (!_available) return;
    if (_listening) {
      await _speech.stop();
    } else {
      await _listen();
    }
  }

  Future<void> _startOver() async {
    if (_available) await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _committed = '';
      _partial = '';
      _listening = false;
    });
    await _listen();
  }

  Future<void> _send() async {
    if (_available) await _speech.stop();
    final text = _text.trim();
    if (text.isEmpty || !mounted) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _text.isNotEmpty;
    final failed = _error != null;

    return AppScaffold(
      backdrop: GlowBackdrop(
        color: hasText && _listening
            ? AppColors.glowActive
            : AppColors.glowIdle,
        intensity: failed ? 0.45 : 1,
        leftBias: hasText && _listening ? 0.8 : 0,
      ),
      child: Column(
        children: [
          const AppHeader(interactive: false),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                return Stack(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: hasText ? 1 : 0),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeInOutCubic,
                      builder: (context, t, child) => Positioned(
                        left: 0,
                        right: 0,
                        top: height * (0.40 - 0.18 * t) - 152,
                        height: 304,
                        child: Center(
                          child: Transform.scale(
                            scale: 1 - 0.38 * t,
                            child: child,
                          ),
                        ),
                      ),
                      child: DotRing(
                        mood: failed || !_listening
                            ? DotRingMood.muted
                            : DotRingMood.listening,
                        level: _listening ? _level : 0,
                        converging: hasText && _listening,
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 14,
                      child: failed
                          ? Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: inter(
                                size: 15,
                                color: AppColors.error,
                                height: 1.4,
                              ),
                            )
                          : hasText
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 250,
                                  ),
                                  child: SingleChildScrollView(
                                    controller: _transcriptScroll,
                                    child: Text.rich(_transcript()),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _startOver,
                                  child: Text(
                                    _listening
                                        ? 'Listening · tap to start over'
                                        : 'Tap send when you are ready',
                                    textAlign: TextAlign.center,
                                    style: inter(
                                      size: 12,
                                      weight: FontWeight.w500,
                                      color: const Color(0xB3FFFFFF),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 26),
                              ],
                            )
                          : ListeningCaption(
                              text: _listening
                                  ? "I'm Listening"
                                  : 'Tap the mic to start',
                              animateDots: _listening,
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          VoiceControls(
            level: _listening ? _level : 0,
            micOn: true,
            dimmed: !_listening,
            leftIcon: Icons.arrow_upward_rounded,
            leftTooltip: 'Send',
            onKeyboard: _text.trim().isEmpty ? null : _send,
            onMic: _toggle,
            onClose: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }

  /// White for what has been heard, dimmed for the last couple of words that
  /// the recogniser may still change.
  InlineSpan _transcript() {
    if (_text.isEmpty) {
      return TextSpan(
        text: _listening
            ? 'Go ahead, I am listening…'
            : 'Your words will appear here',
        style: AppText.transcript.copyWith(color: AppColors.text3),
      );
    }

    final words = _partial.isEmpty ? const <String>[] : _partial.split(' ');
    final tailCount = _listening ? math.min(2, words.length) : 0;
    final stable = [
      if (_committed.isNotEmpty) _committed,
      ...words.take(words.length - tailCount),
    ].join(' ');
    final tail = words.skip(words.length - tailCount).join(' ');

    return TextSpan(
      style: AppText.transcript,
      children: [
        TextSpan(text: stable),
        if (tail.isNotEmpty)
          TextSpan(
            text: stable.isEmpty ? tail : ' $tail',
            style: const TextStyle(color: Color(0xFF6B6B6B)),
          ),
      ],
    );
  }
}
