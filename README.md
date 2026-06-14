# Release Champion

[![GitHub Release](https://img.shields.io/github/v/release/offload-project/release-champion?style=flat-square)](https://github.com/offload-project/release-champion/releases)
[![Build](https://img.shields.io/github/actions/workflow/status/offload-project/release-champion/release.yml?label=build&style=flat-square)](https://github.com/offload-project/release-champion/actions/workflows/release.yml)
[![Marketplace](https://img.shields.io/badge/marketplace-release--champion-blue?style=flat-square&logo=github)](https://github.com/marketplace/actions/release-champion)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)](LICENSE.md)

A GitHub Action that automates semantic versioning and releases
using [conventional commits](https://www.conventionalcommits.org/). Merge a PR and the action handles the rest — version
bumps, changelogs, tags, and GitHub releases. Optionally gate releases behind a label.

## Features

- **Two-phase release flow** — opens a release PR first; tags and releases only after that PR is merged
- **Conventional commits** — automatic semver bumps (major/minor/patch) from commit prefixes
- **Changelog generation** — `CHANGELOG.md` grouped by change type with links to the originating PRs
- **Optional release gating** — require a label on a PR before it triggers a release
- **GitHub releases** — auto-generated release notes, draft or published
- **npm publishing** — token-based or [npm Trusted Publishers](https://docs.npmjs.com/trusted-publishers) (OIDC)
- **GitHub Packages support** — point at any npm-compatible registry
- **Composite action** — runs as bash on the consumer's runner, no Docker pull

## Table of Contents

- [Quick start](#quick-start)
- [How it works](#how-it-works)
    - [Phase 1: Create a release PR](#phase-1-create-a-release-pr)
    - [Phase 2: Finalize the release](#phase-2-finalize-the-release)
- [Usage](#usage)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Conventional commits and version bumps](#conventional-commits-and-version-bumps)
- [Changelog format](#changelog-format)
- [Examples](#examples)
- [Permissions](#permissions)
- [Tests](#tests)
- [Contributing](#contributing)
- [Security](#security)
- [License](#license)

## Quick start

1. Add the workflow to your repo (see [Usage](#usage) below)
2. Merge a PR — the action creates a release PR with the version bump and changelog
3. Review and merge the release PR — the action creates the tag and GitHub release

By default, every merged PR triggers a release. If you'd rather control when releases happen, set
`require-release-label: true` and add the configured label (default: `change-release`) to PRs that should trigger a
release.

## How it works

The action operates in two phases, both triggered by `pull_request` `closed` events:

### Phase 1: Create a release PR

When a PR is merged (and the release label requirement is met, if enabled):

1. Finds the latest version tag
2. Analyzes all commits since that tag using conventional commit prefixes
3. Determines the appropriate semver bump (major, minor, or patch)
4. Creates a `release/<prefix><version>` branch
5. Bumps `package.json` version if npm publishing is enabled
6. Optionally generates/updates `CHANGELOG.md`
7. Opens a release PR with a summary of what's included

### Phase 2: Finalize the release

When the release PR (detected by the `release/` branch prefix) is merged:

1. Creates an annotated git tag
2. Optionally creates a GitHub release with auto-generated release notes
3. Optionally publishes to an npm registry

## Usage

```yaml
# .github/workflows/release.yml
name: Release

on:
  pull_request:
    types: [ closed ]

permissions:
  contents: write
  pull-requests: write

jobs:
  release:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          ref: ${{ github.event.pull_request.merge_commit_sha }}
          fetch-depth: 0
      - uses: offload-project/release-champion@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

> **Note:** `fetch-depth: 0` is required so the action can access the full commit history and tags.

## Inputs

| Input                   | Description                                                                                                       | Required | Default                      |
|-------------------------|-------------------------------------------------------------------------------------------------------------------|----------|------------------------------|
| `github-token`          | GitHub token for creating PRs, tags, and releases                                                                 | Yes      | —                            |
| `release-label`         | Label that marks a PR for release (only used when `require-release-label` is `true`)                              | No       | `change-release`             |
| `require-release-label` | Require the release label to trigger a release PR. When `false`, every merged PR triggers a release               | No       | `false`                      |
| `version-prefix`        | Prefix for version tags (e.g., `v` produces `v1.2.3`)                                                             | No       | `v`                          |
| `create-tag`            | Create a git tag when the release PR is merged                                                                    | No       | `true`                       |
| `create-release`        | Create a GitHub release when the release PR is merged                                                             | No       | `true`                       |
| `draft-release`         | Create the GitHub release as a draft (unpublished)                                                                | No       | `true`                       |
| `changelog`             | Generate or update `CHANGELOG.md` in the release PR                                                               | No       | `true`                       |
| `publish-npm`           | Publish the package to an npm registry when the release PR is merged                                              | No       | `false`                      |
| `npm-token`             | Auth token for the npm registry. Omit to use [Trusted Publishers](#publish-to-npm-with-trusted-publishers) (OIDC) | No       | —                            |
| `npm-registry`          | npm registry URL (set to `https://npm.pkg.github.com` for GitHub Packages)                                        | No       | `https://registry.npmjs.org` |
| `npm-build-command`     | Build command to run before `npm publish` (e.g., `npm run build`)                                                 | No       | —                            |

## Outputs

| Output        | Description                                 |
|---------------|---------------------------------------------|
| `version`     | The new version string (e.g., `1.2.3`)      |
| `release-pr`  | URL of the created release PR (Phase 1)     |
| `tag`         | The created tag name (Phase 2)              |
| `release-url` | URL of the created GitHub release (Phase 2) |

## Conventional commits and version bumps

The action parses commit messages to determine the version bump:

| Commit prefix                                               | Bump      | Example                               |
|-------------------------------------------------------------|-----------|---------------------------------------|
| `feat!:` or `BREAKING CHANGE`                               | **major** | `feat!: drop support for Node 14`     |
| `feat:`                                                     | **minor** | `feat(auth): add OAuth2 support`      |
| `fix:`                                                      | **patch** | `fix: resolve null pointer in parser` |
| `chore:`, `docs:`, `refactor:`, `perf:`, `style:`, `build:` | **patch** | `chore: update dependencies`          |

The highest applicable bump wins. If any commit contains a breaking change, the bump is always major.

## Changelog format

When `changelog` is enabled, the action generates a `CHANGELOG.md` grouped by change type with links to the associated
PRs:

```markdown
## v1.3.0 - 2026-03-27

### Added

- Add support for wildcard permissions [#234](https://github.com/owner/repo/pull/234)
- Add `hasAnyPermission` method [#230](https://github.com/owner/repo/pull/230)

### Fixed

- Fix cache invalidation on role update [#232](https://github.com/owner/repo/pull/232)

### Changed

- Update minimum PHP version to 8.1 [#228](https://github.com/owner/repo/pull/228)
```

Commits that can't be linked to a PR will reference the commit SHA instead.

## Examples

### Minimal — tags and draft releases

```yaml
- uses: offload-project/release-champion@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Published releases, no changelog

```yaml
- uses: offload-project/release-champion@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    draft-release: false
    changelog: false
```

### Require a label to release

```yaml
- uses: offload-project/release-champion@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    require-release-label: true
```

### Custom label and no version prefix

```yaml
- uses: offload-project/release-champion@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    require-release-label: true
    release-label: 'ready-to-release'
    version-prefix: ''
```

### Publish to npm

```yaml
- uses: offload-project/release-champion@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    publish-npm: true
    npm-token: ${{ secrets.NPM_TOKEN }}
    npm-build-command: 'npm run build'
```

### Publish to npm with Trusted Publishers

[npm Trusted Publishers](https://docs.npmjs.com/trusted-publishers) lets you publish without a long-lived token. npm
exchanges a GitHub OIDC token at publish time and attaches a provenance attestation automatically.

**Setup:**

1. On npmjs.com, open your package's settings → **Publishing access** and add a trusted publisher. Match the repo
   (`owner/repo`), the workflow filename (e.g., `release.yml`), and the environment if you use one. The values must
   match exactly — a mismatch will reject the publish.
2. Use Node 24+ in your workflow. Trusted Publishers requires npm ≥ 11.5.1; Node 24 ships it by default, older Node
   versions don't.
3. Add `id-token: write` to the workflow's `permissions`.
4. Omit `npm-token`. If a token is set, the action falls back to token auth and skips OIDC.

> **First publish:** Trusted Publishers can only be configured on a package that already exists on npm. For a brand-new
> package, do the initial publish manually (or with a token) so the package exists, then set up the trusted publisher
> and remove the token.

```yaml
name: Release

on:
  pull_request:
    types: [ closed ]

permissions:
  contents: write
  pull-requests: write
  id-token: write           # required for Trusted Publishers

jobs:
  release:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          ref: ${{ github.event.pull_request.merge_commit_sha }}
          fetch-depth: 0
      - uses: actions/setup-node@v4
        with:
          node-version: '24'
          registry-url: 'https://registry.npmjs.org'
      - uses: offload-project/release-champion@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          publish-npm: true
          npm-build-command: 'npm run build'
```

### Publish to GitHub Packages

```yaml
- uses: offload-project/release-champion@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    publish-npm: true
    npm-token: ${{ secrets.GITHUB_TOKEN }}
    npm-registry: 'https://npm.pkg.github.com'
    npm-build-command: 'npm run build'
```

### Tag only, no GitHub release

```yaml
- uses: offload-project/release-champion@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    create-release: false
```

### Using outputs

```yaml
steps:
  - uses: actions/checkout@v6
    with:
      ref: ${{ github.event.pull_request.merge_commit_sha }}
      fetch-depth: 0
  - uses: offload-project/release-champion@v1
    id: release
    with:
      github-token: ${{ secrets.GITHUB_TOKEN }}
  - if: steps.release.outputs.version
    run: echo "Released version ${{ steps.release.outputs.version }}"
```

## Permissions

The workflow needs `contents: write` (for tags and releases) and `pull-requests: write` (for creating PRs). If
publishing to GitHub Packages, also add `packages: write`. If using the default `GITHUB_TOKEN`, set these under the
job's `permissions` key.

## Tests

```shell
bats tests/conventional.bats
```

## Contributing

Contributions are welcome! Please see the documents below before getting started.

- [Contributing Guide](CONTRIBUTING.md) — setup, workflow, commit conventions, and PR process
- [Code of Conduct](CODE_OF_CONDUCT.md) — expectations for participation in this project

## Security

- [Security Policy](SECURITY.md) — how to report a vulnerability privately

## License

The MIT License (MIT). Please see [License File](LICENSE.md) for more information.
