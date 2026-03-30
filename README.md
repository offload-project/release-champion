# Release Champion

A GitHub Action that automates semantic versioning and releases
using <a href="https://www.conventionalcommits.org/">conventional commits</a>. Label a PR, merge it, and the action
handles the
rest — version bumps, changelogs, tags, and GitHub releases.

## Quick start

1. Add the workflow to your repo (see [Usage](#usage) below)
2. Create a label called `change-release` in your repo (or configure a custom label via the `release-label` input)
3. When you're ready to release, add the `change-release` label to a PR
4. Merge the PR — the action creates a release PR with the version bump and changelog
5. Review and merge the release PR — the action creates the tag and GitHub release

That's it. The label is what tells the action "this merge should trigger a release."

## How it works

The action operates in two phases, both triggered by `pull_request` `closed` events:

### Phase 1: Create a release PR

When a PR with the release label (default: `change-release`) is merged:

1. Finds the latest version tag
2. Analyzes all commits since that tag using conventional commit prefixes
3. Determines the appropriate semver bump (major, minor, or patch)
4. Creates a `release/<prefix><version>` branch
5. Optionally generates/updates `CHANGELOG.md`
6. Opens a release PR with a summary of what's included

### Phase 2: Finalize the release

When the release PR (detected by the `release/` branch prefix) is merged:

1. Creates an annotated git tag
2. Optionally creates a GitHub release with auto-generated release notes

## Usage

```yaml
# .github/workflows/release.yml
name: Release

on:
  pull_request:
    types: [ closed ]

jobs:
  release:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: offload-project/release-champion@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

> **Note:** `fetch-depth: 0` is required so the action can access the full commit history and tags.

## Inputs

| Input            | Description                                           | Required | Default          |
|------------------|-------------------------------------------------------|----------|------------------|
| `github-token`   | GitHub token for creating PRs, tags, and releases     | Yes      | —                |
| `release-label`  | Label that marks a PR for release                     | No       | `change-release` |
| `version-prefix` | Prefix for version tags (e.g., `v` produces `v1.2.3`) | No       | `v`              |
| `create-tag`     | Create a git tag when the release PR is merged        | No       | `true`           |
| `create-release` | Create a GitHub release when the release PR is merged | No       | `true`           |
| `draft-release`  | Create the GitHub release as a draft (unpublished)    | No       | `true`           |
| `changelog`      | Generate or update `CHANGELOG.md` in the release PR   | No       | `true`           |

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

### Custom label and no version prefix

```yaml
- uses: offload-project/release-champion@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    release-label: 'ready-to-release'
    version-prefix: ''
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
  - uses: actions/checkout@v4
    with:
      fetch-depth: 0
  - uses: offload-project/release-champion@v1
    id: release
    with:
      github-token: ${{ secrets.GITHUB_TOKEN }}
  - if: steps.release.outputs.version
    run: echo "Released version ${{ steps.release.outputs.version }}"
```

## Permissions

The workflow needs `contents: write` (for tags and releases) and `pull-requests: write` (for creating PRs). If using the
default `GITHUB_TOKEN`, set these under the job's `permissions` key.

## Tests

```shell
bats tests/conventional.bats
```

## License

MIT
