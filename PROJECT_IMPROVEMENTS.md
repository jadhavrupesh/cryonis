# Cryonis Project Improvements

**Review date:** 3 November 2026

**Assumed load:** one user per installed app, one active Ollama response, and one LiveKit call at a time.

## What this repository does

Cryonis is a Flutter AI assistant providing Ollama text and vision chat, on-device dictation, and LiveKit-powered voice conversations in English and Hindi. The automated baseline is healthy: strict Dart analysis passes, all 104 Flutter tests pass, and all 40 Python voice-agent tests pass.

## Progress summary

| Priority | Done | Partial | Remaining |
|---|---:|---:|---:|
| Must fix | 1 | 0 | 6 |
| Should fix | 0 | 0 | 5 |
| Nice to have | 0 | 1 | 2 |

## Open-source release readiness

**Goal:** publish Cryonis as a reusable public repository without exposing maintainer infrastructure, credentials, or unclear licensing obligations.

**Current status:** not ready to make public yet. The project now uses the MIT License, has PR-only contribution governance, community/security policies, a fork-safe LiveKit template, a clean Gitleaks review, a dependency licence review and an in-app licences screen (OS-9). The CI/CD workflows and Dependabot that were added were removed on 3 November 2026 at the maintainer's request (OS-6). It still needs a decision on the Lumix design reference, public-repository configuration and enforced branch rules.

| Area | Status | Required before public launch |
|---|---|---|
| Software license | Ready | MIT License added at the repository root |
| Secret hygiene | Ready locally | Gitleaks found no leak in the earlier local history (since removed) or the intended public file set; the Gitleaks run on GitHub passed on the first commit; run it locally before later pushes, since there is no CI |
| Maintainer-specific configuration | Ready | Real LiveKit configuration is ignored; a placeholder template is tracked |
| Contributor documentation | Ready | Contribution, governance, conduct, security and support policies added |
| Issue and pull-request workflow | Partial | PR and issue templates added; GitHub ruleset and real Code Owners still need configuration |
| CI and dependency security | Removed | The workflows, dependency review and Dependabot were removed at the maintainer's request (3 November 2026); checks run locally and the earlier workflows stay in the Git history (see OS-6) |
| Dependency licences | Reviewed, 1 follow-up | No GPL, LGPL or AGPL package found in the Dart or Python dependencies; the app now shows its MIT licence and the third-party notices; decide on the Lumix design reference (OS-9) |
| Releases and changelog | Blocked | Define versioning, changelog and release process |
| Public onboarding | Partial | Add screenshots, quick start, architecture and fork/deployment guidance |

### OS-1. Choose and add the project license — completed

- **Completed:** Added the MIT License with copyright © 2026 Rupesh Jadhav and linked it from README.
- **Third-party notice:** The bundled Inter font remains under the SIL Open Font License in `assets/fonts/Inter-OFL.txt`.
- **Remaining legal review:** Preserve third-party notices and confirm that all screenshots and design assets intended for the public repository are owned or licensed for redistribution.

### OS-2. Remove maintainer-specific cloud configuration — completed

- **Completed:** `agent/livekit.toml` is ignored and excluded from Docker images; [`agent/livekit.toml.example`](agent/livekit.toml.example) contains public placeholders. README, project status and project context no longer publish the maintainer's LiveKit subdomain, agent ID, deployment version or fixed region.
- **Local operation:** The maintainer's existing ignored `agent/livekit.toml` remains available locally for deployment commands.
- **History review:** The earlier local Git history passed Gitleaks on 3 November 2026 and has since been removed (see item 2), so the first commit under the new account is a fresh public baseline that does not carry the removed identifiers. Rerun the scan after that commit.

### OS-3. Add automated secret and privacy checks — completed locally

- **Completed:** `lib/secrets.dart`, `agent/.env.local` and Android signing properties are ignored. A Gitleaks workflow ran against a full-history checkout on pushes and pull requests until the CI/CD was removed (OS-6); run Gitleaks locally instead.
- **Verified 3 November 2026:** Gitleaks 8.30.1 found no leaks in the two earlier commits (that history has since been removed, see item 2) and no leaks in the 1.39 MB intended public file set (tracked files plus non-ignored new files). A separate broad 520 MB workspace scan detected the intentionally ignored `agent/.env.local` credential and generated Flutter/dependency artifacts; none are part of the public file set. Rerun the scan after future commits and before the first push.
- **Privacy review:** Remove local absolute paths, personal email addresses, device identifiers, private URLs and unnecessary production IDs from public documentation and fixtures.
- **Failure policy:** Run Gitleaks locally before pushing (see `CONTRIBUTING.md`). [`SECURITY.md`](SECURITY.md) documents private reporting and credential rotation; a deleted secret must still be rotated and removed from history when appropriate.

### OS-4. Add community health files — completed locally

- **Completed:** Added `CONTRIBUTING.md`, `GOVERNANCE.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `SUPPORT.md`, bug/feature/private-vulnerability forms, a pull-request template, a Code Owners example and a branch-protection configuration guide. Every change must use a pull request with reported local check results and maintainer approval; only maintainers may merge.
- **Remaining GitHub setup:** Replace the placeholder security-advisory URL and Code Owner with the real public repository owner/team, enable private vulnerability reporting and enable Discussions if it will be used for support.
- **Scope clarity:** Explain that contributors supply their own Ollama and LiveKit accounts and that maintainers do not provide shared production credentials or guaranteed free inference quota.

### OS-5. Make setup fork-safe

- **Current state:** The README is thorough but mixes reusable setup with the maintainer's deployment history, bundle ID and hosted-agent details.
- **Implementation:** Separate the public quick start from historical notes. Add copyable example files for Flutter secrets, LiveKit configuration and Android signing; use placeholders everywhere; explain how fork owners change application/bundle IDs.
- **Acceptance test:** A new contributor should be able to clone the repository, run offline tests and start text chat without access to the maintainer's machine or cloud projects.

### OS-6. CI and dependency maintenance — removed at the maintainer's request

- **What was built (3 November 2026):** SHA-pinned GitHub Actions workflows (strict analysis, Flutter and Python tests, Android and macOS debug builds), a Gitleaks secret scan, a pull-request dependency review with an AGPL/GPL deny list, and Dependabot for Actions, Dart packages and the agent's `uv` lock.
- **What happened:** The first push started them. The secret scan passed; Dependabot opened three update pull requests and the dependency-review job failed on the first two (cause not investigated). Actions was switched off in the repository settings, then the workflows and `dependabot.yml` were deleted, the three pull requests closed and Dependabot's branches removed.
- **Where they are now:** Only in the Git history, in the first commit `c02d8ad`. Restore them with `git checkout c02d8ad -- .github/workflows .github/dependabot.yml` and re-enable Actions.
- **What this means:** Nothing automated guards a pull request. Contributors report the results of the local checks in [`CONTRIBUTING.md`](CONTRIBUTING.md), and the maintainer reviews them.
- **If they are restored:** GitHub's list of dependency-graph ecosystems names `pubspec.lock` but not `uv.lock`, so dependency review and Dependabot alerts may not see changes to the Python lock (a `pip-audit` step would cover it; it reported nothing on the current lock, see item 15). Dependabot's `pub` updates run on its own Flutter SDK, which may be older than the pinned 3.47.5.
- **Release checks:** Add a release-mode Android build that does not require private signing credentials and verify that public builds contain no development secrets.

### OS-7. Define releases and project governance

- **Missing:** `CHANGELOG.md`, versioning policy and release checklist. Support and maintainer/decision ownership are now documented in `SUPPORT.md` and `GOVERNANCE.md`.
- **Implementation:** Adopt semantic versioning, document how releases are tagged and built, record breaking configuration changes, and state which platforms and versions receive support.
- **Recommended first release:** Publish an explicitly labeled pre-release after the security, license and onboarding blockers are resolved; do not describe the current development-sandbox voice flow as production authentication.

### OS-8. Prepare the public repository launch

- [x] Choose the public repository owner and name: `jadhavrupesh/cryonis`, private for now.
- [x] Add the MIT License and reference it from README.
- [x] Replace the maintainer's LiveKit configuration with an ignored local file and public template.
- [ ] Complete the remaining work in OS-5 through OS-7.
- [x] Scan the intended public file set for secrets (3 November 2026).
- [x] Run a full-history secret scan on the new repository's first commit: the Gitleaks run on GitHub passed (3 November 2026). Rerun it after later commits.
- [x] Run a dependency/license review (OS-9): no known vulnerabilities in the Python lock and no GPL-family licences in either ecosystem, 3 November 2026. The Dart packages were not vulnerability-audited.
- [x] Show open-source licence notices inside the app (OS-9, follow-up 1).
- [ ] Decide whether the Lumix-derived layout needs the designer's permission (OS-9, follow-up 2).
- [ ] Make the repository public only after the review passes. A private remote exists and `main` is pushed (3 November 2026).
- [ ] Configure repository description, topics, social preview and default branch. The description and eleven topics are set (3 November 2026); still to do: upload [`docs/social-preview.png`](docs/social-preview.png) under Settings → General → Social preview.
- [ ] Enable branch protection (there are no CI checks to require), vulnerability reporting and dependency alerts.
- [x] Document PR-only governance, maintainer-only merge authority and required branch-protection settings.
- [ ] Open one test issue and pull request to verify templates, permissions and contributor instructions.
- [ ] Tag the first pre-release and publish its changelog.

Completed since the original review:

- [x] Consolidated `agent/` and `agent_local/` into one deployed, unit-tested `agent/` implementation.
- [x] Updated the verification counts and deployment documentation.
- [x] Verified a real hosted English/Hindi call after consolidating the agent.
- [x] Pinned all CI actions to commit SHAs and added Dependabot plus a pull-request dependency review (OS-6); all of it was removed again the same day at the maintainer's request.
- [x] Ran the dependency licence review (OS-9).

### OS-9. Dependency licence review — completed, one follow-up

- **Method (3 November 2026):** Dart: all 126 packages in `pubspec.lock` (107 in the production graph from `flutter pub deps --no-dev`) were classified by matching the licence text in each package's pub-cache copy; the three the script flagged (`dbus`, `nm`, `file_selector_android`) were read by hand. Python: `pip-licenses --from=mixed` on the agent's locked environment (82 packages, test tools included), plus the licence files of the two LiveKit packages with special terms. This is phrase matching, not legal review.
- **Result:** no GPL, LGPL or AGPL package in either ecosystem, so the deny list in the (since removed) dependency-review workflow would not have blocked any current dependency. Dart: 94 BSD-3-Clause, 16 MIT, 5 Apache-2.0, 1 BSD-2-Clause, 1 Apache-2.0 plus BSD-3-Clause, 2 MPL-2.0, and 7 Flutter SDK packages. Python: almost entirely Apache-2.0, MIT and BSD, with the exceptions below.
- **MPL-2.0 (file-level copyleft, compatible with MIT when unmodified):** Dart `dbus` and `nm`, reached only through `connectivity_plus` from `livekit_client` (D-Bus and NetworkManager clients, so a Linux concern; Cryonis's documented targets are iOS, Android and macOS), and Python `certifi`. Their text mentions the GNU licences only as MPL "secondary licences"; they are not dual-licensed under them.
- **LiveKit terms, not open source:** `livekit-plugins-noise-cancellation` is declared as "see LiveKit's Terms of Service" and is a service plugin for LiveKit Cloud. `livekit-local-inference`, required by `livekit-agents`, is Apache-2.0 plus the LiveKit Model License, which allows its models only together with the LiveKit Agents framework and forbids using them or their output to build other models. Cryonis uses both as intended. They are installed from PyPI rather than stored in this repository, but a Docker image built from `agent/` contains them, so do not publish such an image; tell fork owners they accept LiveKit's terms when they deploy.
- **Follow-up 1, licence notices in the app — done 3 November 2026:** The app had no licence screen, and MIT, BSD and Apache licences require their notices to accompany binary distributions. The "Open-source licences" button at the bottom of the server-settings sheet now opens [`licenses_screen.dart`](lib/screens/licenses_screen.dart): Cryonis's own MIT licence in full (the bundled `LICENSE` file, so the text cannot drift), then a "Third-party licences" row that opens Flutter's licence page. That page lists well over a hundred entries because Flutter includes every package and every C++ library inside its engine (ANGLE alone has 58), including packages for platforms Cryonis does not ship; they are kept behind the MIT licence rather than removed, since their licences require the notices to stay with the app. The Inter font's OFL text is registered with `LicenseRegistry` ([`app_licenses.dart`](lib/services/app_licenses.dart)). Tests cover the bundled assets, the registration and the two-step flow; the page was opened on the A142 and showed the registered `Inter (font)` entry.
- **Follow-up 2, borrowed design:** the README, `UI_SPEC.md` and `PROJECT_CONTEXT.md` state that the interface follows the Dribbble shot "Lumix – AI Platform Mobile App" by Barly Design (layout, colours and motion, no brand assets). I did not check Dribbble's terms or the designer's. The maintainer should decide whether to ask for permission or reword it as inspiration only before publishing.
- **Not covered:** native libraries pulled in by Gradle and Apple tooling (for example the WebRTC binaries behind `flutter_webrtc`, an MIT wrapper); the origin of the 40 platform launcher-icon files; native libraries bundled inside Python wheels such as `av` and `onnxruntime`, which their declared licences do not list; and the Docker base image.

## Must fix

### 1. Production voice agent and tested agent were different — completed

- **What this was:** The deployed implementation lived in `agent_local/`, while the tests covered `agent/`.
- **Resolution:** The bilingual TTS defaults, table-speech filter, active LiveKit ID and scripted-call utility were merged into [`agent/`](agent/). The duplicate folder was removed, and the tests now cover the same source that is deployed.
- **Verification:** 40 Python tests pass, and a hosted call correctly answered two English questions and one Hindi question.

### 2. Establish a Git baseline — redo under the new account

- **What happened:** A baseline commit (`9459b47`, `Initial Cryonis project baseline`) and two later commits existed locally on `main` and `codex/open-source-readiness`, never pushed. On 3 November 2026 the repository's `.git` folder was moved out of the project so the code can be pushed to a different account; the working files were not changed (295 files before and after). The moved history is kept outside the project as `cryonis-git-history-backup-20261103` next to it, and its commits carried the machine's global Git identity.
- **Done since:** A new local repository was created the same day with the intended account's name and email set for this project only (the machine's global identity is unchanged), a fresh first commit was made, and `main` was pushed the same day to the private `jadhavrupesh/cryonis` repository over SSH with a dedicated key (the account's other key was left alone). GitHub shows the commit under the account's profile. The off-device backup now exists.
- **First remote runs:** The Secret scan (Gitleaks) passed on the pushed history, which closes the full-history scan. The CI run had not finished when GitHub Actions was switched off in the repository settings at the maintainer's request on 3 November 2026, so its result is unknown. Dependabot had opened three update pull requests; the Dependency review job failed on the first two, and the cause was not investigated. The workflows and `dependabot.yml` were then deleted, the three pull requests closed and Dependabot's branches removed.
- **Remaining:** Nothing automated runs now. To bring the workflows back, restore them from the first commit (`git checkout c02d8ad -- .github/workflows .github/dependabot.yml`) and re-enable Actions (Settings → Actions → General → Allow all actions). The repository stays private until the launch checklist passes.
- **If we skip it:** A machine failure could lose the project (this one is done: `main` is on GitHub).

### 3. Move attached images out of SharedPreferences

- **What this is:** Up to four 5 MB images are converted to base64 in [`image_attachment_picker.dart`](lib/services/image_attachment_picker.dart), embedded in chat JSON through [`chat_message.dart`](lib/models/chat_message.dart), and saved as one preference value by [`chat_controller.dart`](lib/state/chat_controller.dart).
- **Problem:** Four maximum-size images become roughly 26.7 MB after base64 expansion. Large preference values can slow startup, stall the UI, or fail to persist.
- **Fix:** Resize/compress attachments, store the image bytes in the application-support directory, and persist only file paths and metadata in the conversation record.
- **If we skip it:** Image-heavy conversations will become progressively slower and less reliable.

### 4. Serialize conversation persistence

- **What this is:** Conversation writes and removals are fire-and-forget operations in [`chat_controller.dart`](lib/state/chat_controller.dart).
- **Problem:** Starting a new chat calls `reset()` immediately before `send()` in [`home_screen.dart`](lib/screens/home_screen.dart). Removal and replacement are not one atomic operation, and the app can terminate before a write completes.
- **Fix:** Introduce a persistence repository with one queued or debounced write operation. Make conversation replacement atomic and flush important changes during lifecycle shutdown.
- **If we skip it:** A recently updated chat or voice transcript may occasionally disappear after restart.

### 5. Complete production voice authentication

- **What this is:** [`LiveKitVoiceBackend.endpoint`](lib/services/livekit_voice_backend.dart) supports request headers, but the factory in [`voice_flow.dart`](lib/screens/voice_flow.dart) provides no authenticated user session.
- **Problem:** A properly protected production token service will reject unauthenticated requests. The current sandbox token server is for development only.
- **Fix:** Add product sign-in/session handling and inject a short-lived bearer or session token into the LiveKit endpoint request. Keep LiveKit API secrets on the server.
- **If we skip it:** Voice must use an insecure public endpoint or remain dependent on the development sandbox.

### 6. Restrict Android cleartext networking

- **What this is:** [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml) globally enables `android:usesCleartextTraffic="true"` so Android can reach a local Ollama server.
- **Problem:** Release builds can also send prompts and responses to arbitrary plaintext HTTP endpoints.
- **Fix:** Scope HTTP access with an Android network-security configuration or a developer/local-server flavor, and warn users when a physical device connects to a plaintext server.
- **If we skip it:** Traffic sent to a remote HTTP endpoint can be intercepted on an untrusted network.

### 7. Capture the final voice transcript after shutdown

- **What this is:** `_finishVoice()` reads `_backend.lines` before awaiting `_backend.end()` in [`agent_voice_screen.dart`](lib/screens/agent_voice_screen.dart).
- **Problem:** A final transcript update arriving during shutdown is not included when the call moves into text chat.
- **Fix:** End the backend first, wait for its final transcript event, then call `conversationFrom(_backend.lines)`. Add a fake-backend test that appends a final line during `end()`.
- **If we skip it:** The last user sentence or assistant answer may intermittently disappear.

## Should fix

### 8. Make image attachment model-capability aware

- **What this is:** [`ollama_service.dart`](lib/services/ollama_service.dart) sends images to whichever model is selected.
- **Problem:** The app has no metadata indicating whether the selected model accepts image input.
- **Fix:** Track model capabilities, disable attachment for incompatible models, or offer to switch to an available vision model.
- **If we skip it:** Users can select valid images and still receive a provider error.

### 9. Validate and decode images once

- **What this is:** [`image_attachment_picker.dart`](lib/services/image_attachment_picker.dart) infers MIME type from the filename extension. [`chat_bubble.dart`](lib/widgets/chat_bubble.dart) and [`input_bar.dart`](lib/widgets/input_bar.dart) decode base64 during widget builds.
- **Problem:** Renamed non-image files pass initial validation, large-dimension compressed images can consume excessive memory, and streaming rebuilds can repeatedly decode the same data.
- **Fix:** Verify file signatures, inspect dimensions, resize once, and render from a stable file or memory image provider.
- **If we skip it:** Invalid or unusually large images can crash or visibly stutter the chat.

### 10. Improve bilingual TTS selection

- **What this is:** [`SpeechSettings`](agent/src/agent.py) recognizes English and Hindi but uses one `TTS_LANGUAGE` value for the entire call; it currently defaults to `hi`.
- **Problem:** English responses are synthesized through the Hindi/Hinglish configuration, and their naturalness has not been judged by ear.
- **Fix:** Select the TTS language per turn or expose a call-language setting. Run an A142 acceptance matrix covering English, Hindi, Hinglish, Bluetooth, barge-in, reconnect and voice-to-text handoff.
- **If we skip it:** English pronunciation and mixed-language calls may feel unnatural even though scripted recognition tests pass.

### 11. Harden settings validation and saving

- **What this is:** `_connect()` in [`sheets.dart`](lib/widgets/sheets.dart) catches only the production-token URL error, while Ollama URL normalization in [`ollama_service.dart`](lib/services/ollama_service.dart) accepts loosely formed addresses.
- **Problem:** Storage failures or malformed server addresses can escape the UI, and repeated Save taps can overlap.
- **Fix:** Accept only valid HTTP/HTTPS server URLs, catch storage and network exceptions, show field-specific errors, and disable the button while saving.
- **If we skip it:** Incorrect settings can result in confusing errors or unhandled exceptions.

### 12. Replace the hard-coded free cloud-model list

- **What this is:** [`freeCloudModels`](lib/app_config.dart) is based on a one-time provider probe.
- **Problem:** Provider availability and pricing can change without an application update.
- **Fix:** Load a remotely maintained capability document or perform a lightweight availability probe and cache the result.
- **If we skip it:** Newly available models remain hidden and unavailable models may continue to appear.

## Nice to have

### 13. Add real multi-conversation history

- **What this is:** The UI says “Previous conversations,” but [`ChatController`](lib/state/chat_controller.dart) stores only one conversation under one key.
- **Problem:** Starting a new chat replaces the previous conversation.
- **Fix:** Add conversation IDs, titles, timestamps, delete/search controls, and one database row or file per conversation.
- **If we skip it:** Cryonis remains suited to short sessions rather than becoming a dependable assistant history.

### 14. Add image generation as a separate capability

- **What this is:** Cryonis currently accepts images as model input but does not generate image files.
- **Problem:** Text/vision chat and image generation require different model capabilities and API workflows.
- **Fix:** Add an optional image-provider abstraction, generation screen, progress/cancellation, local gallery and provider capability checks.
- **If we skip it:** Image generation will continue outside Cryonis without affecting the existing chat experience.

### 15. Keep dependencies and documentation current — documentation completed

- **What this is:** The original review found twelve locked dependency upgrades and contradictory test counts in the documentation.
- **Progress:** README, project context and project status now consistently report 104 Flutter tests, 40 Python tests and the consolidated agent deployment.
- **Python lock (uncommitted):** The working tree raises the agent's minimum Python from 3.10 to 3.11 so the lock can use patched Pillow and OpenTelemetry releases (the reason is in `agent/pyproject.toml`), and README and CONTRIBUTING state 3.11–3.14. Checked 3 November 2026: `uv lock --check` and `uv sync --locked` succeed, 40 tests pass, and `pip-audit` finds no known vulnerabilities in the locked packages (runtime and test groups). The Dart packages were not audited.
- **Remaining fix:** Perform a controlled dependency upgrade, rerun device/build tests, and record the verification results in the status documents.
- **If we skip it:** Dependency maintenance debt will continue to accumulate.

## Recommended execution order

1. ~~Choose the public repository owner/name.~~ Chosen: `jadhavrupesh/cryonis`, private for now.
2. ~~Add dependency review/updates and finish pinning the remaining GitHub Actions.~~ Done, then removed with the rest of the CI/CD on 3 November 2026 (OS-6).
3. ~~Run the dependency licence inventory~~ (done, OS-9). Commit the work, then rerun Gitleaks after the final public-release commit.
4. Run the full public-release audit, create the remote, then push the reviewed history.
5. Replace SharedPreferences image storage and serialize conversation persistence.
6. Implement production authentication and restrict Android cleartext traffic.
7. Fix the final voice-transcript shutdown race.
8. Add model capability checks and harden image processing/settings validation.
9. Run real bilingual audio QA, then improve per-turn TTS language selection.
10. Add multi-conversation history and optional image generation.

## Verdict

Cryonis is a strong, tested MIT-licensed MVP with the core community and security files now present. It should not be made public until the full Git history is scanned and reviewed, dependency/asset licensing is checked, the real GitHub owner placeholders are configured and repository security/branch rules are enforced. After those open-source blockers, persistence, production authentication and release-network hardening remain the main product blockers before a public production release.

## Not checked

A legal review of the phrase-matched licence results, the native-library licences listed in OS-9, asset-redistribution review, signed Android/iOS distribution, iOS execution, store submission, the production token service, destructive/high-volume stress testing, and real by-ear voice quality remain outside the automated verification completed so far.
