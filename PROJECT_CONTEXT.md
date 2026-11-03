# Cryonis — Project Context

## Overview
**Cryonis** is a Flutter AI assistant app (iOS / Android / macOS) powered by the **Ollama API**, with a **live voice agent** over **LiveKit**.
**Primary: Ollama Cloud (`https://ollama.com`) with an API key. Secondary: a model running locally on your own machine.**
**Standing preference: don't run anything locally** (no local LiveKit server, no local Ollama required). Everything primary is hosted:
LiveKit Cloud (transport + agent hosting + speech), Ollama Cloud (the language model).
The UI follows the Dribbble shot "Lumix – AI Platform Mobile App" by Barly Design
(https://dribbble.com/shots/26513278-Lumix-AI-Platform-Mobile-App): layout, colours and motion only, no brand assets. The whole app was
restyled to it on 2 Nov 2026; the full analysis (frame-by-frame timeline, measured colours, sizes) is in `UI_SPEC.md`.
(The first version followed "AI Agent Mobile App UI Animation…" by vino_costa, an orange-aurora look; that styling is gone.)

- Project path: `/Users/rupeshjadhav/StudioProjects/cryonis`
- Status (text chat): all screens are built and wired to Ollama; analyzer clean (`--fatal-infos`), 104 Flutter tests and 40 agent tests pass.
  Debug builds succeed for macOS and Android. A real chat on Ollama Cloud (free model,
  real key, sandboxed app) is covered by `integration_test/native_chat_test.dart`.
- Status (UI): **restyled on 2 Nov 2026** to the Lumix shot (see below and `UI_SPEC.md`): Home, Chat and both voice screens, the header,
  sheets and Markdown, plus a distinct ring animation for each phase of the agent's loop. Checked on the A142 phone (Home, a live call opening, Chat) and by native macOS renders of every state
  (`integration_test/voice_ui_preview_test.dart`). Not yet checked on a phone: the new ring phases live, the transitions side by side with
  the shot, the settings sheets in the new colours, and a long call.
- Status (voice agent): **deployed and working end to end on LiveKit Cloud.**
  - **One agent source of truth:** on 3 Nov 2026 the deployed bilingual/table-filter behavior and active LiveKit ID were consolidated into
    `agent/`. It also retains the tested latency/interruption logging, configurable speech settings, VoiceStudio wiring and greeting.
    `agent_local/` was removed after verification and deployment. The production source is `agent/`, which contains the Dockerfile,
    pytest suite and scripted-call tool. Public forks use their own ignored LiveKit deployment configuration.
  - Done: Python agent in `agent/` (40 pytest tests pass), sandbox-ID settings, `VoiceBackend`, `LiveKitVoiceBackend`, the complete
    `AgentVoiceScreen`, `openVoice()` routing, mute/restart/close controls, transcript hand-off into chat, platform permissions,
    recoverable call retries, widget/flow tests, and macOS/Android compilation with the WebRTC plugin. An application-owned
    HTTPS token endpoint can be configured for production and takes precedence over the development sandbox ID.
  - **Live setup:** the maintainer verified `cryonis-agent` in a private LiveKit Cloud project. Public configuration is
    `agent/livekit.toml.example`; each contributor copies it to the ignored `agent/livekit.toml` and uses their own project and token server.
  - **Verified with a scripted client** joining a real call (macOS `say` as the caller): agent joins, greets, speech-to-text heard
    "What is the capital of France?" exactly, `beam` (the voice model at that time) answered "The capital of France is Paris.", spoken reply came back. The app itself
    has started real calls from the Mac and from the A142 phone (the agent's log shows the sessions and their timings); how they
    sounded has not been reported.
  - **Latency measured and the voice model tuned** (27 Oct 2026): the deployed `agent/` logs per-turn timings and uses `gpt-oss:120b`
    (see "Voice model" and Known Limits). **Runs on an Android phone** (A142, Android 16, debug build): the app launches, a live call
    connects and Cryo's greeting arrives.
  - **English + Hindi, noise filter, interruption logging** (27 Oct – 2 Nov 2026): the agent speaks and understands English and Hindi
    (STT `multi`), applies LiveKit's background-noise filter by default (`NOISE_CANCELLATION=nc`), and logs
    per-turn timings and how fast it stops when interrupted. Background *chatter* (voice-like) still cuts the agent off; that is unsolved (see Known Limits and
    `agent/README.md`).
  - Still to do: a deployed production token endpoint, and a by-ear call test with a real voice (quality, barge-in, reconnect, and
    how often speech-to-text mis-hears; see Known Limits).
- Name origin: fictional icy planet name (Cryonis), chosen from a planet-name shortlist
- Assistant name shown in status lines: **Cryo** (the design says "Aira"); one constant, `assistantName` in `lib/app_config.dart`

## History so far (oldest first)
- **Before 26 Oct 2026 — text chat.** Design from the first Dribbble shot (an orange aurora look); Ollama Cloud chat with an API key and a
  free-models-only picker, local Ollama as the secondary path; ChatGPT/Claude/Gemini-style Markdown and code answers; image prompts,
  secure key storage, conversation persistence; run on the Mac, with a native integration test.
- **26 Oct — voice agent.** Chose LiveKit (hosted; nothing local). VoiceStudio was evaluated and left off (not hosted). Wrote the Python
  agent and deployed it to LiveKit Cloud (`cryonis-agent`); built `VoiceBackend`, `LiveKitVoiceBackend` and the call screen;
  verified the whole pipeline with a scripted caller; fixed a silent greeting (`beam` returns nothing for a prompt without a user
  message) by speaking the greeting directly; wrote `BUILD_GUIDE.md`.
- **27 Oct — tuning, languages, phone.** Added per-turn latency logging; changed the voice model `beam` → `gpt-oss:120b` after interleaved
  tests; made the speech language configurable (`multi` kept for English + Hindi; a fixed `en-IN` broke Hindi); first run on the A142.
- **2 Nov — noise, interruptions, UI.** Added the noise filter and server-side interruption timing; measured chatter (still unsolved) and
  corrected earlier numbers that were artifacts of my own test script; reinstalled on the phone; restyled the whole app to the Lumix
  shot (`UI_SPEC.md`); gave the voice ring a motion per phase; updated tests and docs.
- **2 Nov (evening) — the user's own agent code, deployed.** The user pasted a final agent of their own (Hindi TTS, `inference.TTS`, table-pipe
  filter, BVC noise filter). It was reviewed against LiveKit 1.8.9, then made deploy-ready in `agent_local/` (agent name, prewarmed VAD,
  hosted turn detector, consistent English + Hindi settings, a stronger streaming-safe table filter, Dockerfile, offline checks). At deploy
  time the LiveKit project turned out to have **no agent at all**, so `cryonis-agent` was created fresh. A scripted
  call by name and then a real call from the A142 reached it and worked. The earlier agent (`agent/`) was kept in the repo.
- **3 Nov — agent consolidation.** Merged the bilingual TTS and streaming table cleanup into the tested, instrumented `agent/`, moved the
  deployment configuration and scripted-call tool there, verified a real hosted call with two English and one Hindi question, and removed
  the duplicate `agent_local/` tree. The maintainer-specific deployment file was later replaced publicly by an ignored local file and template.

## Design Reference (3 screens) — details and the motion timeline are in `UI_SPEC.md`
Theme: pure black canvas, warm charcoal surfaces (`#1D1D1C`, `#30302F`), a silver action gradient
(`#EEEEEA → #9C9C98`), Inter type (bundled variable font in `assets/fonts/`, SIL OFL), and a graphite→silver glow along
the bottom edge in voice mode. The palette was changed on 3 Nov 2026 from the supplied habit-tracker screenshot.

**Header on every screen (`AppHeader`):** menu (server settings; a back arrow on Chat) · `model ⌄` pill (`ModelChip`: the current Ollama
model, tap to change; "Add API key" when there is none) · avatar orb with a connection dot (green / amber / red, tap re-checks). It is
inert during a call and works without a `ChatController` above it (shows "Cryonis").

1. **Home**
   - "Previous conversations" chip plus one row for the saved conversation: title = its first message, right side = relative time
     (`utils/relative_time.dart`, from `ChatController.lastActivity`); tap resumes it. Hidden when there is no conversation.
   - Quick-action chips (Analyse, Summaries, Draft, Debug) that prefill the input and focus it; they never send anything.
   - "Ask anything" card (`HomeInputPanel`): `+` attaches images, silver mic square (→ voice; turns into send once there is text).
     `MicHero` flies the mic into the voice screen's round mic.
   - Not taken from the shot: its "Deep Search" and "Think" chips (nothing behind them in the backend).
2. **Voice** — two modes, chosen by `ChatController.voiceAgentConfigured` (is a LiveKit sandbox ID or token endpoint set?). Both share:
   a dotted ring (`DotRing`: ~2,000 square dots lit in a boiling ring; each phase of the agent's loop has its own motion: observe = breathing + outward ripples, orient = inward ripples while words arrive, decide = an orbiting comet arc while thinking, act = voice-driven outward ripples while speaking; see `UI_SPEC.md` §5), the caption
   "I'm Listening…" with dots that count up (`ListeningCaption`), `VoiceControls` (keyboard · mic with a pulsing halo · close) and
   `GlowBackdrop` (graphite while waiting, silver once anyone is speaking). When words arrive the ring contracts and moves up, the caption
   gives way to the latest turn, left-aligned, each new word fading grey→white (`WordRevealText`), with a small label under it
   ("Listening" / "Thinking" / "Speaking").
   - **Live voice agent (`AgentVoiceScreen`)**: keyboard or X = end voice mode and continue the completed transcript in chat; mic = mute
     (shows "Mic is muted"); a failure shows its message and a "Try again" button. An empty call simply returns home.
   - **On-device dictation (`VoiceScreen`)**: `speech_to_text`; the left button is "send" (it sends the text to the Ollama chat), "tap to
     start over" sits under the transcript. Free, nothing hosted, no spoken replies.
3. **Chat**
   - Header with a back arrow (this is how a chat is closed).
   - User messages: flat `#1A1A1A` bubble, right-aligned (max ~80 % wide), images above the text.
   - **AI answers are plain full-width Markdown, no bubble and no avatar header** (as in the shot): "Generating ✳"
     (`GenerateLoading`, an 8-ray `SparkSpinner`) sits under the text while it streams; copy / regenerate buttons appear under the
     finished answer (regenerate on the latest one only).
   - Markdown: headings, bold / italic / strikethrough, lists, block quotes (silver bar), tables (scroll sideways), links (open in the
     browser), inline code chips, horizontal rules. Code blocks: dark card with language label + Copy, syntax highlighting, sideways scroll;
     unfinished fences render while streaming. Text can be selected across messages; the list fades at the top and bottom edges.
   - Compact input (`ChatInputBar`): `+`, text, mic → send → stop; errors show a red notice with "Tap to retry".

How the design maps to Ollama (decisions):
- The header pill is the model switcher; the menu opens the "Ollama API" settings (API key, server address, LiveKit settings); the avatar
  is the connection check.
- Quick-action chips use general-purpose lead-ins ("Analyse ", "Summarise ", "Draft ", "Help me debug ").
- Both voice screens use the same look; only the left button and the status words differ.

## Technical Approach

### Ollama API (primary: Ollama Cloud + API key)
- Default server: `https://ollama.com` (`cloudOllamaUrl` in `lib/app_config.dart`), authenticated with `Authorization: Bearer <API key>`.
  - `POST /api/chat` with `stream: true` for token streaming (newline-delimited JSON, `message.content` per line, `done: true` at the end; errors arrive as `{"error": ...}`)
  - `GET /api/tags` lists models (public on the hosted API, so it does **not** validate the key; a bad key shows up on the first chat as 401)
  - OpenAI-compatible chat completions are at `https://ollama.com/v1` (used by the voice agent).
- **API key** can default from `lib/secrets.dart` (`ollamaApiKey`), which is **gitignored** so it isn't committed. A key typed into the
  in-app settings overrides it and is stored with `flutter_secure_storage` (Keychain/Keystore-backed); older plain-text
  `shared_preferences` values are migrated and removed after a successful secure write. The key is only sent to `https://` addresses.
  A key embedded in an app binary can still be extracted, so don't ship a real compiled key in a public release.
- **Free models only.** The hosted catalogue has 23 models but only 7 work on free usage credits, so with the cloud server the picker
  shows just these (`freeCloudModels`): `beam`, `gemma4:31b`, `gpt-oss:120b`, `gpt-oss:20b`, `nemotron-3-nano:30b`,
  `nemotron-3-super`, `nemotron-3-ultra`. This matches Ollama's "free usage credits" list and a probe of every model (others answer
  HTTP 402 "not included in your free usage"). Default chat model: first of `gpt-oss:120b`, `gpt-oss:20b`, `llama3.2:latest` available.
- Error mapping: 401 → "The server rejected the API key"; other HTTP errors show the server's own message; no key on the cloud
  server → a "Add your Ollama API key…" prompt without making a request.
- Each chat request sends a short system prompt + the whole conversation (errors excluded). Stopping a reply closes the HTTP client,
  which stops generation on the server. `OllamaService.chat` is built on a `StreamController` (not `async*`) so a request that fails
  after the listener cancelled is dropped instead of becoming an unhandled exception; connection errors include the underlying cause.
- User messages may include up to four PNG/JPG/WebP images (5 MB each), sent as Ollama base64 `images`. Stable conversation turns are
  serialized to preferences and restored across app launches; the home screen can resume them.

### Local Ollama (secondary, no key, all installed models shown)
- `http://<host>:11434`; pick "This Mac" in the settings. Host by target (`localOllamaUrl()`):
  | Target | Host |
  |---|---|
  | iOS simulator / macOS | `localhost` |
  | Android emulator | `10.0.2.2` |
  | Physical phone | Mac LAN IP, run Ollama with `OLLAMA_HOST=0.0.0.0` |
- Ollama 0.40.11 was installed on this Mac with `brew install ollama` (needed the Xcode license accepted for Xcode 27.1 first), and
  `llama3.2` was pulled. Start it with `ollama serve` (or `brew services start ollama`). Not needed for the primary path.

### Voice agent (LiveKit) — decisions

**Where this came from.** The user shared an earlier Claude chat (https://claude.ai/share/868bfdab-99ee-45f4-950a-0d067d5644c7). Gist:
a voice-agent interview question (cut latency from ~4 s to ~300 ms with a streaming pipeline, handle barge-in with VAD and noise
suppression, don't forget echo cancellation); Ollama only has REST streaming (no WebSocket, no audio); for live voice use WebRTC and
LiveKit (`livekit_client` + LiveKit Agents) with Ollama as the LLM through its OpenAI-compatible `/v1`; Ollama needs separate STT and
TTS; the user then said they want **LiveKit Cloud** and **don't want to run LiveKit or Ollama locally** (so: LiveKit Cloud hosts server
and agent, Ollama Cloud hosts the model). The chat also listed no-LiveKit alternatives (on-device `speech_to_text` + `flutter_tts`;
own WebSocket backend with `record`; Pipecat); the user chose LiveKit. Realistic cascaded latency is ~500–800 ms, not 300 ms.

**Architecture (all hosted):**
```
Flutter app (livekit_client Session)  ──WebRTC──►  LiveKit Cloud  ◄──►  agent/ (Python, deployed with `lk agent deploy`)
   mic + speaker + transcripts                  token endpoint             ├─ STT  LiveKit Inference · Deepgram nova-3 (multi)
                                                (app-owned or sandbox)      ├─ LLM  Ollama Cloud · OpenAI-compatible · gpt-oss:120b
                                                                            ├─ TTS  LiveKit Inference · Cartesia sonic-3
                                                                            └─ Silero VAD + LiveKit turn detector (barge-in)
```
- LiveKit handles VAD, turn detection, interruption (barge-in), and on-device echo cancellation / noise suppression (WebRTC). On top
  of that the agent asks LiveKit Cloud to filter the caller's microphone (Krisp background-noise suppression, `NOISE_CANCELLATION=nc`).
- **Voice model: `gpt-oss:120b`** (was `beam`). Time to first text token via `https://ollama.com/v1` with the agent's real system
  prompt, from India, requests interleaved: `gpt-oss:120b` median 0.75 s (20 requests, 0 failures in 38 over three tests), `beam`
  1.29 s (3 of 38 requests streamed reasoning but never text), `gpt-oss:20b` ~1.7 s, `nemotron-3-nano:30b` no text within the token
  budget (avoid), `gemma4:31b` **~10 s** (too slow for voice; also slow for text chat — avoid as a default). Medians move with server
  load, so gaps under ~0.3 s are noise; in the deployed agent the first-token median was 1.44 s (`gpt-oss:120b`, 5 calls) vs 1.58 s
  (`beam`, 8 calls). Override with `OLLAMA_MODEL` (keep it on the free list). The agent's instructions ask for short, spoken-style
  replies in English or Hindi, in the language the user speaks (a Hindi/English mix gets the same mix; any other language gets English).
- **Latency is logged per turn** by the deployed agent (`lk agent logs`): `user turn: transcript …, turn detection …` and
  `assistant turn: llm first token …, tts first audio …, total …` (`latency_line` in `agent/src/agent.py`), plus
  `interruption: agent stopped X s after the user started talking` (`InterruptionTimer`). The first line at the start of each call
  shows the active settings (`stt language …, noise cancellation …, interruption min words …`).
- **Agent settings** are secrets on the deployed agent; change them with `lk agent update-secrets --secrets KEY=VALUE` and **never
  `--overwrite`**: `STT_LANGUAGE` (default `multi`), `TTS_LANGUAGE` (`hi`), `TTS_VOICE`, `NOISE_CANCELLATION` (`nc` default, `off`, `bvc`),
  `INTERRUPTION_MIN_WORDS` (0 default), and `OLLAMA_MODEL`. Details: `agent/README.md`.
- **Client**: `livekit_client` 2.13.2's high-level `Session.withAgent(name, tokenSource: DevelopmentTokenSource(id: sandboxId))`: fetches a
  token, joins the room, dispatches the agent, publishes the mic (pre-connect audio buffers the first words while the agent joins), and
  exposes `agent.agentState` (initializing / listening / thinking / speaking, from the `lk.agent.state` attribute) and `messages`
  (live transcripts via the `lk.transcription` text stream). The app wraps it behind `VoiceBackend` so UI and tests don't need WebRTC.
- **Token server**: the sandbox token server (header `X-Sandbox-ID`, `https://cloud-api.livekit.io/api/v2/sandbox/connection-details`)
  is **development only and insecure**. The settings sheet also accepts an application-owned HTTPS token endpoint, which is preferred
  whenever configured. That service must authenticate the user; the LiveKit API secret must never be in the app.
- **Agent name**: `cryonis-agent` — must match `voiceAgentName` in `lib/app_config.dart` and `AGENT_NAME` in `agent/src/agent.py`.

**Free-tier reality (LiveKit Cloud "Build" plan, checked in LiveKit's docs):** $0, allowances are **hard caps** that reset on the 1st of
each month: 1,000 agent-session minutes, 5,000 WebRTC participant minutes, 50 GB transfer, and **$2.50 of LiveKit Inference credit**
(STT + TTS), which LiveKit's pricing page estimates at **~50 minutes of talking** — that credit is the binding limit. Free production
agents scale to zero: **10–20 s cold start** before the agent joins. Inference prices: Deepgram nova-3 multilingual $0.0058/min;
Cartesia sonic-3 $50 per 1M characters; cheaper options exist (AssemblyAI / Inworld STT ~$0.0025/min; Inworld TTS $15 per 1M chars)
but their Hindi quality and exact model IDs were not verified. Ollama free usage allows one request at a time.

**VoiceStudio (https://github.com/debpalash/VoiceStudio) — evaluated, OFF by default.** The user asked to use it "for voice". It is an
open-source (AGPL-3.0), local-first desktop app (Electron + Python backend) for TTS, voice cloning/design, dubbing and transcription.
It is a *speech provider*, not a voice agent: its own docs say the agent framework (LiveKit, Pipecat) runs the loop and calls it. It
exposes OpenAI-compatible endpoints on `http://127.0.0.1:3900`: `POST /v1/audio/speech` (TTS, `stream_format` audio|sse),
`POST /v1/audio/transcriptions`, `WS /v1/audio/transcriptions/stream`, `GET /v1/models`, `GET /v1/audio/voices`. No latency numbers are
published (benchmarks table is empty). It is **not a hosted service**: it must run on a machine you control (your Mac, or a GPU server
you pay for, reached over Tailscale; docs say not to expose it publicly), so an agent hosted on LiveKit Cloud cannot reach a Mac's
`localhost`. That conflicts with "run nothing locally", so the default speech engine stays LiveKit Inference. The agent has a switch:
`SPEECH_PROVIDER=voicestudio` (+ `VOICESTUDIO_URL`, `VOICESTUDIO_API_KEY`, `VOICESTUDIO_TTS_MODEL`, `VOICESTUDIO_TTS_VOICE`,
`VOICESTUDIO_STT_MODEL`, `VOICESTUDIO_TTS_FORMAT=wav`) which wires `openai.TTS` / `openai.STT` at its `/v1`. **That path is unit-tested for
wiring only and untried against a real VoiceStudio** (not installed; its installer is `curl | sh`, which was deliberately not run). To
use it, run the agent on the same Mac (`uv run src/agent.py dev`) instead of deploying it. Model/voice names are guesses until checked
against the server's `/v1/models` and `/v1/audio/voices`.

**LiveKit setup — DONE on 26 Oct 2026 (kept as the recipe for a fresh machine/project):**
1. Create a free LiveKit Cloud account and project (https://cloud.livekit.io). *(done: project `cryonis`)*
2. `brew install livekit-cli`, then `lk cloud auth` — it must run in an interactive terminal (it asks for a device name, then a
   browser approval; `--yes` does not work). *(done)*
3. `cd agent`, copy `livekit.toml.example` to the ignored `livekit.toml`, put `OLLAMA_API_KEY=<key>` in `.env.local`, then
   run `lk agent create --secrets-file .env.local .` and select a region near the intended users. Updates: `lk agent deploy`
   (updates the same agent; secrets persist). Logs: `lk agent logs` (streams; stop it with Ctrl-C). Status: `lk agent status`.
4. In the project's Settings switch on **Development token server**, copy the **Token server ID** (`cryonis-…`). It goes in the app's
   settings sheet (section "Live voice calls (LiveKit)" — low down, scroll inside the sheet) or in `lib/secrets.dart`
   (`livekitSandboxId`, used here). Without it the voice screen stays in on-device dictation mode. *(done)*
- The free Build plan allows **one deployed agent** (dashboard shows 1/1): `lk agent create` can't be run a second time; redeploy
  with `lk agent deploy`. Other free limits seen on the dashboard: 5 concurrent agent sessions, 100 concurrent participants.
- Testing without clicking: a Python client (`livekit` rtc, in `agent/.venv`) can request a token from the token server (needs a
  non-default `User-Agent`, otherwise Cloudflare answers 403 error 1010), join a room with `room_config.agents=[{agent_name}]`,
  publish speech synthesised with macOS `say` + `afconvert`, and read `lk.agent.state` and the `lk.transcription` text stream.

### Packages
- `http` — streaming HTTP (a fresh client per chat request so it can be aborted)
- `speech_to_text` — on-device voice input for the dictation mode (Ollama has no voice; the transcript is sent as a normal text message)
- `livekit_client` 2.13.2 (brings `flutter_webrtc` 1.6.3) — the live voice call
- `shared_preferences` — saved server address, selected model, conversation, LiveKit endpoint, and sandbox ID
- `flutter_secure_storage` — Ollama API-key storage with migration from the former preferences value
- `file_selector` — PNG/JPG/WebP image prompts (up to four images, 5 MB each)
- `flutter_markdown_plus` (+ `markdown`) — answer rendering (the original `flutter_markdown` is discontinued); `flutter_highlight` —
  code syntax highlighting; `url_launcher` — opening links
- No state-management package: a `ChatController` (`ChangeNotifier`) shared through an `InheritedNotifier` (`ChatScope`)
- Python agent (`agent/`, managed with `uv`, Python 3.12): `livekit-agents[openai,silero]` 1.8.9, `python-dotenv`; dev: `pytest`,
  `pytest-asyncio`. Turn detection uses `inference.TurnDetector()` (the old `livekit.plugins.turn_detector` is deprecated).

### Platform config
- Added: iOS mic + speech + local-network usage strings, `NSAllowsLocalNetworking`; Android `INTERNET`, `RECORD_AUDIO`, Bluetooth perms,
  `usesCleartextTraffic`, speech `<queries>`, `https` VIEW `<queries>`; macOS mic + speech usage strings and sandbox entitlements
  `network.client` + `audio-input` (Debug + Release). Deployment targets: iOS 15, macOS 12 (both fine for WebRTC).
- LiveKit/WebRTC additions are present: Android `MODIFY_AUDIO_SETTINGS`, `ACCESS_NETWORK_STATE`, `CHANGE_NETWORK_STATE`, and iOS
  `NSCameraUsageDescription` (not used at runtime, but the WebRTC SDK references camera APIs).
- Android, iOS, and macOS use `com.rupeshjadhav.cryonis`. Android release signing reads an ignored `android/key.properties` when
  present; `android/key.properties.example` documents the required values. Real signing credentials are still required for release.
- macOS uses the OS-protected legacy Keychain mode, which does not need Keychain Sharing or a provisioning profile. iOS declares
  Keychain Sharing because iOS builds are provisioned normally.

### Structure
```
lib/
  main.dart               # app + ChatScope + initial model refresh
  app_config.dart         # assistantName, system prompt, cloud/local URLs, preferred + free model lists, voiceAgentName
  secrets.dart            # Ollama API key + livekitSandboxId (gitignored)
  theme/app_theme.dart    # colors, gradients, text styles, ThemeData
  models/chat_message.dart
  services/
    api_key_store.dart   # secure API-key storage and legacy migration
    image_attachment_picker.dart # validated image selection and base64 encoding
    ollama_service.dart   # chat streaming, model listing, API key header, error mapping
    speech_service.dart   # speech_to_text wrapper (level normalising)
    voice_backend.dart    # VoiceBackend interface, VoiceLine, AgentPhase, conversationFrom()
    livekit_voice_backend.dart  # LiveKit Session wrapper (state, transcripts, mic, audio level)
  state/
    chat_controller.dart  # conversation, models (free filter), connection, stream lifecycle, LiveKit sandbox ID, addConversation()
    chat_scope.dart
  screens/
    home_screen.dart
    voice_screen.dart     # on-device dictation; pops with the transcript on send
    chat_screen.dart
    routes.dart           # fade transition
    agent_voice_screen.dart  # live LiveKit call UI (ring, caption / transcript, controls, glow; same call logic as before)
    voice_flow.dart          # openVoice(): picks live call vs dictation, returns VoiceOutcome
  utils/relative_time.dart  # "Just now", "7h ago", "Yesterday", "3d ago", "12 Oct"
  widgets/
    app_scaffold.dart     # black screen, phone-width column on wide windows, keyboard inset, optional full-bleed backdrop
    app_header.dart       # menu / model pill / avatar (+ optional back arrow); works without a ChatController
    glow_backdrop.dart    # GlowBackdrop: the bottom glow (profile measured from the design), glides between colours
    dot_ring.dart         # DotRing: the voice visual, moods connecting / listening / thinking / speaking / muted
    voice_widgets.dart    # AccentMic + MicHero, VoiceControls, ListeningCaption, WordRevealText, SparkSpinner, GenerateLoading
    planet_orb.dart       # animated orb, used as the avatar
    chat_bubble.dart      # flat user bubble, plain assistant answer + actions, error notice, "Generating" row
    markdown_view.dart    # Markdown styling + code-block builder
    code_block.dart       # highlighted code card with Copy
    copy_button.dart      # copy-to-clipboard with "Copied" tick
    input_bar.dart        # "Ask anything" card, compact chat input, mic / send / stop
    sheets.dart           # model pill (ModelChip), model picker, API key + server settings
test/
  fake_ollama.dart        # in-memory Ollama (MockClient) used by all tests
  ollama_service_test.dart, chat_controller_test.dart, markdown_view_test.dart,
  agent_voice_screen_test.dart, voice_flow_test.dart, api_key_store_test.dart,
  chat_message_test.dart, image_attachment_picker_test.dart, widget_test.dart, voice_widgets_test.dart, app_header_test.dart,
  last_activity_test.dart, utils/relative_time_test.dart, app_licenses_test.dart   (104 tests at last full run)
integration_test/
  native_chat_test.dart   # real chat inside the macOS app; spends a little free quota
  voice_ui_preview_test.dart  # renders Home, Chat and the voice screen in every state to PNGs in the app container (no network, no key)
agent/                    # deployed and unit-tested voice agent; not part of the Flutter build
  src/agent.py            # AgentServer + AgentSession: STT / LLM (Ollama Cloud) / TTS / VAD / turn detection; SpeechSettings (language, noise
                          # filter, interruption words, VoiceStudio switch); latency + interruption logging
  tests/test_agent.py     # 40 tests: LLM/TTS wiring, bilingual prompt, table cleanup, settings, noise filter, interruption and latency
  tools/call_agent.py     # joins by agent name like the app and speaks tools/questions.json with macOS `say`
  pyproject.toml, uv.lock, Dockerfile, .dockerignore, .env.example, README.md   (README has the deploy steps and the settings)
assets/fonts/             # Inter variable font + its licence text
README.md                 # how to run, set up, test
PROJECT_CONTEXT.md        # this file: decisions, numbers, history
PROJECT_STATUS.md         # verified checklist and remaining work
PROJECT_IMPROVEMENTS.md   # prioritized engineering backlog and completion status
BUILD_GUIDE.md            # step-by-step walkthrough of how it was built
UI_SPEC.md                # the design analysis (colours, type, motion timeline, ring phases)
```
Run the Flutter tests with `flutter test`; the agent tests with `cd agent && uv run pytest`. Run the native chat with
`flutter test integration_test/native_chat_test.dart -d macos` (stop any running copy of the app first). It prints the model, the
answer and the paths of two PNGs written to the app's container (`~/Library/Containers/com.rupeshjadhav.cryonis/Data/tmp/`).

## Known Limits

The actionable engineering backlog is maintained in `PROJECT_IMPROVEMENTS.md`. As of 3 November 2026, the duplicate production/test agent issue, stale verification documentation and local Git baseline are resolved. A remote repository is not configured yet. The highest-priority code work is file-based image persistence, serialized conversation writes, production LiveKit authentication, scoped Android cleartext access, and final-transcript shutdown ordering.

- **Voice latency is ~1.4–2 s inside the agent, ~3–4 s as the scripted client hears it — not 300 ms.** The agent's own per-turn log
  (27 Oct 2026, 13 test turns) shows where time goes: transcript ~0.2 s, turn detection ~0.6 s (overlaps the model call because
  preemptive generation is on, so lowering it gains nothing), **model first token 0.9–3.2 s (the main cost)**, voice first audio
  ~0.1 s. Totals: `beam` 1.4–3.5 s (median 2.0 s, 8 turns), `gpt-oss:120b` 1.4–2.0 s (median 1.9 s, 5 turns). The scripted client
  (end of its speech → first audible audio) measured 3.0–5.0 s; that includes network, audio buffering and its own sending buffer,
  which is not exactly comparable. Remaining levers: a model that thinks less, a region closer to Ollama's servers, an STT with
  built-in turn detection. Bluetooth earbuds (the Mac picked "CMF Buds Pro 2") drop to low-quality call audio and add delay, so test
  with the built-in mic/speakers or wired headphones.
- **Speech-to-text sometimes mis-hears English (about 1 utterance in 6 in synthetic-voice tests).** The scripted caller uses macOS
  `say` voices (Rishi/Tara en-IN, Samantha en-US, Lekha hi-IN). With `STT_LANGUAGE=multi` (Deepgram nova-3, the default) 5 of 23
  English utterances were wrong: "…in a leap year" heard as "…in Alipay", "Romeo and Juliet" heard as "Min Duliet" or as Bengali
  script (the agent then answered in Bengali), and one nonsense string for "What is the capital of France?". A fixed `en-IN` was
  tried (27 Oct 2026): 1 of 7 English wrong (the same "Alipia" slip), so no measurable gain, and it **broke Hindi** (answers came
  back in Latin letters, "Taj Mahal | Mahal", one question heard as nothing) — so `multi` stays. Hindi under `multi` was exact for all 5
  pure-Hindi questions; the mixed "मुझे Moon के बारे में…" heard "Moon" as "मुंह" (mouth). These are synthetic voices; a real
  human voice may do better or worse, not yet checked. If it persists with real speech, try another STT model/provider (e.g. the
  `deepgram/flux-general-multi` model with language hints) and compare. `STT_LANGUAGE` is read from the agent's secrets; change it with
  `lk agent update-secrets --secrets STT_LANGUAGE=<code>` (no rebuild; do **not** add `--overwrite`, it wipes the other secrets).
  **Spoken Hindi** was checked by round trip: Cryo's Hindi answer (12 s of audio) replayed to the speech-to-text came back as nearly the
  same sentences (a few rare words slipped), so it is intelligible; naturalness is not judged.
- **Voice-like background chatter still cuts the agent off mid-answer (unsolved).** Server log, 27 Oct – 2 Nov 2026, synthetic voices:
  a clear "Stop." stopped the agent **0.19 s** after the caller started; 4 s of traffic-like rumble did **not** interrupt it (filter on or
  off); 5 s of four voices talking at once interrupted it **0.40 s** after it began (with the `nc` filter on) and the agent never resumed.
  With `nc` on the speech-to-text transcribed no chatter words; with it off one run transcribed "I have tried" and the agent answered
  "I didn't catch that" — one observation, not proof the filter helps. `INTERRUPTION_MIN_WORDS=1` did **not** fix it (chatter still
  interrupted, at 0.81 s) and made real interruptions slower (0.19 → 0.52 s; the user's own phone calls logged 1.18 s and 2.68 s while it
  was on), so it stays 0. The remaining candidate is `NOISE_CANCELLATION=bvc` (voice isolation): billed extra, **untested, needs the
  user's OK before it is enabled**. This is the gap versus the interview-video concept (streaming pipeline, VAD + noise suppression +
  barge-in): the architecture matches, latency is ~1.4–2 s rather than 300 ms, and chatter-triggered false interruptions remain.
- **Corrected earlier claims:** "the agent takes ~1.6 s to stop when interrupted" and "chatter silences the agent at once" were artifacts
  of my test script (it blocked the event loop synthesising audio with `say` mid-call, and its mic source queued ~1 s of silence ahead of
  the speech, shifting every client-side offset by about a second). Trust the server log lines, not client-measured offsets.
- **Model quirk found in testing:** `beam` returns an **empty reply** when a prompt has no user message (e.g. a lone "greet the user"
  instruction). The agent therefore speaks its greeting with `session.say(GREETING)` instead of asking the LLM. Remember this for
  any agent-initiated turn. `beam` also sometimes streams only reasoning chunks and no text, which is one reason the voice model
  moved to `gpt-oss:120b`.
- **Voice not yet checked by ear in the app** (audio quality, barge-in, reconnect): the user made real calls from the A142 (the earlier
  agent's log shows turns of 0.9–2.6 s total; on 2 Nov a call started from the app reached the new agent in ~1.5 s and transcribed speech),
  but nothing has been reported about how it sounded; the browser pane blocks the mic and no tool here can click in the native window.
- **Free LiveKit quota ≈ 50 minutes of talking per month** (the $2.50 inference credit), hard-capped, plus a 10–20 s cold start for the
  first call after idle. The app does not show the remaining quota.
- **Sandbox token server is dev-only and insecure**; the client supports a production HTTPS endpoint, but that authenticated service
  must still be deployed and configured before release.
- **VoiceStudio path is wiring-only** (see above); AGPL-3.0 and separate model-weight licences apply if it is ever hosted or shipped.
- **Desktop/mobile verification is incomplete:** macOS and Android debug builds succeed, and the Android debug build was run on a
  physical A142 (Android 16, wireless debugging) on 27 Oct and again on 2 Nov 2026 with the new UI (Home, a live call opening, Chat);
  the user has also made real calls. Not tried: a release build, a long call, reconnecting after a network change. Signed production builds still require signing credentials. The iOS simulator is unavailable here ("CoreSimulator is out of date"
  for Xcode 27.1); a phone named "Shubham's iPhone" appears in `flutter devices` but is not the user's and was not touched.
- **Native window not driven by hand:** the native check is the integration test (real chat on `gpt-oss:120b` via Ollama Cloud, home +
  chat renders reviewed). Re-run on 26 Oct 2026 after the secure-storage / bundle-id / image / persistence changes: it passed on the
  `com.rupeshjadhav.cryonis` build, along with `dart analyze . --fatal-infos`, 69 Flutter tests and 9 agent tests. Mouse/keyboard feel
  and window resizing were not tried.
- **No web support for Ollama Cloud:** `https://ollama.com` answers the browser CORS preflight with 405, so a web build cannot reach it.
  Local Ollama works from a web build on a localhost origin.
- **On-device dictation voice is untested live** (mic blocked in the browser pane); its idle layout was checked.
- Image attachments require a vision-capable Ollama model. The app validates type/count/size but cannot guarantee the selected model
  understands images.
- No LaTeX / math rendering, no images in answers, and the model's reasoning ("thinking") is not shown: thinking models (e.g. `gpt-oss`)
  stream a hidden reasoning phase first, during which the answer area shows "Generating ✳".
- Long code lines scroll sideways inside the code card instead of wrapping.
- Widget tests need `tester.runAsync` to let a stream finish (the fake clock never delivers a stream's "done" event).
- Free Ollama usage has limits; the app doesn't show remaining quota.
- The chat model picker remembers the last choice; on the user's phone it is `gemma4:31b`, whose first token takes ~10 s. The default
  (`gpt-oss:120b`) is far quicker.
- Git: the earlier local history (initial baseline `9459b47` plus two commits, never pushed) was moved out of the project on 3 Nov 2026 so the code can go to a different GitHub account. A new repository was created the same day with the new account's identity set for this project only (the machine's global identity is unchanged) and one fresh first commit. `origin` is the private `jadhavrupesh/cryonis` repository on GitHub, reached over SSH with a dedicated key that the project's own Git config selects (this machine's stored HTTPS login belongs to a different account, so plain HTTPS pushes would use the wrong one). `main` was pushed on 3 Nov 2026. The first Gitleaks secret scan passed; CI had not finished when GitHub Actions was switched off in the repository settings at the maintainer's request. The workflows and `dependabot.yml` were then deleted from the repository (3 Nov 2026; they stay in the history, commit `c02d8ad`), and the three pull requests Dependabot had already opened were closed and its branches deleted. There is no automated CI/CD now; checks run locally.

## Working notes (how things are run here)
- **Phone:** over USB `flutter devices` lists the A142 by its serial (`flutter run -d <serial>`); over Wireless debugging it is
  `adb-<serial>-<id> (2)._adb-tls-connect._tcp` and must be quoted. Wireless debugging drops when the phone changes network (`adb devices
  -l` empty → re-enable it or plug in). Uninstalling wipes the app's chats and settings.
  Don't send adb taps while the user is using the phone.
- **Mac native renders:** `flutter test integration_test/voice_ui_preview_test.dart -d macos` (about 35 s once the Swift packages are resolved).
- **Agent:** `lk agent deploy | status | secrets | logs | update-secrets | list` from `agent/` (the ignored `livekit.toml` holds the fork owner's agent ID).
  If calls hang on "Connecting…", run `lk agent list`: on 2 Nov the agent had vanished from the project (cause unknown). `lk agent logs` only shows what it has buffered;
  macOS has no `timeout`, so a bounded recording is `perl -e 'alarm 120; exec @ARGV' lk agent logs > file &`. In the log, rooms named
  `cryonis-test-<epoch>` are scripted test calls and `sbx-…` rooms are calls from the app.
- **Scripted callers** (macOS `say` voices speaking to the deployed agent): the plain "ask questions, print what it heard and said" one is
  saved as `agent/tools/call_agent.py`. The barge-in / chatter test and the spoken-reply round-trip checker used for the earlier
  measurements are still only in the session's scratch folder (not in the repo).
- **Cost:** every test call spends part of LiveKit's ~50-minute monthly inference credit; keep calls short and batch questions into one call.
- **Measuring:** trust the agent's own log lines, not client-measured offsets (see the corrected claims under Known Limits).

## Open Questions
- Is ~50 free voice minutes a month enough, or should the agent use cheaper hosted STT/TTS (needs a Hindi-quality check)?
- Will VoiceStudio be used later (needs a machine to run on and the agent run locally, or a paid GPU server)?
- Test device: iOS simulator, Android emulator, or physical phone? (The A142 phone is what has been used.)
- Keep the assistant name "Cryo" or use "Aira" from the design?

## Next Steps
1. Try live calls on the Android phone with the deployed agent and the new UI: watch the four ring phases (listening, words arriving,
   thinking, speaking), speak English, Hindi and a mix, interrupt Cryo mid-answer, and try it with a TV or other voices nearby. Note the
   audio quality, how natural the Hindi voice sounds (including English replies under `TTS_LANGUAGE=hi`; `en` is a one-line secret change),
   and how often speech-to-text mis-hears real speech (see Known Limits).
2. On the phone, also look at the settings sheets and the Chat in the new colours, and compare the transitions with the Lumix shot.
3. If chatter still cuts Cryo off, decide whether to try `NOISE_CANCELLATION=bvc` (voice isolation, billed extra, needs the user's OK).
4. Deploy and configure the authenticated production token endpoint; keep provider secrets out of distributed clients.
5. Fix the local Xcode/CoreSimulator mismatch and run iOS (Android already runs on the A142).
6. Add real release signing credentials/store metadata and keep the local checks (analysis and tests) green.
7. Move the barge-in / chatter and round-trip test scripts from the scratch folder into the repo if repeated measurements are wanted; make the
   first commit when the user is ready (nothing is committed yet).
8. Track feature work and current verification in `PROJECT_STATUS.md`; this file remains the architectural record.
