# Security policy

Thank you for helping keep Cryonis and its users safe.

## Supported versions

Cryonis is currently pre-release software. Security fixes are applied to the latest commit on `main` and, after releases begin, to the latest published release. Older development snapshots are not supported.

## Report a vulnerability privately

Do not open a public issue, discussion or pull request for a suspected vulnerability.

Use the repository's **Security → Advisories → Report a vulnerability** form. Include:

- the affected version, commit and platform;
- a clear description of the impact;
- reproducible steps or a minimal proof of concept;
- any suggested mitigation; and
- whether the issue is already public or actively exploited.

If private vulnerability reporting is not available, contact a maintainer through their GitHub profile without including sensitive details and ask for a private reporting channel.

Repository owners must enable GitHub private vulnerability reporting before public launch. See [`.github/BRANCH_PROTECTION.md`](.github/BRANCH_PROTECTION.md) for the launch checklist.

## What to expect

Maintainers aim to acknowledge a report within seven days and provide an initial assessment within fourteen days. These are targets, not a paid-service guarantee. We will coordinate remediation and disclosure with the reporter and credit them unless they prefer to remain anonymous.

Please allow a reasonable remediation window before publishing details. If a report is not a security issue, maintainers may redirect it to the normal issue tracker.

## Scope

Security reports may cover the Flutter application, the Python voice agent, build and release automation, credential handling, authentication, unsafe network behavior, and vulnerabilities introduced by project-owned dependencies or configuration.

Third-party hosted services such as Ollama, LiveKit, Deepgram and Cartesia are governed by their own security programs. Report vulnerabilities in those services to their vendors unless the problem is caused by Cryonis integration code.

## Secret exposure

If a credential is committed or disclosed:

1. Revoke or rotate it immediately; deleting it from the latest commit is not sufficient.
2. Assess logs and provider dashboards for unauthorized use.
3. Remove it from Git history when appropriate.
4. Add a regression check or scanner rule before closing the incident.

Never post real API keys, access tokens, signing keys, private URLs or user data in issues, pull requests, test fixtures or logs.

## Good-faith research

We welcome good-faith research that avoids privacy violations, data destruction, service disruption, social engineering and access beyond what is necessary to demonstrate the issue. This policy does not authorize testing against third-party infrastructure or other users' accounts.
