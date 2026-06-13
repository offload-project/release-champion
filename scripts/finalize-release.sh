#!/usr/bin/env bash
# Phase 2: Create tag and GitHub release when the release PR is merged

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/conventional.sh"

main() {
  # Extract version from branch name (release/v1.2.3 → v1.2.3)
  local branch="$PR_HEAD_REF"
  local tag_name="${branch#release/}"
  local version="${tag_name#"$INPUT_VERSION_PREFIX"}"

  echo "Finalizing release for version: ${tag_name}"

  # Create tag
  if [[ "$INPUT_CREATE_TAG" == "true" ]]; then
    echo "::group::Creating tag: ${tag_name}"

    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"

    git tag -a "$tag_name" -m "Release ${tag_name}"
    git push origin "$tag_name"

    echo "Tag ${tag_name} created and pushed"
    echo "::endgroup::"

    echo "tag=${tag_name}" >> "$GITHUB_OUTPUT"
  fi

  # Create GitHub release
  if [[ "$INPUT_CREATE_RELEASE" == "true" ]]; then
    echo "::group::Creating GitHub release"

    local release_flags=()
    release_flags+=(--title "${tag_name}")
    release_flags+=(--generate-notes)

    if [[ "$INPUT_DRAFT_RELEASE" == "true" ]]; then
      release_flags+=(--draft)
    fi

    # Find the previous tag for --notes-start-tag
    local previous_tag
    previous_tag=$(get_previous_tag "$tag_name")
    if [[ -n "$previous_tag" ]]; then
      release_flags+=(--notes-start-tag "$previous_tag")
    fi

    local release_url
    release_url=$(gh release create "$tag_name" "${release_flags[@]}")

    echo "GitHub release created: ${release_url}"
    echo "::endgroup::"

    echo "release_url=${release_url}" >> "$GITHUB_OUTPUT"
  fi

  # Publish to npm
  if [[ "${INPUT_PUBLISH_NPM:-false}" == "true" ]]; then
    echo "::group::Publishing to npm"

    if ! command -v npm &>/dev/null; then
      echo "::error::npm is not installed. Add a setup-node step before release-champion."
      exit 1
    fi

    local registry="${INPUT_NPM_REGISTRY:-https://registry.npmjs.org}"
    local registry_host
    registry_host=$(echo "$registry" | sed 's|https:||' | sed 's|/$||')

    if [[ -n "${INPUT_NPM_TOKEN:-}" ]]; then
      echo "${registry_host}/:_authToken=${INPUT_NPM_TOKEN}" > .npmrc
      echo "registry=${registry}" >> .npmrc
    else
      # No token: rely on npm Trusted Publishers (OIDC).
      # Requires npm >= 11.5.1 and `id-token: write` workflow permission.
      echo "registry=${registry}" > .npmrc
      echo "No npm-token provided — using Trusted Publishers (OIDC)"
    fi

    if [[ -n "${INPUT_NPM_BUILD_COMMAND:-}" ]]; then
      echo "Running build: ${INPUT_NPM_BUILD_COMMAND}"
      npm install
      eval "$INPUT_NPM_BUILD_COMMAND"
    fi

    npm publish

    rm -f .npmrc

    local pkg_name
    pkg_name=$(node -p "require('./package.json').name")
    echo "Published ${pkg_name}@${version}"
    echo "::endgroup::"
  fi

  echo "version=${version}" >> "$GITHUB_OUTPUT"
}

# Get the tag before the given one (for release notes range)
get_previous_tag() {
  local current_tag="$1"
  local tags
  tags=$(git tag --list "${INPUT_VERSION_PREFIX}*" --sort=-v:refname 2>/dev/null || true)

  if [[ -z "$tags" ]]; then
    echo ""
    return
  fi

  local found_current=false
  while IFS= read -r tag; do
    if [[ "$found_current" == "true" ]]; then
      echo "$tag"
      return
    fi
    if [[ "$tag" == "$current_tag" ]]; then
      found_current=true
    fi
  done <<< "$tags"

  echo ""
}

main
