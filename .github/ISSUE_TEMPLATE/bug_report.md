---
name: Bug Report
about: Report a bug in release-champion
title: "[Bug]: "
labels: bug
assignees: ''
---

### Description

A clear and concise description of the bug.

### Steps to Reproduce

Provide a minimal workflow snippet or steps that reproduce the issue.

```yaml
# e.g. the relevant step from your release workflow
- uses: offload-project/release-champion@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    # ...
```

1. Workflow trigger '...'
2. PR / commit shape '...'
3. See the error.

### Expected Behavior

Explain what you expected to happen (e.g., release PR created, tag pushed, npm publish succeeded).

### Actual Behavior

What actually happened? Include the failing job log excerpt or `gh run view` output.

```
// Paste relevant log output here
```

### Environment

- Action version (tag or SHA): [e.g., v1.7.0, or a commit SHA]
- Runner OS: [e.g., ubuntu-latest, ubuntu-22.04]
- Node version (if npm publishing is involved): [e.g., 24]
- Repository visibility: [public / private]

### Relevant Configuration

Share the `with:` inputs you passed to the action, and the workflow `permissions:` block:

```yaml
permissions:
  contents: write
  pull-requests: write
  # ...

- uses: offload-project/release-champion@<version>
  with:
    # ...
```

### Additional Context

Add any other context — link to the failing workflow run (if public), related issues, or the PR that triggered the run.
