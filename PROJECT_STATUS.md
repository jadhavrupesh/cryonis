# Cryonis Project Status

**Snapshot date:** 3 November 2026
**Overall status:** Repository-controlled MVP work is complete and validated. The remaining blockers require external accounts, signing credentials, or real devices.

## Verified status

| Area | Status | Evidence |
|---|---|---|
| Strict Dart analysis | Done | `dart analyze . --fatal-infos` passes |
| Flutter tests | Done | 159 tests pass |
| Python voice-agent tests | Done | 40 tests pass (settings, language, TTS, table cleanup, noise filter, interruption timing, latency logging) |
| macOS debug build | Done | `flutter build macos --debug` succeeds |
| Android debug build | Done | `flutter build apk --debug` succeeds |
| CI/CD | Removed | The GitHub Actions workflows and the Dependabot configuration were deleted on 3 November 2026 at the maintainer's request; they stay in the Git history (commit `c02d8ad`). Analysis, tests and builds are run locally |
| Git | Pushed, private | The earlier local history (initial commit `9459b47` and two later commits, no remote) was moved out of the project on 3 November 2026 so the code can be pushed to a different account. A new repository with one fresh first commit (new account's identity, set for this project only) was pushed on 3 November 2026 to the private `jadhavrupesh/cryonis` repository over SSH, using a dedicated key. The first remote runs started on that push: the Gitleaks secret scan passed; CI had not finished when GitHub Actions was switched off, and the workflows and Dependabot configuration were then removed at the maintainer's request (3 November 2026). The three pull requests Dependabot had opened were closed and its branches deleted |
| Text chat | Done | Streaming, history, stop, retry, regeneration, errors, and connection timeout |
| Markdown/code UI | Done | Rich Markdown, highlighted code, copy, links, tables, and streaming fences |
| Conversation persistence | Done | Conversations, their last-activity time and attached images survive restarts; Home lists the conversation under "Previous conversations" |
| UI restyle + monochrome theme | Done, phone-checked | Lumix layout with the supplied habit-tracker grayscale palette across Home, Chat, both voice screens, header, sheets, Markdown and the avatar; analysis in `UI_SPEC.md`; Home and a live voice call checked on the A142 |
| Voice animation per phase | Done, partly checked | Observe / Orient / Decide / Act each has its own ring motion (breathing + outward ripples, inward ripples, orbiting comet arc, voice-driven ripples); motion maths unit-tested, rendered offscreen; not yet watched live on the phone |
| Image prompts | Done | PNG/JPEG/WebP, preview/removal, maximum 4 images and 5 MB each |
| API-key storage | Done | Secure platform storage, safe legacy migration, no bundled key in release |
| LiveKit client UI | Done in code | State, transcript, mute, retry, restart, and automatic voice-to-text hand-off when the call is ended are tested |
| Production token client | Done in code | Validated application-owned HTTPS endpoint is preferred over sandbox |
| Python voice agent | Done in code | STT, Ollama LLM, TTS, VAD, turn detection, Docker, and deployment docs |
| Hosted voice agent | Done | `agent/` is the single deployed and tested implementation: English + Hindi, `gpt-oss:120b`, Hindi/Hinglish voice, free noise filter, table cleanup, latency/interruption logs and greeting. A real scripted hosted call heard and correctly answered two English questions and one Hindi question. Public configuration now uses contributor-owned LiveKit projects. Not yet: a by-ear call |
| Voice latency | Measured | The deployed `agent/` logs per-turn timings. The model's first token is the main cost (~1.4 s of ~1.9 s); see `PROJECT_CONTEXT.md` |
| English + Hindi voice | Done in the agent | Speech recognition is `multi` (English, Hindi, mixes); replies in the user's language. Spoken Hindi was checked by round trip (the audio transcribes back to nearly the same sentences); naturalness not judged by ear |
| Voice transcription accuracy | Open | Synthetic-voice tests: `multi` mis-heard 5 of 23 English utterances; a fixed `en-IN` did not help (1 of 7) and broke Hindi, so `multi` stays. `STT_LANGUAGE` is configurable. Needs a check with a real voice |
| Noise filter + interruptions | Partly | `NOISE_CANCELLATION=nc` is on by default. A clear "Stop." stopped the instrumented agent 0.19 s after the caller started; traffic-like rumble did not interrupt it. **Voice-like chatter still cuts it off**. Candidate: `bvc` voice isolation (billed extra, untested, needs the user's OK) |
| Real voice call by ear | Pending | Audio quality, barge-in, reconnect and hand-off still need a person listening (the user has made calls from the A142; no feedback yet) |
| Android device run | Done | Debug build on an A142 (Android 16): home renders, live calls connect, the greeting arrives; the user has also made calls from it |
| iOS run | Blocked locally | Installed CoreSimulator is incompatible with the installed Xcode |
| Signed store builds | Blocked externally | Requires Android keystore and Apple signing/provisioning credentials |

## Completed work

### Application and chat

- Home, chat, dictation, and LiveKit voice screens are implemented.
- Ollama Cloud and local Ollama are configurable.
- Cloud API keys are sent only over HTTPS.
- User-entered Ollama keys use Keychain/Keystore-backed storage.
- An older plain-text preference is migrated only after the secure write succeeds.
- `lib/secrets.dart` is allowed as a development fallback but is ignored in release builds.
- Model discovery, free-cloud filtering, selection, and connection status are implemented.
- Chat requests have a connection timeout while preserving long-running response streams.
- Conversations are JSON-serialized, restored safely, and resumable from Home.
- Corrupt persisted records are skipped without hiding valid history.

### Images and rendering

- The attach buttons now select PNG, JPEG, or WebP images.
- Users can preview and remove attachments before sending.
- Ollama receives base64 image data through its `images` message field.
- Image prompts render in user messages and persist with conversation history.
- Markdown headings, lists, quotes, tables, links, inline code, fenced code, syntax highlighting, selection, and copy actions are implemented.

### Voice

- On-device dictation remains the fallback when LiveKit is not configured.
- The LiveKit client supports connecting, listening, thinking, speaking, mute, transcript, restart, and voice-to-text continuation. Ending a completed call always opens its transcript in text chat.
- Start, microphone, end, retry, and disposal failures are guarded from becoming unhandled asynchronous errors.
- Failed calls show a visible retry action.
- Repeated start/end/dispose operations are idempotent.
- The settings sheet accepts an application-owned HTTPS production token endpoint.
- Production endpoints reject insecure HTTP, URL credentials, fragments, and malformed URLs.
- A development sandbox ID remains available for non-production testing.
- The Python agent implements English + Hindi STT, Ollama Cloud (`gpt-oss:120b`), TTS, VAD, turn detection, barge-in, a LiveKit background-noise filter, per-turn latency and interruption logging, and a VoiceStudio-compatible optional path.

### Release engineering

- Application/bundle ID is `com.rupeshjadhav.cryonis` on Android, Apple, and Linux targets.
- Android release signing reads ignored values from `android/key.properties`; an example file is included.
- iOS Keychain entitlement configuration is present.
- macOS secure storage uses the OS Keychain without requiring Keychain Sharing/provisioning for debug builds.
- macOS dependencies use Swift Package Manager; obsolete CocoaPods integration was removed.
- Static analysis enables strict casts, strict inference, and strict raw types.
- Root and agent documentation describe setup, testing, security, and deployment.
- The checks need no provider credentials: an empty, ignored `lib/secrets.dart` is enough.

## Remaining external work

### Required to finish the voice MVP

- [x] Create or select a LiveKit Cloud project (`cryonis`).
- [x] Authenticate the LiveKit CLI and deploy `agent/` (`cryonis-agent`) to a maintainer-owned project.
- [x] Put the Ollama key into the deployed agent's secret configuration.
- [x] Enable the development token server temporarily (done; an authenticated production endpoint is still required for release).
- [ ] Complete a real macOS voice call.
- [ ] Verify microphone permission, speaker output, transcripts, interruption/barge-in, reconnect, and voice-to-chat hand-off.
- [ ] Measure response latency and verify Hindi, English, and mixed-language quality.
- [ ] Install the Android APK on an emulator or phone and repeat chat/audio checks.
- [ ] Update macOS/Xcode/CoreSimulator, then build and run the iOS target.

### Required for production distribution

- [ ] Implement and deploy an authenticated LiveKit token service. The Flutter endpoint client is ready, but the service must use the product's real user-auth system.
- [ ] Supply the Android upload keystore and `android/key.properties`.
- [ ] Confirm the Apple development team, signing identities, provisioning profiles, and store entitlements.
- [ ] Provide store listing data, screenshots, privacy disclosures, support URL, and release policy.
- [ ] Decide whether provider credentials remain user-supplied or are protected behind an authenticated backend.
- [ ] Run the real Ollama integration test with an account key; it consumes external quota and was intentionally not run here.

## Optional future enhancements

- [ ] Math/LaTeX and rich image rendering in assistant answers.
- [ ] Visible model reasoning for thinking models.
- [ ] Ollama/LiveKit quota display where provider APIs allow it.
- [ ] Localization, accessibility audit, keyboard navigation, and screen-reader verification.
- [ ] Privacy-reviewed analytics and crash reporting.
- [ ] A backend proxy if Ollama Cloud web support is required.
- [ ] Dynamic discovery or a maintenance process for the hard-coded free-model list.
- [ ] Evaluate alternative speech providers after real latency, quality, and cost measurements.

## Known environment warnings

- The installed CoreSimulator framework is older than the installed Xcode; macOS builds still pass, but iOS simulator support is disabled until the Apple toolchain is updated.
- `livekit_client` / `flutter_webrtc` currently emit a future Flutter/Kotlin-plugin compatibility warning during Android builds. Track upstream upgrades before Flutter makes this an error.
- Android tools report that the command-line SDK metadata reader is older than one installed SDK metadata format.

## Commands used for verification

```text
dart analyze . --fatal-infos             PASS
flutter test                             PASS — 159 tests
cd agent && uv run pytest -q             PASS — 40 tests
flutter build macos --debug              PASS
flutter build apk --debug                PASS
```

## Next milestone definition

The voice MVP is complete when a real hosted call works on macOS and one mobile platform, including permission handling, two-way audio, live transcript, interruption, retry/reconnect, and continuation in text chat. Production release additionally requires the authenticated token service and real platform signing credentials.
