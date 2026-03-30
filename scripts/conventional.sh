#!/usr/bin/env bash
# Conventional commit parsing and semver logic

set -euo pipefail

# Parse a version string into major.minor.patch components
# Usage: parse_version "1.2.3" → sets VER_MAJOR, VER_MINOR, VER_PATCH
parse_version() {
  local version="$1"
  # Strip any prefix (v, etc.)
  version="${version#"$INPUT_VERSION_PREFIX"}"
  VER_MAJOR="${version%%.*}"
  local rest="${version#*.}"
  VER_MINOR="${rest%%.*}"
  VER_PATCH="${rest#*.}"
}

# Get the latest tag matching the version prefix
get_last_tag() {
  local tags
  tags=$(git tag --list "${INPUT_VERSION_PREFIX}*" --sort=-v:refname 2>/dev/null || true)

  if [[ -z "$tags" ]]; then
    echo ""
    return
  fi

  echo "$tags" | head -n 1
}

# Determine the bump type from a list of conventional commit messages
# Reads commit messages from stdin, one per line
# Returns: major, minor, or patch
determine_bump() {
  local bump="patch"

  while IFS= read -r message; do
    # Check for breaking changes
    if [[ "$message" =~ ^[a-zA-Z]+(\(.+\))?!: ]] || [[ "$message" =~ BREAKING[[:space:]]CHANGE ]]; then
      echo "major"
      return
    fi

    # Check for features
    if [[ "$message" =~ ^feat(\(.+\))?: ]]; then
      bump="minor"
    fi
  done

  echo "$bump"
}

# Calculate the next version based on the bump type
# Usage: next_version "1.2.3" "minor" → "1.3.0"
next_version() {
  local current="$1"
  local bump="$2"

  if [[ -z "$current" ]]; then
    # No previous version — start at 0.1.0 for minor/patch, 1.0.0 for major
    case "$bump" in
      major) echo "1.0.0" ;;
      *)     echo "0.1.0" ;;
    esac
    return
  fi

  parse_version "$current"

  case "$bump" in
    major)
      echo "$(( VER_MAJOR + 1 )).0.0"
      ;;
    minor)
      echo "${VER_MAJOR}.$(( VER_MINOR + 1 )).0"
      ;;
    patch)
      echo "${VER_MAJOR}.${VER_MINOR}.$(( VER_PATCH + 1 ))"
      ;;
  esac
}

# Get commits since a tag (or all commits if no tag)
# Returns commit subjects, one per line
get_commits_since_tag() {
  local tag="$1"

  if [[ -z "$tag" ]]; then
    git log --format="%H %s" --no-merges
  else
    git log "${tag}..HEAD" --format="%H %s" --no-merges
  fi
}

# Categorize a conventional commit message
# Returns the category (Added, Fixed, Changed, Removed, Deprecated, Security, Other)
categorize_commit() {
  local message="$1"

  # Strip the breaking change indicator for categorization
  local clean="${message/\!/}"

  if [[ "$clean" =~ ^feat(\(.+\))?: ]]; then
    echo "Added"
  elif [[ "$clean" =~ ^fix(\(.+\))?: ]]; then
    echo "Fixed"
  elif [[ "$clean" =~ ^docs(\(.+\))?: ]]; then
    echo "Documentation"
  elif [[ "$clean" =~ ^refactor(\(.+\))?: ]]; then
    echo "Changed"
  elif [[ "$clean" =~ ^perf(\(.+\))?: ]]; then
    echo "Changed"
  elif [[ "$clean" =~ ^chore(\(.+\))?: ]]; then
    echo "Changed"
  elif [[ "$clean" =~ ^style(\(.+\))?: ]]; then
    echo "Changed"
  elif [[ "$clean" =~ ^test(\(.+\))?: ]]; then
    echo "Other"
  elif [[ "$clean" =~ ^ci(\(.+\))?: ]]; then
    echo "Other"
  elif [[ "$clean" =~ ^build(\(.+\))?: ]]; then
    echo "Changed"
  elif [[ "$clean" =~ ^revert(\(.+\))?: ]]; then
    echo "Reverted"
  else
    echo "Other"
  fi
}

# Extract the human-readable description from a conventional commit message
# "feat(scope): add new feature" → "Add new feature"
extract_description() {
  local message="$1"

  if [[ "$message" =~ ^[a-zA-Z]+(\(.+\))?!?:[[:space:]]*(.*) ]]; then
    local desc="${BASH_REMATCH[2]}"
    # Capitalize first letter
    echo "$(echo "${desc:0:1}" | tr '[:lower:]' '[:upper:]')${desc:1}"
  else
    echo "$message"
  fi
}
