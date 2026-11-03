# Cryonis Governance

## Principles

Cryonis is open for public contribution while maintaining a reviewed and reproducible `main` branch. Discussion is public by default, technical decisions are recorded in issues or pull requests, and no contributor receives production credentials through the repository.

## Roles

### Contributors

Anyone may open issues and pull requests, suggest designs, improve documentation, add tests, review public changes, or propose fixes. Contributors do not receive direct-push access to `main`.

### Reviewers

Reviewers provide technical feedback but cannot merge unless they are also maintainers. Reviewer status may be granted by maintainers based on sustained, constructive participation and relevant expertise.

### Maintainers

Maintainers set project direction, triage reports, approve changes, manage releases and repository settings, and merge pull requests. Write or admin access does not permit bypassing the pull-request policy.

## Change process

1. A contributor opens an issue for substantial or breaking work.
2. The change is implemented on a fork or non-protected branch.
3. A pull request explains its scope, tests, risks and documentation impact.
4. Required CI checks pass.
5. At least one authorized maintainer approves the pull request. The author cannot approve their own change.
6. A maintainer merges the approved pull request.

All changes, including maintainer-authored changes, use this process. Direct pushes and force pushes to `main` are prohibited. Emergency security fixes may use a private security advisory, but they still require review and a pull request before reaching `main` whenever the hosting platform permits it.

## Decision making

Maintainers seek consensus for normal changes. When consensus is not possible, the lead maintainer records the decision and reasoning in the relevant issue or pull request. Security, user privacy, backward compatibility and maintainability take priority over delivery speed.

## Becoming a maintainer

Existing maintainers may invite a contributor who has demonstrated sustained high-quality work, respectful collaboration, sound security judgment and familiarity with the project. Access is reviewed periodically and removed when it is no longer needed.

## Repository enforcement

The policy is enforced through GitHub branch protection or a repository ruleset. Required configuration is listed in [.github/BRANCH_PROTECTION.md](.github/BRANCH_PROTECTION.md). If repository settings and this document differ, maintainers must correct the settings before accepting further changes.
