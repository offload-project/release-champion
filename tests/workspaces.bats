#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/workspaces.sh"

  # Build a throwaway monorepo to exercise discovery against.
  REPO="$(mktemp -d)"

  mk_pkg() {
    local dir="$1" json="$2"
    mkdir -p "$REPO/$dir"
    printf '%s' "$json" > "$REPO/$dir/package.json"
  }
}

teardown() {
  rm -rf "$REPO"
}

# ── read_workspace_patterns ──────────────────────────────────────

@test "read_workspace_patterns: array form" {
  mk_pkg "." '{"name":"root","workspaces":["packages/*","tools/cli"]}'
  run read_workspace_patterns "$REPO/package.json"
  [[ "${lines[0]}" == "packages/*" ]]
  [[ "${lines[1]}" == "tools/cli" ]]
}

@test "read_workspace_patterns: object form" {
  mk_pkg "." '{"name":"root","workspaces":{"packages":["libs/*"]}}'
  run read_workspace_patterns "$REPO/package.json"
  [[ "${lines[0]}" == "libs/*" ]]
}

@test "read_workspace_patterns: no workspaces field emits nothing" {
  mk_pkg "." '{"name":"root"}'
  run read_workspace_patterns "$REPO/package.json"
  [[ -z "$output" ]]
}

@test "read_workspace_patterns: missing file emits nothing" {
  run read_workspace_patterns "$REPO/does-not-exist.json"
  [[ -z "$output" ]]
}

# ── discover_packages ────────────────────────────────────────────

@test "discover_packages: expands a glob to each package dir" {
  mk_pkg "." '{"name":"root","workspaces":["packages/*"]}'
  mk_pkg "packages/a" '{"name":"a","version":"1.0.0"}'
  mk_pkg "packages/b" '{"name":"b","version":"1.0.0"}'

  run discover_packages "$REPO"
  [[ "$output" == *"packages/a"* ]]
  [[ "$output" == *"packages/b"* ]]
  [[ "${#lines[@]}" -eq 2 ]]
}

@test "discover_packages: ignores glob matches without a package.json" {
  mk_pkg "." '{"name":"root","workspaces":["packages/*"]}'
  mk_pkg "packages/a" '{"name":"a","version":"1.0.0"}'
  mkdir -p "$REPO/packages/not-a-pkg"

  run discover_packages "$REPO"
  [[ "$output" == *"packages/a"* ]]
  [[ "$output" != *"not-a-pkg"* ]]
  [[ "${#lines[@]}" -eq 1 ]]
}

@test "discover_packages: handles an explicit (non-glob) path" {
  mk_pkg "." '{"name":"root","workspaces":["tools/cli"]}'
  mk_pkg "tools/cli" '{"name":"cli","version":"1.0.0"}'

  run discover_packages "$REPO"
  [[ "$output" == *"tools/cli"* ]]
  [[ "${#lines[@]}" -eq 1 ]]
}

@test "discover_packages: no workspaces field emits nothing" {
  mk_pkg "." '{"name":"root","version":"1.0.0"}'
  run discover_packages "$REPO"
  [[ -z "$output" ]]
}

# ── is_private_package ───────────────────────────────────────────

@test "is_private_package: true when private is set" {
  mk_pkg "p" '{"name":"p","private":true}'
  run is_private_package "$REPO/p"
  [[ "$status" -eq 0 ]]
}

@test "is_private_package: false when private is absent" {
  mk_pkg "p" '{"name":"p","version":"1.0.0"}'
  run is_private_package "$REPO/p"
  [[ "$status" -ne 0 ]]
}

@test "is_private_package: false when private is explicitly false" {
  mk_pkg "p" '{"name":"p","private":false}'
  run is_private_package "$REPO/p"
  [[ "$status" -ne 0 ]]
}

# ── is_scoped_package ────────────────────────────────────────────

@test "is_scoped_package: true for @scope/name" {
  mk_pkg "p" '{"name":"@acme/widget","version":"1.0.0"}'
  run is_scoped_package "$REPO/p"
  [[ "$status" -eq 0 ]]
}

@test "is_scoped_package: false for an unscoped name" {
  mk_pkg "p" '{"name":"widget","version":"1.0.0"}'
  run is_scoped_package "$REPO/p"
  [[ "$status" -ne 0 ]]
}
