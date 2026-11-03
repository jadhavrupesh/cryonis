import 'package:flutter/widgets.dart';

import '../app_config.dart';
import '../models/chat_message.dart';
import '../services/livekit_voice_backend.dart';
import '../services/voice_backend.dart';
import '../state/chat_scope.dart';
import 'agent_voice_screen.dart';
import 'routes.dart';
import 'voice_screen.dart';

/// What the voice screen hands back to the caller.
sealed class VoiceOutcome {
  const VoiceOutcome();
}

/// On-device dictation finished: send this text as a chat message.
class VoiceText extends VoiceOutcome {
  const VoiceText(this.text);

  final String text;
}

/// A live call with the agent ended: carry on in the chat from its turns.
class VoiceConversation extends VoiceOutcome {
  const VoiceConversation(this.turns);

  final List<ChatMessage> turns;
}

/// Selects either the application-owned production token endpoint or LiveKit's
/// development sandbox token server.
class VoiceConnection {
  const VoiceConnection.endpoint(this.value) : isProduction = true;
  const VoiceConnection.sandbox(this.value) : isProduction = false;

  final String value;
  final bool isProduction;
}

/// Creates the live call. Tests replace this with a fake so they don't need a
/// real WebRTC session.
@visibleForTesting
VoiceBackend Function(VoiceConnection connection) voiceBackendFactory =
    (connection) => connection.isProduction
    ? LiveKitVoiceBackend.endpoint(
        endpoint: connection.value,
        agentName: voiceAgentName,
      )
    : LiveKitVoiceBackend.sandbox(
        sandboxId: connection.value,
        agentName: voiceAgentName,
      );

/// Opens the voice screen: a live LiveKit call when a sandbox ID is set,
/// otherwise on-device dictation. A completed live transcript is returned no
/// matter which control the user uses to leave voice mode.
Future<VoiceOutcome?> openVoice(BuildContext context) async {
  final chat = ChatScope.read(context);
  final navigator = Navigator.of(context);

  if (chat.voiceAgentConfigured) {
    final connection = chat.usesProductionVoiceEndpoint
        ? VoiceConnection.endpoint(chat.livekitTokenEndpoint)
        : VoiceConnection.sandbox(chat.livekitSandboxId);
    final turns = await navigator.push<List<ChatMessage>>(
      fadeRoute(
        AgentVoiceScreen(createBackend: () => voiceBackendFactory(connection)),
      ),
    );
    return turns == null || turns.isEmpty ? null : VoiceConversation(turns);
  }

  final text = await navigator.push<String>(fadeRoute(const VoiceScreen()));
  return text == null || text.trim().isEmpty ? null : VoiceText(text);
}
