#!/usr/bin/env bash
# Changelog generation — PR-based with GitHub links

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/conventional.sh"

# Resolve the PR associated with a commit SHA via the GitHub API
# Usage: resolve_pr "abc123"
# Returns: "number<TAB>title" or empty string
resolve_pr() {
  local sha="$1"

  gh api "repos/${REPO}/commits/${sha}/pulls" \
    --jq '.[0] | select(. != null) | "\(.number)\t\(.title)"' 2>/dev/null || true
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

  # Track seen PR numbers to avoid duplicates
  local -A seen_prs

  # Process each commit, grouping by PR
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local sha="${line%% *}"
    local message="${line#* }"

    # Try to resolve PR
    local pr_info
    pr_info=$(resolve_pr "$sha")

    if [[ -n "$pr_info" ]]; then
      local pr_num pr_title
      pr_num="${pr_info%%	*}"
      pr_title="${pr_info#*	}"

      # Skip if we've already seen this PR
      if [[ -n "${seen_prs[$pr_num]:-}" ]]; then
        continue
      fi
      seen_prs[$pr_num]=1

      local category
      category=$(categorize_commit "$pr_title")
      local description
      description=$(extract_description "$pr_title")

      local entry="- ${description} [#${pr_num}](https://github.com/${REPO}/pull/${pr_num})"
      categories[$category]+="${entry}"$'\n'
    else
      # No associated PR — fall back to commit entry
      local category
      category=$(categorize_commit "$message")
      local description
      description=$(extract_description "$message")

      local entry="- ${description} ([${sha:0:7}](https://github.com/${REPO}/commit/${sha}))"
      categories[$category]+="${entry}"$'\n'
    fi
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
