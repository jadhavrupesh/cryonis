import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';

/// What the voice agent is doing, as far as the app can tell.
enum AgentPhase { connecting, listening, thinking, speaking }

/// One transcript segment of a call.
class VoiceLine {
  const VoiceLine({
    required this.id,
    required this.fromUser,
    required this.text,
  });

  final String id;
  final bool fromUser;
  final String text;
}

/// A live voice call with the agent. The real one is LiveKit
/// ([LiveKitVoiceBackend]); the screen and tests only depend on this.
abstract class VoiceBackend extends ChangeNotifier {
  AgentPhase get phase;

  /// A human-readable failure (could not connect, agent never joined, ...).
  String? get error;

  /// The call was ended, by the user or because it failed.
  bool get ended;

  /// The running transcript of both sides, oldest first.
  List<VoiceLine> get lines;

  /// 0..1 loudness of whoever is speaking, to animate the orb.
  double get level;

  bool get micEnabled;

  /// Starts the call; progress and failures are reported through the getters.
  /// Implementations should absorb transport exceptions rather than leaving an
  /// unhandled asynchronous error in the UI.
  Future<void> start();

  Future<void> setMicEnabled(bool enabled);

  Future<void> end();
}

/// Turns a call transcript into chat messages, merging consecutive segments
/// from the same side (a long answer arrives as several segments).
List<ChatMessage> conversationFrom(Iterable<VoiceLine> lines) {
  final turns = <ChatMessage>[];
  for (final line in lines) {
    final text = line.text.trim();
    if (text.isEmpty) continue;
    final role = line.fromUser ? ChatRole.user : ChatRole.assistant;
    if (turns.isNotEmpty && turns.last.role == role) {
      turns[turns.length - 1] = turns.last.copyWith(
        content: '${turns.last.content} $text',
      );
    } else {
      turns.add(ChatMessage(role: role, content: text));
    }
  }
  return turns;
}
