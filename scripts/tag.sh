#!/usr/bin/env bash
# Release tag creation.
#
# Tags are created through the GitHub API rather than `git push`. A `git push`
# of a ref whose commits touch .github/workflows/ is rejected for the default
# GITHUB_TOKEN ("refusing to allow a GitHub App to create or update workflow ...
# without `workflows` permission"), which would otherwise force consumers to
# supply a PAT with the `workflow` scope. Creating a ref via the API points at a
# commit that already exists on the server — no push, no workflow-file
# protection — so a plain GITHUB_TOKEN with `contents: write` is enough.

set -euo pipefail

# Create an annotated tag via the GitHub API: first a tag object, then a ref
# pointing at it. Uses gh (authenticated via GH_TOKEN).
# Usage: create_tag <owner/repo> <tag-name> <commit-sha> <message>
create_tag() {
  local repo="$1" tag_name="$2" commit_sha="$3" message="$4"

  # Create the annotated tag object and read back its SHA.
  local tag_sha
  tag_sha=$(gh api "repos/${repo}/git/tags" \
    -f tag="$tag_name" \
    -f message="$message" \
    -f object="$commit_sha" \
    -f type=commit \
    | node -e 'const fs=require("fs");console.log(JSON.parse(fs.readFileSync(0,"utf8")).sha)')

  # Point refs/tags/<tag> at the tag object.
  gh api "repos/${repo}/git/refs" \
    -f ref="refs/tags/${tag_name}" \
    -f sha="$tag_sha" > /dev/null
}
