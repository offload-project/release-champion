#!/usr/bin/env bash
# Changelog generation — GitHub release-notes style with PR links

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/conventional.sh"

# Resolve the PR number associated with a commit SHA via the GitHub API
# Usage: resolve_pr_number "abc123"
# Returns: PR number or empty string
resolve_pr_number() {
  local sha="$1"
  local pr_num

  pr_num=$(gh api "repos/${REPO}/commits/${sha}/pulls" \
    --jq '.[0].number // empty' 2>/dev/null || true)

  echo "$pr_num"
}

# Generate changelog content for a new version
# Usage: generate_changelog "v1.2.3" "v1.1.0"
# Args: new_version, last_tag
# Outputs changelog markdown to stdout
generate_changelog() {
  local new_version="$1"
  local last_tag="$2"
  local today
  today=$(date +%Y-%m-%d)

  local -A categories
  categories=(
    [Added]=""
    [Fixed]=""
    [Changed]=""
    [Deprecated]=""
    [Removed]=""
    [Security]=""
    [Documentation]=""
    [Reverted]=""
    [Other]=""
  )

  # Process each commit
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local sha="${line%% *}"
    local message="${line#* }"
    local category
    category=$(categorize_commit "$message")
    local description
    description=$(extract_description "$message")

    # Try to resolve PR number
    local pr_num
    pr_num=$(resolve_pr_number "$sha")

    local entry
    if [[ -n "$pr_num" ]]; then
      entry="- ${description} [#${pr_num}](https://github.com/${REPO}/pull/${pr_num})"
    else
      entry="- ${description} ([${sha:0:7}](https://github.com/${REPO}/commit/${sha}))"
    fi

    categories[$category]+="${entry}"$'\n'
  done < <(get_commits_since_tag "$last_tag")

  # Build the changelog section
  local changelog_section=""
  changelog_section+="## ${INPUT_VERSION_PREFIX}${new_version} - ${today}"$'\n'$'\n'

  # Output categories in order, skipping empty ones
  local category_order=("Added" "Fixed" "Changed" "Deprecated" "Removed" "Security" "Documentation" "Reverted" "Other")

  for category in "${category_order[@]}"; do
    if [[ -n "${categories[$category]:-}" ]]; then
      changelog_section+="### ${category}"$'\n'
      changelog_section+="${categories[$category]}"$'\n'
    fi
  done

  echo "$changelog_section"
}

# Update or create the CHANGELOG.md file
# Usage: update_changelog "v1.2.3" "v1.1.0"
update_changelog() {
  local new_version="$1"
  local last_tag="$2"

  local new_content
  new_content=$(generate_changelog "$new_version" "$last_tag")

  if [[ -f "CHANGELOG.md" ]]; then
    local existing
    existing=$(cat CHANGELOG.md)

    # Check if the file starts with a top-level heading
    if [[ "$existing" =~ ^#[[:space:]] ]]; then
      # Insert new content after the first line (the title)
      local first_line
      first_line=$(head -n 1 CHANGELOG.md)
      local rest
      rest=$(tail -n +2 CHANGELOG.md)

      cat > CHANGELOG.md <<EOF
${first_line}

${new_content}
${rest}
EOF
    else
      # Prepend new content with a title
      cat > CHANGELOG.md <<EOF
# Changelog

${new_content}
${existing}
EOF
    fi
  else
    cat > CHANGELOG.md <<EOF
# Changelog

${new_content}
EOF
  fi
}
