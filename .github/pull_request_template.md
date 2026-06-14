# Description

Please include a summary of the changes and the related issue. Include the motivation and context, and list any
workflows or downstream consumers impacted by this change.

Fixes # (issue)

## Type of change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing usage to not work as expected)
- [ ] Refactor / internal change (no functional impact)
- [ ] Documentation update
- [ ] CI / tooling change

## How Has This Been Tested?

Describe the tests you ran to verify your changes (bats tests, manual end-to-end run in a fork, etc.). Provide
instructions so reviewers can reproduce.

- [ ] `bats tests/` passes
- [ ] Added or updated tests covering the change
- [ ] Manually exercised the change end-to-end in a fork (Phase 1 / Phase 2 / npm publish, as applicable)

**Test Configuration**:

- Runner OS: [e.g., ubuntu-latest]
- Node version (if npm publishing is involved): [e.g., 24]
- Inputs exercised: [e.g., `require-release-label: true`, `publish-npm: true` with Trusted Publishers]

## Checklist

- [ ] My code follows the style guidelines of this project (bash `set -euo pipefail`, quoted expansions)
- [ ] I have performed a self-review of my code
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing tests pass locally with my changes
- [ ] I have updated the README and `action.yml` descriptions where relevant
- [ ] My commit messages follow Conventional Commits
- [ ] Any breaking changes (input renames, default changes, output changes) are clearly called out above
