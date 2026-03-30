#!/usr/bin/env bash
# Entry point — detects which phase to run based on PR context

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure the PR was actually merged
if [[ "$PR_MERGED" != "true" ]]; then
  echo "PR was not merged — skipping."
  exit 0
fi

# Phase detection
if [[ "$PR_HEAD_REF" == release/* ]]; then
  # Phase 2: Release PR was merged → create tag + release
  echo "Detected release PR merge (branch: ${PR_HEAD_REF})"
  bash "$SCRIPT_DIR/finalize-release.sh"

elif echo "$PR_LABELS" | tr ',' '\n' | grep -qx "$INPUT_RELEASE_LABEL"; then
  # Phase 1: Labeled PR was merged → create release PR
  echo "Detected labeled PR merge (label: ${INPUT_RELEASE_LABEL})"
  bash "$SCRIPT_DIR/create-release-pr.sh"

else
  echo "PR does not have the '${INPUT_RELEASE_LABEL}' label and is not a release branch — skipping."
  exit 0
fi
