# GitHub branch-protection settings

Repository files cannot enforce branch protection. After creating the public GitHub repository, an owner must create a branch ruleset targeting `main` with the following settings.

## Required rules

- Require a pull request before merging.
- Require at least one approval from a maintainer who did not author the pull request.
- Dismiss stale approvals when new commits are pushed.
- Require approval of the most recent reviewable push.
- Require conversation resolution before merging.
- Require status checks to pass before merging.
- Require the branch to be up to date before merging.
- Block force pushes.
- Block branch deletion.
- Do not allow bypassing the ruleset, including for administrators.
- Do not grant direct write access to casual contributors; contributions should arrive from forks or non-protected branches.

## Required status checks

Select the checks produced by [`.github/workflows/ci.yml`](workflows/ci.yml):

- `Flutter quality`
- `Voice agent tests`
- `Android debug build`
- `macOS debug build`
- `Secret scan` from [`.github/workflows/security.yml`](workflows/security.yml)
- `Dependency review` from [`.github/workflows/dependency-review.yml`](workflows/dependency-review.yml). It runs only on pull requests and needs the dependency graph enabled (see below); a check that never reports blocks merging when it is required, so confirm it appears on the first test pull request before requiring it.

[`dependabot.yml`](dependabot.yml) opens weekly, grouped update pull requests for GitHub Actions, Dart/Flutter packages and the agent's `uv` lock. They are ordinary pull requests: they need the same checks and a maintainer approval.

## Repository security settings

Before public launch, open **Settings → Advanced Security** and:

- enable private vulnerability reporting so [`SECURITY.md`](../SECURITY.md) has a confidential reporting path;
- enable dependency graph, Dependabot alerts and Dependabot security updates; and
- subscribe at least one maintainer to security-alert notifications.

The Gitleaks action does not need a license for a repository owned by a personal GitHub account. If the repository is transferred to an organization, configure the action's required `GITLEAKS_LICENSE` repository secret.

## Merge permissions

Only maintainers should have repository write access and permission to merge. Contributors may open pull requests but must not be added as collaborators merely to merge their own work.

## Verification

After enabling the ruleset:

1. Create a test branch and confirm a direct push to `main` is rejected.
2. Open a test pull request and confirm it cannot merge without approval.
3. Confirm it cannot merge while a required CI check is pending or failing.
4. Confirm the author cannot approve their own pull request.
5. Confirm only a maintainer can perform the final merge.
