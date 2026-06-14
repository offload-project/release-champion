# Contributing to Release Champion

Thanks for your interest in contributing! This document outlines the process and standards for contributing to `offload-project/release-champion`.

## Code of Conduct

By participating in this project, you agree to treat fellow contributors with respect. Be kind, assume good intent, and keep discussions focused on the work. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Ways to Contribute

- Reporting bugs via the [Bug Report](.github/ISSUE_TEMPLATE/bug_report.md) template
- Proposing new features via the [Feature Request](.github/ISSUE_TEMPLATE/feature_request.md) template
- Improving documentation (`README.md`, `CHANGELOG.md`)
- Fixing bugs or implementing features through pull requests
- Reviewing open pull requests

Before opening a large PR, please open an issue first to discuss the approach.

## Requirements

- **Bash 4+** — the action runs entirely as composite bash scripts.
- **[bats-core](https://github.com/bats-core/bats-core)** — for running the test suite locally.
- **GitHub CLI (`gh`)** — used by the scripts to interact with PRs, releases, and labels. Required for any manual end-to-end testing.
- A POSIX-compatible environment (macOS or Linux). The action targets `ubuntu-latest` runners.

## Getting Set Up

1. Fork the repository on GitHub and clone your fork:

   ```bash
   git clone git@github.com:<your-username>/release-champion.git
   cd release-champion
   ```

2. Install [bats-core](https://github.com/bats-core/bats-core#installation):

   ```bash
   # macOS
   brew install bats-core

   # Linux (via npm)
   npm install -g bats
   ```

3. Create a feature branch off `main`:

   ```bash
   git checkout -b feat/short-description
   ```

## Development Workflow

The action is implemented as a small set of bash scripts under `scripts/`:

| Script                     | Role                                                                   |
| -------------------------- | ---------------------------------------------------------------------- |
| `main.sh`                  | Entry point — dispatches to Phase 1 (release PR) or Phase 2 (finalize) |
| `conventional.sh`          | Parses conventional commits and computes the semver bump               |
| `changelog.sh`             | Generates / updates `CHANGELOG.md` grouped by change type              |
| `create-release-pr.sh`     | Phase 1 — branches, bumps version, opens the release PR                |
| `finalize-release.sh`      | Phase 2 — tags, creates the GitHub release, optionally publishes npm   |

Keep scripts focused and `set -euo pipefail`-clean. Prefer pure functions in the helper scripts so they're easy to test from `bats`.

### Running the Test Suite

```bash
bats tests/conventional.bats
```

Run all `.bats` files:

```bash
bats tests/
```

New behavior should be covered by tests; bug fixes should include a regression test.

### Manual End-to-End Testing

For changes that touch the PR / tag / release flow, the easiest path is:

1. Point a fork's workflow at your branch with `uses: <your-fork>/release-champion@<your-branch>`.
2. Open and merge a throwaway PR to trigger Phase 1.
3. Merge the resulting release PR to trigger Phase 2.
4. Verify the tag, GitHub release, and (if relevant) the npm publish.

Note this in the PR description so reviewers know what was exercised.

### Code Style

- Two-space indentation in bash.
- `set -euo pipefail` at the top of every script.
- Quote variable expansions (`"$var"`) unless word-splitting is intended.
- Use `local` for variables inside functions.
- Prefer `[[ ... ]]` over `[ ... ]` for tests.

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/) — the action itself depends on them to compute version bumps, so commits in this repo must follow the convention strictly.

Format: `<type>(<optional scope>): <description>`

Common types used in this repo:

| Type       | Use for                                              | Bump  |
| ---------- | ---------------------------------------------------- | ----- |
| `feat`     | New user-facing functionality                        | minor |
| `fix`      | Bug fixes                                            | patch |
| `refactor` | Internal change with no behavior difference          | patch |
| `test`     | Adding or updating tests                             | patch |
| `docs`     | Documentation only                                   | patch |
| `chore`    | Tooling, dependency bumps, repo housekeeping         | patch |
| `ci`       | Changes to GitHub Actions workflows                  | patch |

Examples (taken from this project's history):

- `feat: support npm trusted publisher publishing`
- `fix: broken pipeline error`
- `chore: release v1.6.1`

Breaking changes: add `!` after the type (e.g., `feat!: rename require-release-label input`) or include `BREAKING CHANGE:` in the body, and explain the migration path in the PR. Breaking changes trigger a **major** bump.

## Pull Requests

1. Make sure your branch is up to date with `main`.
2. Run the tests before pushing:

   ```bash
   bats tests/
   ```

3. Push your branch and open a PR against `main` using the [PR template](.github/pull_request_template.md).
4. Fill in:
   - What changed and why
   - Type of change (bug fix, feature, breaking, refactor, etc.)
   - How it was tested (bats, manual fork run, both)
   - Whether the README needs updating
5. Keep PRs focused. One logical change per PR makes review faster and bisection easier.
6. CI must pass before review.
7. Address review feedback in additional commits rather than force-pushing while review is active.

## Adding or Changing Features

When working on this action, keep these areas in mind:

- **Inputs and outputs** — `action.yml` is the public API. Renaming an input/output, removing one, or changing a default is a breaking change. Add new inputs with safe defaults.
- **Composite action contract** — the scripts run on the consumer's runner. Don't assume tools beyond what `ubuntu-latest` provides (`bash`, `git`, `gh`, `node`/`npm` when the npm features are used).
- **Token handling** — never echo `github-token` or `npm-token`. Pass secrets via env vars and avoid interpolating them into command strings.
- **PR / commit metadata** — values like commit messages, PR titles, and branch names are attacker-controllable on public repos. Always quote them and never `eval` or pass them through unquoted shell expansion.
- **Trusted Publishers (OIDC)** — the absence of `npm-token` is the signal to use OIDC. Don't reintroduce a fallback that silently swaps modes.
- **Phase detection** — Phase 1 vs Phase 2 is decided by whether the merged branch matches `release/*`. Changes to this detection are effectively breaking and need a migration note.

## Documentation

If your change affects inputs, outputs, behavior, or usage, update:

- `README.md` — Inputs / Outputs tables, Usage examples, How it works
- `action.yml` — input/output `description:` fields stay in sync with the README
- `CHANGELOG.md` is generated by the action itself — don't hand-edit it in feature PRs

## Reporting Security Issues

Please do **not** open a public issue for security vulnerabilities. See [SECURITY.md](SECURITY.md) for the private reporting process.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE.md) that covers this project.
