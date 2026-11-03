import 'dart:async';
import 'dart:math' as math;

import 'package:livekit_client/livekit_client.dart' as lk;

import 'voice_backend.dart';

/// A voice call with the LiveKit agent, built on the SDK's [lk.Session]: it
/// fetches a token, joins the room, dispatches the agent, publishes the
/// microphone (buffering your first words while the agent joins) and relays
/// live transcripts of both sides.
class LiveKitVoiceBackend extends VoiceBackend {
  LiveKitVoiceBackend({
    required lk.TokenSourceConfigurable tokenSource,
    required String agentName,
  }) : _usesSandboxTokenServer = tokenSource is lk.DevelopmentTokenSource,
       _session = lk.Session.withAgent(
         agentName,
         tokenSource: tokenSource,
         options: lk.SessionOptions(),
       ) {
    _session.addListener(_onSessionChanged);
  }

  /// Uses LiveKit Cloud's development token server. Development only: the
  /// sandbox hands out tokens to anyone who knows the ID.
  LiveKitVoiceBackend.sandbox({
    required String sandboxId,
    required String agentName,
  }) : this(
         tokenSource: lk.DevelopmentTokenSource(id: sandboxId),
         agentName: agentName,
       );

  /// Uses an application-owned token endpoint for production calls.
  ///
  /// The endpoint must use HTTPS, must not put credentials in the URL, and
  /// must accept LiveKit's token-source JSON request/response format. Put
  /// authentication (for example a short-lived app session token) in
  /// [headers], never a LiveKit API secret in the client.
  factory LiveKitVoiceBackend.endpoint({
    required String endpoint,
    required String agentName,
    Map<String, String> headers = const {},
  }) {
    final uri = _validatedProductionEndpoint(endpoint);
    return LiveKitVoiceBackend(
      tokenSource: lk.EndpointTokenSource(url: uri, headers: headers),
      agentName: agentName,
    );
  }

  final lk.Session _session;
  final bool _usesSandboxTokenServer;
  Timer? _levelTimer;
  Future<void>? _startFuture;
  Future<void>? _endFuture;
  bool _ended = false;
  bool _disposed = false;
  bool _micEnabled = true;
  double _level = 0;
  String? _operationError;

  @override
  AgentPhase get phase {
    final agent = _session.agent;
    switch (agent.agentState) {
      case lk.AgentState.speaking:
        return AgentPhase.speaking;
      case lk.AgentState.thinking:
        return AgentPhase.thinking;
      default:
        // Includes the moment before the agent joins, when your first words
        // are already being buffered.
        return agent.canListen ? AgentPhase.listening : AgentPhase.connecting;
    }
  }

  @override
  String? get error {
    if (_operationError != null) return _operationError;
    final sessionError = _session.error;
    if (sessionError != null) {
      final cause = sessionError.cause;
      if (cause is lk.TokenSourceHttpException) {
        return _tokenHttpError(cause.statusCode);
      }
      return "Couldn't connect the call: ${_short(cause)}";
    }
    return switch (_session.agent.error) {
      lk.AgentFailure.timeout =>
        "The voice agent didn't join the call. Check that it is "
            'deployed (`lk agent status`) and that its name matches the app.',
      lk.AgentFailure.left => 'The voice agent left the call.',
      null => null,
    };
  }

  @override
  bool get ended => _ended;

  @override
  List<VoiceLine> get lines => [
    for (final message in _session.messages)
      if (message.content.text.trim().isNotEmpty)
        VoiceLine(
          id: message.id,
          fromUser: message.content is! lk.AgentTranscript,
          text: message.content.text,
        ),
  ];

  @override
  double get level => _level;

  @override
  bool get micEnabled => _micEnabled;

  @override
  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    if (_ended || _disposed) return;
    _levelTimer ??= Timer.periodic(
      const Duration(milliseconds: 70),
      (_) => _pollLevel(),
    );
    try {
      await _session.start();
      // A screen can be closed while the SDK is still connecting. If start
      // completes afterwards, close the late session as well.
      if (_ended || _disposed) await _session.end();
    } catch (error) {
      if (!_ended && !_disposed) {
        _operationError = _friendlyError(
          error,
          prefix: "Couldn't start the call",
        );
        _levelTimer?.cancel();
        _levelTimer = null;
        _level = 0;
      }
    }
    _notify();
  }

  @override
  Future<void> setMicEnabled(bool enabled) async {
    if (_ended || _disposed || enabled == _micEnabled) return;
    try {
      await _session.room.localParticipant?.setMicrophoneEnabled(enabled);
      _micEnabled = enabled;
      _operationError = null;
    } catch (error) {
      _operationError = _friendlyError(
        error,
        prefix: "Couldn't update the microphone",
      );
    }
    _notify();
  }

  @override
  Future<void> end() => _endFuture ??= _end();

  Future<void> _end() async {
    if (_ended) return;
    _ended = true;
    _levelTimer?.cancel();
    _levelTimer = null;
    _level = 0;
    _notify();
    try {
      await _session.end();
    } catch (error) {
      // Ending is best-effort. Surface it for a still-mounted screen, but do
      // not throw from a close/dispose path.
      if (!_disposed) {
        _operationError = _friendlyError(
          error,
          prefix: "Couldn't end the call cleanly",
        );
        _notify();
      }
    }
  }

  void _onSessionChanged() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Loudness of whoever is talking: the agent's voice, or yours.
  void _pollLevel() {
    if (_ended || _disposed) return;
    final room = _session.room;
    final agentLevel = room.agentParticipant?.audioLevel ?? 0;
    final userLevel = _micEnabled
        ? (room.localParticipant?.audioLevel ?? 0)
        : 0;
    // Audio levels are small, linear values; a square root makes quiet speech
    // visible, and smoothing stops the orb from flickering.
    final target = math.sqrt(math.max(agentLevel, userLevel).clamp(0.0, 1.0));
    final next = _level * 0.6 + target * 0.4;
    if ((next - _level).abs() > 0.01) {
      _level = next;
      _notify();
    }
  }

  String _friendlyError(Object error, {required String prefix}) {
    if (error is lk.TokenSourceHttpException) {
      return _tokenHttpError(error.statusCode);
    }
    return '$prefix: ${_short(error)}';
  }

  String _tokenHttpError(int statusCode) {
    if (_usesSandboxTokenServer) {
      return switch (statusCode) {
        401 || 403 || 404 =>
          'LiveKit did not accept the sandbox ID (HTTP $statusCode). '
              'Check it in the server settings.',
        _ => 'LiveKit sandbox token server error (HTTP $statusCode).',
      };
    }

    return switch (statusCode) {
      401 || 403 =>
        'The voice token endpoint rejected this request (HTTP $statusCode). '
            'Sign in again or check its authentication settings.',
      404 =>
        'The voice token endpoint was not found (HTTP 404). Check its URL.',
      _ => 'The voice token endpoint returned HTTP $statusCode.',
    };
  }

  static Uri _validatedProductionEndpoint(String input) {
    final value = input.trim();
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) {
      throw ArgumentError.value(
        input,
        'endpoint',
        'Enter an absolute HTTPS token endpoint URL.',
      );
    }
    if (uri.scheme.toLowerCase() != 'https') {
      throw ArgumentError.value(
        input,
        'endpoint',
        'Production token endpoints must use HTTPS.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        input,
        'endpoint',
        'Put authentication in request headers, not in the URL.',
      );
    }
    if (uri.hasFragment) {
      throw ArgumentError.value(
        input,
        'endpoint',
        'Token endpoint URLs cannot contain a fragment.',
      );
    }
    return uri;
  }

  static String _short(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > 140 ? '${text.substring(0, 140)}…' : text;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _levelTimer?.cancel();
    _session.removeListener(_onSessionChanged);
    final ending = _endFuture ??= _end();
    unawaited(_disposeSession(ending));
    super.dispose();
  }

  Future<void> _disposeSession(Future<void> ending) async {
    await ending;
    try {
      await _session.dispose();
    } catch (_) {}
    try {
      await _session.room.dispose();
    } catch (_) {}
  }
}
