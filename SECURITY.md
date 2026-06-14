# Security Policy

## Supported versions

Security fixes are applied to the latest minor release line. Older minor versions may receive fixes for critical issues at the maintainers' discretion — when in doubt, please upgrade to the latest `v1.x` tag.

| Version       | Supported              |
| ------------- | ---------------------- |
| `1.7.x`       | ✅                     |
| `1.x` (older) | ⚠️ critical fixes only |
| `< 1.0`       | ❌ (please upgrade)    |

Because this is a GitHub Action, consumers pin to a major (`@v1`) or specific tag. Fixes ship as new patch/minor tags on the supported line.

## Reporting a vulnerability

**Please do not open a public GitHub issue for security reports.**

Use [GitHub Security Advisories](https://github.com/offload-project/release-champion/security/advisories/new) to report privately. This lets us discuss, fix, and coordinate disclosure before details become public.

When reporting, please include:

- A description of the issue and its potential impact.
- Steps to reproduce, or a minimal proof-of-concept workflow.
- The action version (tag or SHA) affected.
- Runner OS and any non-default inputs.
- Any suggested fix or mitigation (optional).

## Response expectations

- **Acknowledgement:** within 5 business days.
- **Initial assessment:** within 10 business days.
- **Fix timeline:** depends on severity. Critical issues get prioritized; lower-severity issues may be batched into the next regular release.

We'll keep you updated on progress and credit you in the advisory unless you'd prefer to stay anonymous.

## Scope

Things in scope for this project:

- Command injection, argument injection, or shell-quoting bugs in the action's bash scripts (`scripts/*.sh`) that allow PR or commit metadata to execute attacker-controlled commands on the runner.
- Privilege escalation or token misuse — e.g., the action handling `github-token` or `npm-token` in a way that leaks them to logs, artifacts, or untrusted contexts.
- Release-integrity issues — e.g., the action publishing the wrong commit, producing a tag that doesn't match the released content, or skipping checks that would otherwise gate a release.
- Trusted Publishers / OIDC flow defects that let an unauthorized workflow obtain a publish token.
- Changelog or release-note generation bugs that allow injection of malicious markup into GitHub releases or `CHANGELOG.md`.

Things **not** in scope (please report upstream or with the relevant project):

- Vulnerabilities in GitHub Actions itself, the GitHub API, or the npm registry.
- Misconfigured workflows in consuming repositories (e.g., overly broad `permissions:`, exposing secrets to forked PRs, running the action on untrusted `pull_request_target` triggers without review).
- Vulnerabilities in user-supplied `npm-build-command` scripts.
- Compromise of a maintainer's own GitHub or npm account (report to the respective platform).

## Disclosure

Once a fix is published, we will:

1. Publish a GitHub Security Advisory with details and credit.
2. Tag a patch release and update the `v1` major-version tag.
3. Update the changelog with a brief mention (without exploit details prior to the disclosure window).

Thanks for helping keep the project and its users safe.
