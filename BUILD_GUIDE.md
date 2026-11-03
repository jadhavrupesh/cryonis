# How Cryonis was built — step by step

A walkthrough of how this project went from an empty Flutter app to a chat app with a live voice agent:
**Flutter** (the app) → **Ollama** (the language model, local and cloud) → **LiveKit** (real-time voice).
It is written in the order things were actually done, including the wrong turns and the bugs, so you can repeat it
or understand why the code looks the way it does.

> **Secrets.** Nothing secret is written in this file. `<OLLAMA_KEY>` and `<TOKEN_SERVER_ID>` are placeholders for values
> that live in `lib/secrets.dart` and `agent/.env.local`, both ignored by git.
>
> Companion files: [README.md](README.md) (how to run it), [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) (decisions and numbers),
> [PROJECT_STATUS.md](PROJECT_STATUS.md) (what is verified and what is left), [agent/README.md](agent/README.md) (the voice agent).

---

## Contents

0. [What you get](#0-what-you-get)
1. [Prerequisites](#1-prerequisites)
2. [Create the project and turn the design into a spec](#2-create-the-project-and-turn-the-design-into-a-spec)
3. [Packages and platform permissions](#3-packages-and-platform-permissions)
4. [Build the UI](#4-build-the-ui)
5. [Talk to Ollama: streaming chat](#5-talk-to-ollama-streaming-chat)
6. [Ollama Cloud, the API key, and free models](#6-ollama-cloud-the-api-key-and-free-models)
7. [Make answers look like ChatGPT / Claude / Gemini](#7-make-answers-look-like-chatgpt--claude--gemini)
8. [Tests, including a real chat inside the macOS app](#8-tests-including-a-real-chat-inside-the-macos-app)
9. [Optional: local Ollama](#9-optional-local-ollama)
10. [Voice: decide the architecture](#10-voice-decide-the-architecture)
11. [Build the voice agent (Python)](#11-build-the-voice-agent-python)
12. [Build the LiveKit client in Flutter](#12-build-the-livekit-client-in-flutter)
13. [Set up LiveKit Cloud and deploy](#13-set-up-livekit-cloud-and-deploy)
14. [Verify the call without a microphone](#14-verify-the-call-without-a-microphone)
15. [Run it and try a call](#15-run-it-and-try-a-call)
16. [Hardening added afterwards](#16-hardening-added-afterwards)
17. [Restyle the whole app from a Dribbble shot](#17-restyle-the-whole-app-from-a-dribbble-shot)
18. [Troubleshooting: everything that went wrong](#18-troubleshooting-everything-that-went-wrong)
19. [Limits, costs, and what is left](#19-limits-costs-and-what-is-left)
20. [Cheat sheet](#20-cheat-sheet)

---

## 0. What you get

```
                       ┌────────────────────────── Flutter app (iOS / Android / macOS) ──────────────────────────┐
                       │  Home · Chat · Voice screens                                                              │
                       │                                                                                           │
   text chat ─────────►│  OllamaService ──HTTPS, streamed JSON──►  Ollama Cloud  (https://ollama.com)             │
                       │                                            └─ or local Ollama (http://localhost:11434)    │
                       │                                                                                           │
   live voice ────────►│  livekit_client Session ──WebRTC──►  LiveKit Cloud ◄──► agent/ (Python, hosted by LiveKit) │
                       │                                                         ├─ STT  Deepgram nova-3 (multi)  │
                       │  on-device dictation (speech_to_text) is the fallback   ├─ LLM  Ollama · gpt-oss:120b    │
                       └───────────────────────────────────────────────────────  ├─ TTS  Cartesia sonic-3         │
                                                                                  └─ Silero VAD + turn detector    │
```

| Piece | Choice | Why |
|---|---|---|
| App | Flutter 3.47.5 | One code base for iOS, Android, macOS |
| Language model | Ollama Cloud (API key); local Ollama as a secondary option | Hosted, nothing to run locally; free models available |
| Voice transport | LiveKit (WebRTC) | Handles VAD, turn detection, interruption (barge-in), echo cancellation |
| Voice brain | LiveKit Agents (Python) on LiveKit Cloud | Hosted; plugs in any LLM through an OpenAI-compatible API |
| Speech | LiveKit Inference (Deepgram + Cartesia) | No extra provider keys |

Standing preference that shaped everything: **don't run anything locally.** The primary path is fully hosted.

---

## 1. Prerequisites

| Need | Version used | Notes |
|---|---|---|
| macOS + Xcode | Xcode 27.1 | Accept the license for the *installed* Xcode version (see [Troubleshooting](#18-troubleshooting-everything-that-went-wrong)) |
| Flutter | 3.47.5 (Dart ^3.13) | `flutter doctor` should be clean for macOS |
| Homebrew | any recent | For the LiveKit CLI and optional local Ollama |
| `uv` + Python | uv, Python 3.12 | Manages the agent's environment (`brew install uv`) |
| Ollama Cloud account | free plan | Create an API key at <https://ollama.com/settings/keys> |
| LiveKit Cloud account | free "Build" plan | <https://cloud.livekit.io> |

Accept the Xcode license once (it needs your password, so you must type it yourself):

```bash
sudo xcodebuild -license accept
```

---

## 2. Create the project and turn the design into a spec

1. Create the app:

   ```bash
   flutter create cryonis
   cd cryonis
   ```

2. The look comes from a Dribbble shot with three screens — **Home** (header, previous conversations, quick chips, "Ask anything"
   card), **Voice** (a ring of dots, "I'm Listening…", a glow rising from the bottom) and **Chat** (flat dark user bubble, plain
   answer). The first version followed a different shot (an orange aurora look); the app was restyled to the **Lumix** shot on 2 Nov 2026
   — see [step 17](#17-restyle-the-whole-app-from-a-dribbble-shot) for how that was done.
3. Write the design down (`PROJECT_CONTEXT.md`, and `UI_SPEC.md` for the measured details) before coding: the screens, the colours,
   and **how each design element maps to Ollama**. The decisions that mattered:
   - the model pill in the header shows the **selected Ollama model** and opens a picker;
   - the avatar's dot shows **connection status**; the menu opens the **server settings**;
   - voice is **speech-to-text only** at first, because Ollama has no audio (that changes in [step 10](#10-voice-decide-the-architecture));
   - the shot's "Deep Search" / "Think" chips are left out: nothing in the backend does anything for them.
4. Keep that file updated as you go; it became the project's memory.

---

## 3. Packages and platform permissions

### Packages (first round)

```bash
flutter pub add http speech_to_text shared_preferences
```

- `http` — streaming HTTP to Ollama.
- `speech_to_text` — on-device dictation for the voice screen.
- `shared_preferences` — remembers the server address, selected model, and later the conversation.

More packages were added later in the same way: `flutter_markdown_plus markdown flutter_highlight url_launcher` (step 7),
`livekit_client` (step 12), `flutter_secure_storage file_selector` (step 16), and `integration_test` (a dev dependency, step 8).

### Permissions — without these the app silently fails

| Platform | What was added | Why |
|---|---|---|
| **macOS** (`macos/Runner/Info.plist`) | `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` | Mic + speech prompts |
| **macOS** (`DebugProfile.entitlements`, `Release.entitlements`) | `com.apple.security.network.client`, `com.apple.security.device.audio-input` | The macOS **sandbox blocks outgoing network and the mic** unless these are set |
| **iOS** (`ios/Runner/Info.plist`) | mic, speech and local-network usage strings; `NSAppTransportSecurity → NSAllowsLocalNetworking`; later `NSCameraUsageDescription` | Permission prompts; plain-http to a local Ollama; the WebRTC SDK references camera APIs |
| **Android** (`AndroidManifest.xml`) | `INTERNET`, `RECORD_AUDIO`, Bluetooth permissions, `usesCleartextTraffic="true"`, `<queries>` for speech and https links; later `MODIFY_AUDIO_SETTINGS`, `ACCESS_NETWORK_STATE`, `CHANGE_NETWORK_STATE` | Network, mic, plain-http to a local Ollama, WebRTC audio |

Check that the macOS build really has the entitlements:

```bash
codesign -d --entitlements - build/macos/Build/Products/Debug/Cryonis.app | grep -E "network.client|audio-input"
```

---

## 4. Build the UI

Structure (all under `lib/`):

```
main.dart                  app + ChatScope + first model refresh
theme/app_theme.dart       colours, gradients, text styles, ThemeData
screens/                   home_screen, chat_screen, voice_screen, routes (fade transition)
widgets/                   app_scaffold, app_header, dot_ring, glow_backdrop, voice_widgets, input_bar, sheets, ...
state/                     chat_controller (ChangeNotifier) + chat_scope (InheritedNotifier)
services/                  ollama_service, speech_service, ...
models/chat_message.dart
```

Key ideas, in the order they were built:

1. **Theme** (`app_theme.dart`): the image-derived grayscale colours (`surface`, `accent`, `glowIdle`, `glowActive`…), the silver gradient, `inter(...)`
   for text, and one `ThemeData`. Everything else reads from it. Inter is a bundled variable font; `inter()` sets its `wght` axis so
   every weight comes from one file.
2. **`AppScaffold`**: a black screen with the content constrained to a 520 px column so the app also looks right in a wide macOS
   window, an optional full-bleed backdrop (the voice glow), and the **keyboard inset applied to the content only**.
3. **`AppHeader`**: menu · `model ⌄` pill · avatar with a connection dot. It also works with no `ChatController` above it, so an
   isolated screen (and its test) cannot crash on it.
4. **Small widgets**: the "Ask anything" card and the compact chat input (mic when empty, send when there is text, stop while
   streaming), chips, and the shared silver mic.
5. **Three screens** and navigation: Home → Chat, Home → Voice, Chat → Voice. The Voice screen *returns a result* (text to send,
   or later a finished conversation) instead of navigating itself. The back arrow in the chat header closes the conversation.
6. **State**: one `ChatController` (a `ChangeNotifier`) owns the messages, models, connection status and the in-flight request;
   `ChatScope` (an `InheritedNotifier`) hands it to every screen. No state-management package was needed.

---

## 5. Talk to Ollama: streaming chat

Ollama is plain REST. Two endpoints matter:

| Endpoint | Use |
|---|---|
| `GET /api/tags` | list the installed (or hosted) models |
| `POST /api/chat` with `"stream": true` | chat; the reply arrives as **newline-delimited JSON**, one object per token batch |

Each streamed line looks like `{"message":{"role":"assistant","content":"Hel"},"done":false}`; the last has `"done": true`.
Errors can arrive as a line `{"error":"…"}` even inside a 200 response.

How `OllamaService.chat` works (simplified):

```dart
Stream<String> chat({required String model, required List<ChatMessage> messages, String? system}) {
  final client = _clientFactory();          // a NEW http client per request, so closing it aborts the request
  var cancelled = false;
  late final StreamController<String> out;

  Future<void> run() async {
    try {
      final response = await client.send(http.Request('POST', _uri('/api/chat'))
        ..body = jsonEncode({'model': model, 'stream': true, 'messages': [...]}));
      if (response.statusCode != 200) throw _httpError(response.statusCode, await response.stream.bytesToString());
      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        final json = jsonDecode(line);
        if (json['error'] is String) throw OllamaException(json['error']);
        final content = json['message']?['content'];
        if (content is String && content.isNotEmpty) out.add(content);
        if (json['done'] == true) break;
      }
    } catch (e) {
      if (!cancelled) out.addError(e);       // after a cancel nobody is listening: drop it silently
    } finally { client.close(); }
  }

  out = StreamController(onListen: run, onCancel: () { cancelled = true; client.close(); });
  return out.stream;
}
```

Things learned the hard way:

- **Use `LineSplitter` on the byte stream.** A JSON line can be split across network chunks (even in the middle of a multi-byte
  character); there is a test for exactly that.
- **Build the stream on a `StreamController`, not `async*`.** With `async*`, a request that fails *after* the user pressed
  "Close chat" surfaced as an **unhandled exception**. With a controller, a late failure after cancel is dropped.
- **Stopping = closing the client.** Ollama stops generating when the connection closes.
- **Keep the cause in error messages.** "Can't reach Ollama at … (SocketException: …)" is far easier to debug than a generic line.

`ChatController` then adds: `send`, `stop` (keeps the partial answer), `retry`, `regenerate`, `reset`, model selection, and a
connection state (`checking / online / offline`). Each request sends a short system prompt plus the whole conversation (error
messages are excluded from the history).

---

## 6. Ollama Cloud, the API key, and free models

1. Make the server address configurable. Default: **`https://ollama.com`** (Ollama Cloud). The same two endpoints work there;
   requests carry `Authorization: Bearer <OLLAMA_KEY>`.
2. **Only ever send the key over `https://`.** If someone switches the address to a plain-http LAN server, the key must not leak,
   so the header is simply omitted for http.
3. Error mapping: **401** → "The server rejected the API key"; any other HTTP error shows the server's own message. With the cloud
   server selected and no key, the app asks for one *without* making a request.
4. **Where the key lives:** `lib/secrets.dart` (a `const ollamaApiKey`) is the development default and is **in `.gitignore`**.
   A key typed into the app's settings overrides it (stored with secure storage after step 16).
5. **Which models are free?** `GET /api/tags` on the hosted API doesn't say. Two checks agreed:
   - Ollama's own list of models usable with free credits;
   - a probe: send a one-token chat to **every** hosted model; the paid ones answer **HTTP 402**
     ("this model is not included in your free usage").
   Seven models work: `beam`, `gemma4:31b`, `gpt-oss:120b`, `gpt-oss:20b`, `nemotron-3-nano:30b`, `nemotron-3-super`,
   `nemotron-3-ultra`. They are the constant `freeCloudModels` in `lib/app_config.dart`, and the model picker shows only these
   when the cloud server is selected. The default chat model is the first available of `gpt-oss:120b`, `gpt-oss:20b`,
   `llama3.2:latest`.
6. `https://ollama.com` answers the browser's CORS preflight with **405**, so a **web build cannot use Ollama Cloud**. That is
   why the project targets iOS, Android and macOS.

---

## 7. Make answers look like ChatGPT / Claude / Gemini

The first version showed answers as plain text in a dark bubble. That did not look professional, so the AI side was redesigned:

- **No bubble**: plain **full-width Markdown** (no avatar header, as in the design). The user's message is a flat dark bubble on the right.
- **Markdown** with `flutter_markdown_plus` (the original `flutter_markdown` is discontinued): headings, bold/italic, lists, quotes,
  tables (scroll sideways), links (`url_launcher`), inline-code chips, horizontal rules. One `MarkdownStyleSheet` in
  `widgets/markdown_view.dart` sets all the typography.
- **Code blocks**: a builder on the `pre` tag returns a `CodeBlock` — a dark card with the language label and a **Copy** button in a
  header bar, and syntax highlighting from `flutter_highlight` (atom-one-dark). Long lines scroll sideways.
  *Bug caught by a test:* `HighlightView` **throws when the language is null**, and a fence without a language is very common, so
  the code falls back to `'plaintext'`. Unfinished fences while streaming render fine.
- **Actions** under a finished answer: copy, and regenerate (latest answer only). While streaming: "Generating ✳" under the text.
- `SelectionArea` around the list lets you select text across messages; the list fades at the top and bottom edges.

---

## 8. Tests, including a real chat inside the macOS app

| Layer | What | How |
|---|---|---|
| Service | streaming, split chunks, errors, key header, cancel | `MockClient` from `package:http/testing.dart` via `test/fake_ollama.dart` |
| Controller | send/stop/retry/regenerate, free-model filter, key logic, history | same fake server |
| Widgets | home → chat flow, Markdown rendering, copy button | `testWidgets` |
| **Native** | a **real** chat with the real key inside the real sandboxed macOS app, plus PNG renders of the screens | `integration_test/native_chat_test.dart` |

```bash
flutter test                                                      # unit + widget tests
dart analyze . --fatal-infos                                      # strict analysis
flutter test integration_test/native_chat_test.dart -d macos      # real chat; uses a little free quota
```

Notes:

- The avatar orb and the voice ring animate forever, so use `pump(Duration)` loops instead of `pumpAndSettle`.
- Under the test clock a stream's **"done" event is never delivered**; wrap the wait in `await tester.runAsync(...)` before
  asserting on things that appear when a stream finishes (e.g. the copy/regenerate buttons).
- The native test writes screenshots to the app's sandbox container
  (`~/Library/Containers/<bundle id>/Data/tmp/`) — a way to *see* the real UI without clicking.
- Stop a running copy of the app before running the native test (both build into the same folder).

---

## 9. Optional: local Ollama

Only for a secondary, offline-friendly path (the app works without it).

```bash
brew install ollama                 # needs the Xcode license accepted first
ollama serve                        # keep this terminal open (or: brew services start ollama)
curl http://localhost:11434/api/pull -d '{"model":"llama3.2"}'     # pull a model through the API
curl http://localhost:11434/api/tags                                # confirm it is installed
```

In the app: menu → **This Mac** → **Save & connect**. Host by target: iOS simulator / macOS `localhost`,
Android emulator `10.0.2.2`, a physical phone needs the Mac's LAN IP and `OLLAMA_HOST=0.0.0.0`.

---

## 10. Voice: decide the architecture

Ollama has **no audio**. A voice agent needs speech-to-text (STT) → LLM → text-to-speech (TTS), plus turn-taking and interruptions.
The decisions, with the reasoning:

1. **Transport: WebRTC via LiveKit.** Plain REST can't carry continuous two-way audio or let the user interrupt. LiveKit already
   provides VAD, turn detection, **barge-in**, and echo cancellation / noise suppression. (Alternatives considered: on-device
   `speech_to_text` + `flutter_tts`; a custom WebSocket backend; Pipecat. LiveKit was chosen.)
2. **LLM: Ollama Cloud through its OpenAI-compatible API** (`https://ollama.com/v1`) using LiveKit's OpenAI plugin.
3. **STT/TTS: LiveKit Inference** (Deepgram nova-3 multilingual, Cartesia sonic-3) — hosted, no extra keys, handles Hindi/English mixes.
4. **Where it runs: all hosted.** LiveKit Cloud hosts the server **and** the agent; Ollama Cloud hosts the model.
5. **Which model for voice?** Time to the first text token matters most, and it is the slowest stage of a voice turn.
   Measured through `https://ollama.com/v1` with the agent's real system prompt, from India, requests interleaved:

   | Model | First text, median | Notes |
   |---|---|---|
   | `gpt-oss:120b` | **0.75 s** (20 requests) | no failures in 38 requests over three tests |
   | `beam` | 1.29 s (20 requests) | 3 of 38 requests streamed reasoning but never text — a long silence in a call |
   | `gpt-oss:20b` | ~1.7 s | |
   | `nemotron-3-nano:30b` | no text | spends its token budget on reasoning |
   | `gemma4:31b` | **~10 s** | far too slow for voice (and a poor chat default) |

   → `gpt-oss:120b` for voice. (We first picked `beam` from a simpler early test; the larger test and the agent's own logs
   changed that.) Medians move with server load, so gaps under ~0.3 s are noise.
6. **VoiceStudio** (an open-source local voice-cloning/TTS app) was evaluated because it was requested. It is a *speech provider*
   (OpenAI-compatible `/v1/audio/speech` and `/v1/audio/transcriptions`), AGPL-3.0, and **local-first — not a hosted service**.
   A LiveKit-Cloud-hosted agent can't reach a Mac's `localhost`, which conflicts with "run nothing locally". So it is **off by default**;
   the agent has a switch (`SPEECH_PROVIDER=voicestudio`) that is unit-tested for wiring only.
7. **Know the free limits** (LiveKit "Build" plan, hard caps, reset monthly): 1,000 agent minutes, 5,000 WebRTC minutes, 50 GB, and
   **$2.50 of Inference credit ≈ 50 minutes of talking** (this is the real limit); **one deployed agent**; 5 concurrent sessions; a
   10–20 s cold start when the free agent has scaled to zero.

---

## 11. Build the voice agent (Python)

Folder `agent/` (managed with `uv`, Python 3.12). It is **not** part of the Flutter build — LiveKit Cloud builds and runs it.

```
agent/
  src/agent.py        the whole agent
  tests/test_agent.py 10 tests
  pyproject.toml, uv.lock
  Dockerfile, .dockerignore     (used by `lk agent create` to build the image on LiveKit's side)
  .env.example, .env.local      (OLLAMA_API_KEY; .env.local is gitignored and not uploaded)
  README.md, livekit.toml       (livekit.toml is written by the deploy command)
```

1. Dependencies (`pyproject.toml`): `livekit-agents[openai,silero]` (1.8.x) and `python-dotenv`; dev: `pytest`, `pytest-asyncio`.

   ```bash
   cd agent
   uv lock --python 3.12 && uv sync --python 3.12
   uv run pytest -q
   ```

2. The agent (`src/agent.py`), in essence:

   ```python
   server = AgentServer()
   server.setup_fnc = lambda proc: proc.userdata.update(vad=silero.VAD.load())   # load VAD once per process

   def build_session(vad, speech):
       return AgentSession(
           stt=inference.STT(model="deepgram/nova-3", language="multi"),
           llm=openai.LLM(model="gpt-oss:120b", base_url="https://ollama.com/v1", api_key=os.environ["OLLAMA_API_KEY"]),
           tts=inference.TTS(model="cartesia/sonic-3", voice="<voice id>"),
           vad=vad,
           turn_handling={                            # (the old top-level turn_detection= / preemptive_generation= are deprecated)
               "turn_detection": inference.TurnDetector(),
               "preemptive_generation": {"enabled": True},   # start the LLM on the partial transcript
           },
       )

   @server.rtc_session(agent_name="cryonis-agent")      # must match voiceAgentName in the Flutter app
   async def entrypoint(ctx):
       session = build_session(ctx.proc.userdata["vad"], SpeechSettings.from_env())
       await session.start(agent=CryoAssistant(), room=ctx.room, room_options=build_room_options(speech))  # mic noise filter
       await ctx.connect()
       await session.say(GREETING)                      # see the lesson below
   ```

   The instructions tell the model: short spoken replies, no markdown or symbols; it speaks **English and Hindi**: reply in the user's
   language, answer a Hindi/English mix with the same mix, and use English for any other language.
3. **Speech engine switch**: `SpeechSettings.from_env()` reads `SPEECH_PROVIDER` (`livekit` default, or `voicestudio`) and builds the
   STT/TTS accordingly. Tests cover the wiring without any network. The same class reads three more settings from the agent's
   secrets: `STT_LANGUAGE` (`multi`: English + Hindi), `NOISE_CANCELLATION` (`nc` default: LiveKit's background-noise filter on the
   caller's mic; `off`; `bvc` voice isolation, billed extra and untried) and `INTERRUPTION_MIN_WORDS` (0). Change one on the live agent
   with `lk agent update-secrets --secrets KEY=VALUE` — **never add `--overwrite`**, it asks to wipe every other secret.
   The agent also logs per-turn timings and `interruption: agent stopped X s after the user started talking`; read those with
   `lk agent logs` instead of timing it from a test client (a test client's own audio buffering and blocking skew its numbers by about
   a second). Findings: a clear "Stop." stopped the agent after 0.19 s; traffic-like rumble did not interrupt it; **voice-like
   chatter still does** (details in `agent/README.md`).
4. **Lesson — the silent greeting.** The first version greeted with `generate_reply(instructions="Greet the user…")`. The agent
   joined, went "thinking" and then gave up in 0.3 s. Cause: **`beam` returns an empty reply when the prompt has no user message**
   (a lone system instruction). Fix: speak a fixed line with `session.say(...)` — instant, free, and can't come back empty.
   Remember this for any agent-initiated turn.
5. Verify the container steps locally: `uv run src/agent.py download-files` (what the Dockerfile runs) and
   `uv run src/agent.py --help`.

---

## 12. Build the LiveKit client in Flutter

```bash
flutter pub add livekit_client        # 2.13.x, brings flutter_webrtc
```

`livekit_client` ships a high-level **`Session`** that does the heavy lifting:

```dart
final session = lk.Session.withAgent(
  'cryonis-agent',
  tokenSource: lk.DevelopmentTokenSource(id: '<TOKEN_SERVER_ID>'),   // dev only
  options: lk.SessionOptions(),                                      // pre-connect audio on by default
);
await session.start();
// session.agent.agentState  → initializing / listening / thinking / speaking  (from the `lk.agent.state` attribute)
// session.messages          → live transcripts of both sides (from the `lk.transcription` text stream)
// session.room.localParticipant.setMicrophoneEnabled(false) → mute
```

The app wraps it so the UI and tests never touch WebRTC:

| File | Role |
|---|---|
| `services/voice_backend.dart` | `VoiceBackend` interface (phase, error, lines, level, mic, start/end), `VoiceLine`, and `conversationFrom()` (merges consecutive segments into chat messages) |
| `services/livekit_voice_backend.dart` | the real implementation on `lk.Session`; maps SDK state to `AgentPhase`; turns token-server errors into readable messages; polls audio level to drive the orb |
| `screens/agent_voice_screen.dart` | the call UI: ring, caption or latest-turn transcript, controls (keyboard = end and continue in chat, mic = mute, X = end), glow, "Try again" on failure |
| `screens/voice_flow.dart` | `openVoice()` picks a **live call** if a sandbox ID or token endpoint is configured, otherwise **on-device dictation**; returns `VoiceText` or `VoiceConversation` |
| `widgets/voice_widgets.dart` | the voice-mode pieces shared by both voice screens: controls with the pulsing mic halo, the "I'm Listening…" caption, the word-by-word transcript reveal |
| `state/chat_controller.dart` | stores the sandbox ID, `voiceAgentConfigured`, and `addConversation()` so a finished call continues as a text chat |
| `widgets/sheets.dart` | settings fields: *Live voice calls (LiveKit)* → production token endpoint, sandbox ID |

**Making it feel like a real agent.** The call screen's look came from the Lumix shot (step 17). The motion follows the agent's own loop,
so you can read the phase without any text. `widgets/dot_ring.dart` draws ~2,000 square dots in a ring and each phase adds its own
travelling light on top of the "boiling" noise:

| Phase | Ring |
|---|---|
| **Observe** (listening) | breathes slowly; soft ripples travel outward when you speak |
| **Orient** (your words arriving) | the ring contracts and moves up; ripples run **inward**, drawing the dots in |
| **Decide** (thinking) | a bright comet arc orbits the ring, the rest dims to a ghost |
| **Act** (speaking) | ripples are pushed outward in time with Cryo's voice; the ring swells |

The moods glide into each other (every number is eased, so nothing jumps). The brightness comes from the call's real audio level (fast
attack, slow release, like a meter). The ripple and comet shapes are small pure functions (`rippleFactor`, `sweepFactor`) so tests can
check that crests really travel the right way. To review the design without a call, `flutter test
integration_test/voice_ui_preview_test.dart -d macos` renders each state to PNGs inside the real app. (Lessons: a `Text.rich` wraps your
span in a root span, so tests must look one level deeper; and a widget that keeps its own clock must accumulate time itself, because a
restarted `Ticker` begins again at zero.)

---

## 13. Set up LiveKit Cloud and deploy

You do these once. Commands run on your Mac; the agent then runs on LiveKit's servers.

1. **Create the project.** <https://cloud.livekit.io> → sign up → *Create project* (e.g. `cryonis`). No keys need copying.
2. **Install the CLI and link it.**

   ```bash
   brew install livekit-cli
   lk cloud auth          # INTERACTIVE: type a device name, then approve in the browser tab it opens
   lk project list        # confirm: your project is listed (default marked *)
   ```

   `--yes` does **not** work for this command; it needs a real interactive terminal.
3. **Give the agent its secret.** Put your Ollama key in `agent/.env.local` (gitignored, excluded from the upload by `.dockerignore`):

   ```bash
   cd agent
   printf 'OLLAMA_API_KEY=%s\n' '<OLLAMA_KEY>' > .env.local && chmod 600 .env.local
   ```
4. **Deploy.** The CLI uploads `agent/`, builds the Docker image on LiveKit's side, and starts it:

   ```bash
   lk agent create --secrets-file .env.local .
   ```

   Answer the prompts: confirm the project and pick the region closest to the intended users;
   at "view logs?" either answer is fine (`n`). It prints an agent ID and writes `livekit.toml`.
5. **Check it is running.**

   ```bash
   lk agent status        # Status: Running, Replicas 1/1/1, name cryonis-agent
   lk agent logs          # streams; stop with Ctrl-C
   ```
6. **Get the app a token.** In the dashboard open **Settings** (project) → switch on **Development token server** → copy the
   **Token server ID** (`<TOKEN_SERVER_ID>`, looks like `cryonis-xxxxxx`). Give it to the app either way:
   - in the app: menu (top right) → scroll down inside the sheet to **Live voice calls (LiveKit)** → *LiveKit sandbox ID* → **Save & connect**; or
   - in `lib/secrets.dart`: `const livekitSandboxId = '<TOKEN_SERVER_ID>';` then restart the app.

   The development token server is **insecure** (anyone with the ID can start calls on your project). Switch it off after testing, and
   use an authenticated token endpoint for production.
7. **Updating the agent later:** `lk agent deploy` (the free plan allows only **one** deployed agent, so never run `create` twice).

---

## 14. Verify the call without a microphone

You can prove the whole cloud pipeline without clicking anything, by joining as a test client and speaking to the agent with a
synthesised voice. The steps (a throw-away Python script using the `livekit` package already in `agent/.venv`):

1. `POST https://cloud-api.livekit.io/api/v2/sandbox/connection-details` with header `X-Sandbox-ID: <TOKEN_SERVER_ID>` and body
   `{"room_name": "...", "participant_name": "...", "room_config": {"agents": [{"agent_name": "cryonis-agent"}]}}`
   → `{"server_url": ..., "participant_token": ...}`.
   Python's default `User-Agent` is blocked by the service in front of it (**HTTP 403, "error code: 1010"**); send your own `User-Agent`.
2. Join the room with `livekit.rtc`, publish a microphone track.
3. Create the "voice" with macOS: `say -o q.aiff "What is the capital of France?"` then
   `afconvert -f WAVE -d LEI16@48000 -c 1 q.aiff q.wav`; push the samples in 10 ms frames, then keep feeding **silence** (the agent's
   VAD needs a steady stream to detect the end of speech).
4. Watch the participant attribute `lk.agent.state` and read the `lk.transcription` text stream (register a **synchronous** handler
   that schedules your async reader; an async function registered directly is never awaited).

What it showed on the deployed agent:

```
agent joined → greeting spoken ("Hi, I'm Cryo. How can I help you today?")
HEARD (STT):  What is the capital of France?
state: listening → thinking → speaking
AGENT SAYS:   The capital of France is Paris.
```

Measured delay from the end of the caller's speech to the first audio of the reply: **2.8 s and 4.0 s** in two runs. Roughly: ~1.6 s for
speech-to-text + turn detection to decide the user is done, ~1.4 s for the model's first tokens (with a nearby agent region; Ollama in the
US) and TTS to start, ~0.8 s to the first audible audio. Ideas to lower it: a shorter endpointing delay, an STT with built-in
turn detection, a faster model, a region nearer Ollama.

---

## 15. Run it and try a call

```bash
flutter pub get
flutter run -d macos            # Android: flutter run -d <device>; iOS needs a working simulator/device
```

Try the live call:

1. Tap the silver **mic on the home screen**; allow microphone access when macOS asks.
2. Wait for "Connecting…" (up to 10–20 s on a cold free agent), then the greeting.
3. Talk. The ring changes with the phase (**listening → thinking → speaking**); the latest turn appears as it is said. Interrupt it
   mid-sentence to test barge-in.
4. Tap either the **keyboard button** or **X** to end voice mode and continue the completed transcript as text.
5. Prefer the Mac's built-in mic/speakers. **Bluetooth earbuds drop to low-quality call audio and add delay.**

Without a sandbox ID the same mic button opens on-device dictation instead (free, no spoken replies).

---

## 16. Hardening added afterwards

Done later in the project (see `PROJECT_STATUS.md` for the verified list):

- **Secure key storage**: `flutter_secure_storage` (Keychain / Keystore) for the Ollama key typed in the app; old plain-text values are migrated
  and removed after a successful secure write. `lib/secrets.dart` is only a development fallback and is ignored in release builds.
- **Image prompts**: PNG / JPEG / WebP, preview and remove, up to 4 images of 5 MB, sent as Ollama base64 `images` (`file_selector`).
- **Conversation persistence**: chats (and attached images) are serialised and restored; "Previous conversations" on Home lists it (title and time of last activity).
- **Production token endpoint**: the settings sheet accepts an application-owned **HTTPS** endpoint (validated: no http, no URL credentials) which
  takes precedence over the development sandbox ID. The service itself (with real user auth) still has to be built.
- **Release engineering**: bundle id `com.rupeshjadhav.cryonis`, Android signing via an ignored `android/key.properties`
  (example provided), strict analysis options, macOS dependencies via Swift Package Manager, and (since removed, see
  the README) a GitHub Actions workflow running analysis, tests, an Android debug build and a macOS debug build.
- Call robustness: start / mic / end / dispose failures can't become unhandled async errors; a failed call shows a visible retry.

---

## 17. Restyle the whole app from a Dribbble shot

On 2 Nov 2026 the whole UI was rebuilt to match the "Lumix – AI Platform Mobile App" shot. The method is reusable for any animated shot:

1. **Find the media.** The shot page's `<video>` elements and its HTML list every file as `…/userupload/<id>/file/<hash>.mp4` in `small-`,
   `large-` and original variants; the original is the one to analyse (here 14 s, 60 fps, 2880×2160, ~20 MB). A second clip on the page
   was only the designer's promo card, so it was ignored. Only that shot's own files were downloaded, into a scratch folder outside the project.
2. **Sample the animation, 2 frames per second.** At 60 fps every 30th frame is 0.5 s apart:
   `ffmpeg -i main.mp4 -vf "select='not(mod(n\,30))',scale=1000:750" -fps_mode vfr frames/m_%02d.png`. Tile them 2×2 with `-vf tile=2x2` to
   read the whole 14 s as seven contact sheets and write down what happens at each half second.
3. **Read the screens at full resolution.** Pull single frames at full size, crop each phone (`crop=770:1640:x:y`), and sample exact colours
   (a ten-line Swift tool over CoreGraphics worked when Pillow was not installed). The phones are drawn at about 1.88 px per dp, so sizes
   are px ÷ 1.88.
4. **Write it down** before coding: `UI_SPEC.md` has the tokens, type scale, the motion timeline and the mapping onto the app.
5. **Build bottom-up:** theme and font → shared widgets (header, glow, ring, voice widgets, input card) → screens → delete the old
   widgets → fix the tests → check on a device.
6. **Check cheaply.** A throwaway `flutter test` that renders one widget to a PNG (`RenderRepaintBoundary.toImage`) lets you tune a
   painter by eye without a device; `integration_test/voice_ui_preview_test.dart` renders every screen state inside the real macOS app
   with the real font; the phone is for the final look.

**Not copied:** the shot's name, logo, avatar photo and promo clip. **Left out:** its "Deep Search" and "Think" chips, because nothing in
the backend does anything for them.

**What the build turned up:**
- `WordRevealText` (new words fade grey → white) had two clock bugs that a test caught: text present on the first frame stayed grey, and a
  word arriving after a finished reveal waited for the restarted ticker's clock to catch up. It now accumulates its own time.
- The header read the chat controller unconditionally, so every isolated screen test crashed; `ChatScope.maybeOf` fixed that for good.
- The bottom glow's corner highlight had a hard top edge; its radius now reaches zero exactly where the glow ends.
- A chip whose label cannot shrink overflows with a wide system font; labels are `Flexible` with an ellipsis.
- The mic is a `Hero` between the Home card and the voice screen, turning from a rounded square into a circle in flight.

---

## 18. Troubleshooting: everything that went wrong

| Symptom | Cause | Fix |
|---|---|---|
| `flutter build macos` / `brew` say "You have not agreed to the Xcode license" | The license is accepted **per Xcode version**; the recorded one was 26.4, installed was 27.1 | `sudo xcodebuild -license accept` (type your password), then re-check `defaults read /Library/Preferences/com.apple.dt.Xcode IDEXcodeVersionForAgreedToGMLicense` |
| `brew install` sits at "Do you want to proceed? [y/n]" | Homebrew asks before installing dependencies; a running command can't be typed into by an assistant | `yes \| HOMEBREW_NO_AUTO_UPDATE=1 brew install <formula>` |
| macOS app can't reach the network or mic | Sandbox entitlements missing | Add `network.client` and `audio-input` to **both** entitlements files; verify with `codesign -d --entitlements -` |
| Web build can't talk to Ollama Cloud | `ollama.com` answers CORS preflight with 405 | Use iOS / Android / macOS (or a backend proxy) |
| "Can't reach Ollama" appeared during a restart | The app was killed while a request was in flight | Harmless; cancelled requests no longer raise unhandled errors (`StreamController`) |
| App crashes rendering a code block with no language | `HighlightView` throws on a null language | Fall back to `'plaintext'` |
| A widget test never sees the copy/regenerate buttons | The test clock never delivers a stream's "done" event | `await tester.runAsync(() => Future.delayed(...))` then pump |
| Chat default feels slow (10 s) | `gemma4:31b` was selected | Default to `gpt-oss:120b` / `beam`; avoid `gemma4:31b` for voice |
| `lk cloud auth` sits at "What is the name of this device?" | It is interactive; `--yes` fails | Type any name + Enter, then approve in the browser; confirm with `lk project list` |
| `lk agent create` asks for a region / logs | Interactive prompts | Pick the region closest to your intended users; answer `n` to logs |
| Agent joins but never greets | `beam` returns an **empty reply** to a prompt with no user message | Greet with `session.say(...)` |
| Voice reply feels slow | Mostly the model's first word (~1.4 s of ~1.9 s); turn detection overlaps it | Read the agent's per-turn log lines with `lk agent logs`; use `gpt-oss:120b`; don't bother lowering the endpointing delay |
| A spoken question is mis-heard, or comes back in the wrong script | Deepgram nova-3 `multi` is intermittently wrong (5 of 23 English utterances with synthetic test voices) | A fixed `en-IN` did not help and broke Hindi, so keep `multi`. Change it without a rebuild: `lk agent update-secrets --secrets STT_LANGUAGE=<code>` (never add `--overwrite`: it asks to wipe all secrets). Check with a real voice before changing providers |
| The agent stops talking mid-answer when other people are talking nearby, and does not resume | Voice-like background chatter is detected as the caller interrupting (0.4 s in tests); `NOISE_CANCELLATION=nc` and `INTERRUPTION_MIN_WORDS=1` did not stop it | Unsolved. Candidate: `NOISE_CANCELLATION=bvc` (voice isolation, billed extra, untested; decide before enabling). Traffic-like noise is not a problem |
| Android run: `flutter devices` lists your phone | It is connected and authorised | `flutter run -d <device id>`; the first Gradle build takes ~30 s, mic permission is already declared in the manifest |
| Token-server call from a script returns 403 `error code: 1010` | Default Python `User-Agent` is blocked | Send a custom `User-Agent` (curl works) |
| Can't find "Live voice calls (LiveKit)" in the app | It is at the bottom of the settings sheet | Scroll inside the sheet, or set `livekitSandboxId` in `lib/secrets.dart` and restart |
| A second `lk agent create` fails / dashboard shows Agents 1/1 | Free plan allows one deployed agent | Update with `lk agent deploy` |
| iOS simulator unavailable | "CoreSimulator is out of date" for Xcode 27.1 | Update macOS/Xcode components; macOS and Android builds are unaffected |
| Voice sounds bad or lags | Bluetooth earbuds use low-quality call mode | Use the built-in mic/speakers or wired headphones |

---

## 19. Limits, costs, and what is left

- **LiveKit free plan:** ≈ 50 minutes of talking per month (the $2.50 Inference credit), hard-capped; 10–20 s cold start; 1 agent; development token server only.
- **Ollama free usage:** only the 7 listed models; one request at a time.
- **Latency:** ~1.4–2 s from the end of your speech to the start of the reply inside the agent (the model's first word is ~1.4 s of that); a scripted test client hears 3–5 s because of its own buffering. Not 300 ms.
- **Not yet verified by ear:** audio quality in the app, barge-in with a real voice, reconnect, and how chatter behaves in a real room. iOS has not been run; Android runs on the A142.
- **Before a public release:** an authenticated token service, store signing credentials, and a decision on whether provider keys stay user-supplied.
- Nice to have: show the model's reasoning for thinking models, math rendering, quota display, cheaper/faster speech models, a backend proxy for web.

---

## 20. Cheat sheet

```bash
# --- app ---
flutter pub get
flutter run -d macos
dart analyze . --fatal-infos
flutter test
flutter test integration_test/native_chat_test.dart -d macos    # real chat in the native app (uses free quota)

# --- local Ollama (optional) ---
ollama serve
curl http://localhost:11434/api/tags

# --- agent ---
cd agent
uv sync --python 3.12
uv run pytest -q
uv run src/agent.py download-files

# --- LiveKit ---
brew install livekit-cli
lk cloud auth                              # interactive
lk project list
lk agent create --secrets-file .env.local .    # once
lk agent deploy                            # every update
lk agent status
lk agent logs                              # Ctrl-C to stop
```

### Where secrets live (all gitignored)

| Secret | Where | Used by |
|---|---|---|
| Ollama API key | `lib/secrets.dart` (dev default) and the app's secure storage | the app → `https://ollama.com` |
| Ollama API key (agent copy) | `agent/.env.local` → stored as a secret on LiveKit | the agent → `https://ollama.com/v1` |
| LiveKit token server ID | `lib/secrets.dart` or the app settings (preferences) | the app → LiveKit token server |
| LiveKit CLI credentials | `~/.livekit/cli-config.yaml` (written by `lk cloud auth`) | the `lk` CLI |
