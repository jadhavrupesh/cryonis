# Contributing to Cryonis

Thank you for helping improve Cryonis. Anyone may report an issue, propose an idea, review an open pull request, or contribute code and documentation.

## Pull requests are required

The `main` branch is protected by project policy:

- Do not push or commit directly to `main`.
- Every change must be submitted through a pull request, including changes made by maintainers.
- Only maintainers may merge pull requests.
- A pull request must report the results of the checks in [Required checks](#required-checks) and receive the required maintainer approval before merge.
- The pull-request author must not approve their own change.
- Force pushes and branch deletion on `main` are not allowed.

The policy is documented in [GOVERNANCE.md](GOVERNANCE.md). The repository owner must also enable the GitHub rules described in [.github/BRANCH_PROTECTION.md](.github/BRANCH_PROTECTION.md); files alone cannot block a direct push.

## Before starting

For bug fixes and small documentation changes, opening a pull request directly is fine. For large features, architecture changes, new providers, dependency replacements, or breaking changes, open an issue first so the approach can be agreed before implementation.

Never include API keys, LiveKit credentials, signing files, production endpoints, personal data, generated build output, or local `.env` files.

## Development setup

Required tools:

- Flutter 3.47.5 or a compatible stable version with Dart 3.13+
- Python 3.11–3.14 and `uv` for voice-agent work
- JDK 17 for Android builds
- Xcode for Apple builds

Install Flutter dependencies and run the application:

```bash
flutter pub get
flutter run -d macos
```

The ignored `lib/secrets.dart` file can contain empty values for offline development:

```dart
const ollamaApiKey = '';
const livekitSandboxId = '';
```

Set up the Python voice agent:

```bash
cd agent
uv sync --locked
```

Provider-backed integration tests require your own Ollama and LiveKit accounts. Maintainers do not share production credentials with contributors.

## Required checks

Run the checks relevant to your change before opening a pull request. For application changes, run:

```bash
dart analyze . --fatal-infos
flutter test
```

For voice-agent changes, also run:

```bash
cd agent
uv run pytest -q
```

For Android or platform changes, run the corresponding build where possible:

```bash
flutter build apk --debug
flutter build macos --debug
```

If a platform-specific check cannot be run locally, explain why in the pull request. This repository has no automated CI, so the results you report in the pull request are what the reviewer relies on.

If Gitleaks is installed, scan all committed history before pushing:

```bash
gitleaks git . --redact
```

If it reports a real credential, rotate the credential immediately and follow [`SECURITY.md`](SECURITY.md); removing it only from the newest commit is not sufficient.

## Pull-request expectations

- Keep one logical change per pull request.
- Explain the problem, approach, user-visible impact, risks and verification.
- Add or update tests for behavior changes.
- Update README, project status or improvement documentation when behavior or setup changes.
- Preserve existing public APIs unless the breaking change was discussed in an issue.
- Do not reformat unrelated files or overwrite another contributor's work.
- Keep commits free of secrets and generated build output.
- Respond to review feedback with new commits; do not rewrite shared history after review begins unless requested.

## Review and merge

A maintainer reviews correctness, security, tests, compatibility, documentation and scope. Approval is not guaranteed merely because the checks pass.

Once the required approval and checks pass, a maintainer merges the pull request using the repository's configured merge method. Contributors should not merge their own pull requests unless they are explicitly acting as an authorized maintainer under [GOVERNANCE.md](GOVERNANCE.md).
