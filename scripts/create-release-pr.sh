#!/usr/bin/env bash
# Phase 1: Analyze commits since last tag, determine version bump, create release PR

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/conventional.sh"
source "$SCRIPT_DIR/changelog.sh"

main() {
  echo "::group::Analyzing commits for version bump"

  # Get the last tag
  local last_tag
  last_tag=$(get_last_tag)

  if [[ -n "$last_tag" ]]; then
    echo "Last tag: ${last_tag}"
  else
    echo "No previous tags found — this will be the first release"
  fi

  # Get commits since last tag
  local commits
  commits=$(get_commits_since_tag "$last_tag")

  if [[ -z "$commits" ]]; then
    echo "::warning::No commits found since last tag. Nothing to release."
    echo "::endgroup::"
    return 0
  fi

  local commit_count
  commit_count=$(echo "$commits" | wc -l | tr -d ' ')
  echo "Found ${commit_count} commit(s) since last tag"

  # Determine bump type from commit messages
  local bump
  bump=$(echo "$commits" | while IFS= read -r line; do echo "${line#* }"; done | determine_bump)
  echo "Bump type: ${bump}"

  # Calculate new version
  local new_version
  new_version=$(next_version "$last_tag" "$bump")
  echo "New version: ${new_version}"
  echo "::endgroup::"

  # Create release branch
  local branch_name="release/${INPUT_VERSION_PREFIX}${new_version}"
  echo "::group::Creating release branch: ${branch_name}"

  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"

  git checkout -b "$branch_name"

  # Generate changelog if enabled
  if [[ "$INPUT_CHANGELOG" == "true" ]]; then
    echo "Generating changelog..."
    update_changelog "$new_version" "$last_tag"
    git add CHANGELOG.md
    git commit -m "chore: update changelog for ${INPUT_VERSION_PREFIX}${new_version}"
  fi

  # Push the branch
  git push origin "$branch_name"
  echo "::endgroup::"

  # Generate the PR body with release notes preview
  echo "::group::Creating release PR"
  local pr_body
  pr_body=$(generate_pr_body "$new_version" "$last_tag" "$bump")

  # Create the pull request
  local pr_url
  pr_url=$(gh pr create \
    --base "$DEFAULT_BRANCH" \
    --head "$branch_name" \
    --title "release: ${INPUT_VERSION_PREFIX}${new_version}" \
    --body "$pr_body")

  echo "Release PR created: ${pr_url}"
  echo "::endgroup::"

  # Set outputs
  echo "version=${new_version}" >> "$GITHUB_OUTPUT"
  echo "release_pr=${pr_url}" >> "$GITHUB_OUTPUT"
}

generate_pr_body() {
  local new_version="$1"
  local last_tag="$2"
  local bump="$3"

  local body=""
  body+="## Release ${INPUT_VERSION_PREFIX}${new_version}"$'\n'$'\n'

  if [[ -n "$last_tag" ]]; then
    body+="**Bump**: \`${last_tag}\` → \`${INPUT_VERSION_PREFIX}${new_version}\` (${bump})"$'\n'$'\n'
  else
    body+="**Bump**: Initial release → \`${INPUT_VERSION_PREFIX}${new_version}\` (${bump})"$'\n'$'\n'
  fi

  body+="### What's included"$'\n'$'\n'

  local changelog_preview
  changelog_preview=$(generate_changelog "$new_version" "$last_tag")
  # Strip the version heading since we already have one
  changelog_preview=$(echo "$changelog_preview" | tail -n +3)

  body+="${changelog_preview}"$'\n'
  body+="---"$'\n'
  body+="*This PR was automatically created by the Release Champion action.*"$'\n'

  if [[ "$INPUT_CREATE_TAG" == "true" ]]; then
    body+="*Merging will create tag \`${INPUT_VERSION_PREFIX}${new_version}\`.*"$'\n'
  fi

  if [[ "$INPUT_CREATE_RELEASE" == "true" ]]; then
    if [[ "$INPUT_DRAFT_RELEASE" == "true" ]]; then
      body+="*A **draft** GitHub release will be created.*"$'\n'
    else
      body+="*A GitHub release will be published.*"$'\n'
    fi
  fi

  echo "$body"
}

main
