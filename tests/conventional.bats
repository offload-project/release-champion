#!/usr/bin/env bats

setup() {
  # Provide defaults that the sourced script expects
  export INPUT_VERSION_PREFIX="v"

  source "$BATS_TEST_DIRNAME/../scripts/conventional.sh"
}

# ── parse_version ────────────────────────────────────────────────

@test "parse_version: splits major.minor.patch" {
  parse_version "v2.5.13"
  [[ "$VER_MAJOR" == "2" ]]
  [[ "$VER_MINOR" == "5" ]]
  [[ "$VER_PATCH" == "13" ]]
}

@test "parse_version: works without prefix" {
  INPUT_VERSION_PREFIX=""
  parse_version "0.1.0"
  [[ "$VER_MAJOR" == "0" ]]
  [[ "$VER_MINOR" == "1" ]]
  [[ "$VER_PATCH" == "0" ]]
}

@test "parse_version: handles custom prefix" {
  INPUT_VERSION_PREFIX="release-"
  parse_version "release-3.2.1"
  [[ "$VER_MAJOR" == "3" ]]
  [[ "$VER_MINOR" == "2" ]]
  [[ "$VER_PATCH" == "1" ]]
}

# ── determine_bump ───────────────────────────────────────────────

@test "determine_bump: patch for fix commits" {
  result=$(echo "fix: correct typo" | determine_bump)
  [[ "$result" == "patch" ]]
}

@test "determine_bump: minor for feat commits" {
  result=$(printf "fix: something\nfeat: add feature\n" | determine_bump)
  [[ "$result" == "minor" ]]
}

@test "determine_bump: major for breaking change with bang" {
  result=$(echo "feat!: redesign API" | determine_bump)
  [[ "$result" == "major" ]]
}

@test "determine_bump: major for breaking change with scope and bang" {
  result=$(echo "refactor(core)!: rewrite engine" | determine_bump)
  [[ "$result" == "major" ]]
}

@test "determine_bump: major for BREAKING CHANGE in message" {
  result=$(echo "feat: something BREAKING CHANGE" | determine_bump)
  [[ "$result" == "major" ]]
}

@test "determine_bump: major trumps minor" {
  result=$(printf "feat: new thing\nfix!: break stuff\n" | determine_bump)
  [[ "$result" == "major" ]]
}

@test "determine_bump: patch for non-conventional commits" {
  result=$(echo "update readme" | determine_bump)
  [[ "$result" == "patch" ]]
}

@test "determine_bump: patch for chore commits" {
  result=$(echo "chore: update deps" | determine_bump)
  [[ "$result" == "patch" ]]
}

# ── next_version ─────────────────────────────────────────────────

@test "next_version: patch bump" {
  result=$(next_version "v1.2.3" "patch")
  [[ "$result" == "1.2.4" ]]
}

@test "next_version: minor bump resets patch" {
  result=$(next_version "v1.2.3" "minor")
  [[ "$result" == "1.3.0" ]]
}

@test "next_version: major bump resets minor and patch" {
  result=$(next_version "v1.2.3" "major")
  [[ "$result" == "2.0.0" ]]
}

@test "next_version: no previous version — minor defaults to 0.1.0" {
  result=$(next_version "" "minor")
  [[ "$result" == "0.1.0" ]]
}

@test "next_version: no previous version — patch defaults to 0.1.0" {
  result=$(next_version "" "patch")
  [[ "$result" == "0.1.0" ]]
}

@test "next_version: no previous version — major defaults to 1.0.0" {
  result=$(next_version "" "major")
  [[ "$result" == "1.0.0" ]]
}

@test "next_version: bump from 0.x" {
  result=$(next_version "v0.3.7" "minor")
  [[ "$result" == "0.4.0" ]]
}

# ── categorize_commit ────────────────────────────────────────────

@test "categorize_commit: feat → Added" {
  result=$(categorize_commit "feat: add login")
  [[ "$result" == "Added" ]]
}

@test "categorize_commit: feat with scope → Added" {
  result=$(categorize_commit "feat(auth): add login")
  [[ "$result" == "Added" ]]
}

@test "categorize_commit: fix → Fixed" {
  result=$(categorize_commit "fix: null pointer")
  [[ "$result" == "Fixed" ]]
}

@test "categorize_commit: docs → Documentation" {
  result=$(categorize_commit "docs: update readme")
  [[ "$result" == "Documentation" ]]
}

@test "categorize_commit: refactor → Changed" {
  result=$(categorize_commit "refactor: simplify parser")
  [[ "$result" == "Changed" ]]
}

@test "categorize_commit: perf → Changed" {
  result=$(categorize_commit "perf: optimize query")
  [[ "$result" == "Changed" ]]
}

@test "categorize_commit: chore → Changed" {
  result=$(categorize_commit "chore: update deps")
  [[ "$result" == "Changed" ]]
}

@test "categorize_commit: test → Other" {
  result=$(categorize_commit "test: add unit tests")
  [[ "$result" == "Other" ]]
}

@test "categorize_commit: ci → Other" {
  result=$(categorize_commit "ci: fix pipeline")
  [[ "$result" == "Other" ]]
}

@test "categorize_commit: revert → Reverted" {
  result=$(categorize_commit "revert: undo feature")
  [[ "$result" == "Reverted" ]]
}

@test "categorize_commit: build → Changed" {
  result=$(categorize_commit "build: upgrade webpack")
  [[ "$result" == "Changed" ]]
}

@test "categorize_commit: breaking feat still categorizes as Added" {
  result=$(categorize_commit "feat!: redesign API")
  [[ "$result" == "Added" ]]
}

@test "categorize_commit: non-conventional → Other" {
  result=$(categorize_commit "random commit message")
  [[ "$result" == "Other" ]]
}

# ── extract_description ──────────────────────────────────────────

@test "extract_description: strips type prefix" {
  result=$(extract_description "feat: add login page")
  [[ "$result" == "Add login page" ]]
}

@test "extract_description: strips type and scope" {
  result=$(extract_description "fix(auth): handle expired tokens")
  [[ "$result" == "Handle expired tokens" ]]
}

@test "extract_description: strips breaking indicator" {
  result=$(extract_description "feat!: redesign the API")
  [[ "$result" == "Redesign the API" ]]
}

@test "extract_description: capitalizes first letter" {
  result=$(extract_description "fix: lowercase start")
  [[ "$result" == "Lowercase start" ]]
}

@test "extract_description: returns raw message for non-conventional" {
  result=$(extract_description "just some message")
  [[ "$result" == "just some message" ]]
}