import 'dart:math' as math;

import 'package:speech_to_text/speech_to_text.dart';

/// Wraps `speech_to_text`. Ollama has no voice input, so speech is
/// transcribed on the device and the resulting text is sent as a normal chat
/// message.
class SpeechService {
  final SpeechToText _stt = SpeechToText();

  // Sound levels are platform specific (dB on iOS), so normalise against the
  // range seen so far.
  double _minLevel = -2;
  double _maxLevel = 10;

  bool get isListening => _stt.isListening;

  /// Returns false when recognition is unavailable or permission was denied.
  Future<bool> init({
    required void Function(String message) onError,
    required void Function(bool listening) onListeningChanged,
  }) {
    return _stt.initialize(
      onError: (e) {
        // Timeouts and "no match" are normal when the user stays quiet.
        if (e.permanent) onError(e.errorMsg);
      },
      onStatus: (status) =>
          onListeningChanged(status == SpeechToText.listeningStatus),
    );
  }

  Future<void> start({
    required void Function(String words, bool isFinal) onWords,
    required void Function(double level) onLevel,
  }) {
    return _stt.listen(
      onResult: (r) => onWords(r.recognizedWords, r.finalResult),
      onSoundLevelChange: (double raw) {
        _minLevel = math.min(_minLevel, raw);
        _maxLevel = math.max(_maxLevel, raw);
        onLevel(((raw - _minLevel) / (_maxLevel - _minLevel)).clamp(0.0, 1.0));
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  Future<void> stop() => _stt.stop();

  Future<void> cancel() => _stt.cancel();
}
