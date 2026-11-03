import 'package:cryonis/services/voice_backend.dart';

/// A scriptable voice call: tests set the state and the screen reacts, with no
/// WebRTC involved.
class FakeVoiceBackend extends VoiceBackend {
  FakeVoiceBackend({
    this._phase = AgentPhase.connecting,
    this._lines = const [],
    this.startError,
    this.endError,
    this.micError,
  });

  final Object? startError;
  final Object? endError;
  final Object? micError;

  AgentPhase _phase;
  String? _error;
  bool _ended = false;
  List<VoiceLine> _lines;
  double _level = 0;
  bool _micEnabled = true;

  bool started = false;
  bool disposed = false;
  int endCalls = 0;

  @override
  AgentPhase get phase => _phase;
  @override
  String? get error => _error;
  @override
  bool get ended => _ended;
  @override
  List<VoiceLine> get lines => _lines;
  @override
  double get level => _level;
  @override
  bool get micEnabled => _micEnabled;

  /// Changes whatever is given and notifies listeners once.
  void emit({
    AgentPhase? phase,
    String? error,
    List<VoiceLine>? lines,
    double? level,
  }) {
    _phase = phase ?? _phase;
    _error = error ?? _error;
    _lines = lines ?? _lines;
    _level = level ?? _level;
    notifyListeners();
  }

  @override
  Future<void> start() async {
    started = true;
    if (startError case final error?) throw error;
  }

  @override
  Future<void> setMicEnabled(bool enabled) async {
    if (micError case final error?) throw error;
    _micEnabled = enabled;
    notifyListeners();
  }

  @override
  Future<void> end() async {
    endCalls++;
    if (endError case final error?) throw error;
    _ended = true;
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
