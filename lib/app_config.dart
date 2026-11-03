import 'package:flutter/foundation.dart';

/// Name shown in the "... is listening" / "... is working" status lines.
const assistantName = 'Cryo';

const systemPrompt =
    'You are $assistantName, a friendly, concise AI assistant inside the '
    'Cryonis mobile app. Keep answers short and easy to read on a phone.';

/// The hosted Ollama API. This is the primary server and needs an API key.
const cloudOllamaUrl = 'https://ollama.com';

/// Default server on first launch.
String defaultOllamaUrl() => cloudOllamaUrl;

/// A model running on your own computer is the secondary option. The Android
/// emulator reaches the host machine at 10.0.2.2; everything else (iOS
/// simulator, macOS, desktop) can use localhost. A physical phone needs the
/// Mac's LAN IP, set from the in-app server settings.
String localOllamaUrl() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:11434';
  }
  return 'http://localhost:11434';
}

/// Name of the LiveKit voice agent to dispatch into the call. Must match
/// `AGENT_NAME` in agent/src/agent.py.
const voiceAgentName = 'cryonis-agent';

/// Picked automatically (in this order) when the saved model isn't available.
const preferredModels = ['gpt-oss:120b', 'gpt-oss:20b', 'llama3.2:latest'];

/// The cloud models Ollama lists as usable with free usage credits; only these
/// are offered when using the API key. The hosted `/api/tags` doesn't say which
/// models are free, so this list comes from Ollama's "free usage credits" list
/// (and was confirmed on 2026-10-26 by sending a one-token chat to every model:
/// these answered 200, the other chat models answered 402). Update it if
/// Ollama changes the list.
const freeCloudModels = {
  'beam',
  'gemma4:31b',
  'gpt-oss:120b',
  'gpt-oss:20b',
  'nemotron-3-nano:30b',
  'nemotron-3-super',
  'nemotron-3-ultra',
};

/// True for the hosted API, which only works with an API key.
bool isCloudUrl(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host == 'ollama.com' || host.endsWith('.ollama.com');
}
