# GitHub branch-protection settings

Repository files cannot enforce branch protection. After creating the public GitHub repository, an owner must create a branch ruleset targeting `main` with the following settings.

## Required rules

- Require a pull request before merging.
- Require at least one approval from a maintainer who did not author the pull request.
- Dismiss stale approvals when new commits are pushed.
- Require approval of the most recent reviewable push.
- Require conversation resolution before merging.
- Require the branch to be up to date before merging.
- Block force pushes.
- Block branch deletion.
- Do not allow bypassing the ruleset, including for administrators.
- Do not grant direct write access to casual contributors; contributions should arrive from forks or non-protected branches.

## Status checks

The repository has no CI/CD workflows, so there are no status checks to require. Contributors report the results of the local checks listed in [`CONTRIBUTING.md`](../CONTRIBUTING.md) in their pull request, and the reviewing maintainer relies on them. If workflows are added again (the earlier ones are in the Git history, see the README), add "Require status checks to pass before merging" to the rules above and select the checks they produce.

## Repository security settings

Before public launch, open **Settings → Advanced Security** and:

- enable private vulnerability reporting so [`SECURITY.md`](../SECURITY.md) has a confidential reporting path;
- enable dependency graph and Dependabot alerts; and
- subscribe at least one maintainer to security-alert notifications.

## Merge permissions

Only maintainers should have repository write access and permission to merge. Contributors may open pull requests but must not be added as collaborators merely to merge their own work.

## Verification

After enabling the ruleset:

1. Create a test branch and confirm a direct push to `main` is rejected.
2. Open a test pull request and confirm it cannot merge without approval.
3. Confirm the author cannot approve their own pull request.
4. Confirm only a maintainer can perform the final merge.
