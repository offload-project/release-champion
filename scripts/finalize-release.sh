#!/usr/bin/env bash
# Phase 2: Create tag and GitHub release when the release PR is merged

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/conventional.sh"
source "$SCRIPT_DIR/workspaces.sh"
source "$SCRIPT_DIR/install.sh"
source "$SCRIPT_DIR/npm-auth.sh"
source "$SCRIPT_DIR/tag.sh"

main() {
  # Extract version from branch name (release/v1.2.3 → v1.2.3)
  local branch="$PR_HEAD_REF"
  local tag_name="${branch#release/}"
  local version="${tag_name#"$INPUT_VERSION_PREFIX"}"

  echo "Finalizing release for version: ${tag_name}"

  # Create tag
  if [[ "$INPUT_CREATE_TAG" == "true" ]]; then
    echo "::group::Creating tag: ${tag_name}"

    # Tag the checked-out commit (the PR merge commit) via the GitHub API so the
    # default GITHUB_TOKEN suffices — see tag.sh.
    local commit_sha
    commit_sha=$(git rev-parse HEAD)
    create_tag "$GITHUB_REPOSITORY" "$tag_name" "$commit_sha" "Release ${tag_name}"

    echo "Tag ${tag_name} created"
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

    # Pick the auth mode and configure .npmrc accordingly (see npm-auth.sh).
    local auth_mode wrote_npmrc
    auth_mode=$(npm_auth_mode "${INPUT_NPM_TOKEN:-}" "${ACTIONS_ID_TOKEN_REQUEST_URL:-}")
    case "$auth_mode" in
      token)    echo "Authenticating with the provided npm-token" ;;
      oidc)     echo "No npm-token provided — using Trusted Publishers (OIDC)" ;;
      external) echo "No npm-token and no OIDC (id-token: write) detected — relying on existing npm auth (e.g. setup-node / NODE_AUTH_TOKEN)" ;;
    esac
    wrote_npmrc=$(write_npmrc "$auth_mode" "$registry" "${INPUT_NPM_TOKEN:-}" ".")

    if [[ -n "${INPUT_NPM_BUILD_COMMAND:-}" ]]; then
      # Install dependencies with the repo's own package manager (detected from
      # its lockfile) using a frozen-lockfile install for reproducibility, then
      # run the user's build command.
      local pm install_cmd pm_bin
      pm=$(detect_package_manager ".")
      install_cmd=$(install_command "$pm")
      pm_bin="${install_cmd%% *}"

      if ! command -v "$pm_bin" &>/dev/null; then
        echo "::error::${pm_bin} is required to install dependencies (detected from the lockfile) but is not installed. Add a setup step for it before release-champion."
        exit 1
      fi

      echo "Installing dependencies: ${install_cmd}"
      eval "$install_cmd"

      echo "Running build: ${INPUT_NPM_BUILD_COMMAND}"
      eval "$INPUT_NPM_BUILD_COMMAND"
    fi

    # Build the list of package directories to publish. In fixed/locked
    # workspaces mode this is the root plus every discovered workspace package;
    # otherwise it is just the root.
    local publish_dirs=(".")
    if [[ "${INPUT_NPM_WORKSPACES:-false}" == "true" ]]; then
      local pkg_dir
      while IFS= read -r pkg_dir; do
        [[ -n "$pkg_dir" ]] && publish_dirs+=("$pkg_dir")
      done < <(discover_packages ".")
    fi

    # Publish each package from the repo root so the root .npmrc auth applies
    # (npm only reads the project .npmrc from the current directory). Private
    # packages are skipped; scoped names get --access public for first publish.
    local dir
    for dir in "${publish_dirs[@]}"; do
      if is_private_package "$dir"; then
        echo "Skipping ${dir} (private package)"
        continue
      fi

      local publish_flags=("$dir")
      if is_scoped_package "$dir"; then
        publish_flags+=(--access public)
      fi

      npm publish "${publish_flags[@]}"

      local pkg_name
      pkg_name=$(node -e 'const fs=require("fs");console.log(JSON.parse(fs.readFileSync(process.argv[1],"utf8")).name)' "$dir/package.json")
      echo "Published ${pkg_name}@${version}"
    done

    # Only remove the .npmrc we created — never delete one written by a prior
    # step (e.g. setup-node), which the publish above may have depended on.
    if [[ "$wrote_npmrc" == "true" ]]; then
      rm -f .npmrc
    fi
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
