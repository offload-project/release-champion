#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/npm-auth.sh"

  # A throwaway directory to write .npmrc into.
  REPO="$(mktemp -d)"
}

teardown() {
  rm -rf "$REPO"
}

# ── npm_auth_mode ────────────────────────────────────────────────

@test "npm_auth_mode: token when a token is provided" {
  run npm_auth_mode "npm_abc123" ""
  [[ "$output" == "token" ]]
}

@test "npm_auth_mode: token wins even when OIDC is also available" {
  run npm_auth_mode "npm_abc123" "https://pipelines.actions.githubusercontent.com/..."
  [[ "$output" == "token" ]]
}

@test "npm_auth_mode: oidc when no token but OIDC url is set" {
  run npm_auth_mode "" "https://pipelines.actions.githubusercontent.com/..."
  [[ "$output" == "oidc" ]]
}

@test "npm_auth_mode: external when neither token nor OIDC" {
  run npm_auth_mode "" ""
  [[ "$output" == "external" ]]
}

# ── registry_host ────────────────────────────────────────────────

@test "registry_host: strips scheme from the default registry" {
  run registry_host "https://registry.npmjs.org"
  [[ "$output" == "//registry.npmjs.org" ]]
}

@test "registry_host: strips a trailing slash" {
  run registry_host "https://npm.pkg.github.com/"
  [[ "$output" == "//npm.pkg.github.com" ]]
}

# ── write_npmrc: token mode ──────────────────────────────────────

@test "write_npmrc: token mode writes auth + registry and reports true" {
  run write_npmrc "token" "https://npm.pkg.github.com" "ghp_secret" "$REPO"
  [[ "$output" == "true" ]]
  [[ -f "$REPO/.npmrc" ]]
  grep -qx "//npm.pkg.github.com/:_authToken=ghp_secret" "$REPO/.npmrc"
  grep -qx "registry=https://npm.pkg.github.com" "$REPO/.npmrc"
}

# ── write_npmrc: oidc mode ───────────────────────────────────────

@test "write_npmrc: oidc mode writes registry only and reports true" {
  run write_npmrc "oidc" "https://registry.npmjs.org" "" "$REPO"
  [[ "$output" == "true" ]]
  [[ -f "$REPO/.npmrc" ]]
  grep -qx "registry=https://registry.npmjs.org" "$REPO/.npmrc"
  # No auth token must be written for OIDC.
  ! grep -q "_authToken" "$REPO/.npmrc"
}

# ── write_npmrc: external mode ───────────────────────────────────

@test "write_npmrc: external mode writes nothing and reports false" {
  run write_npmrc "external" "https://registry.npmjs.org" "" "$REPO"
  [[ "$output" == "false" ]]
  [[ ! -f "$REPO/.npmrc" ]]
}

@test "write_npmrc: external mode does not clobber an existing .npmrc" {
  printf '//npm.pkg.github.com/:_authToken=preexisting\n' > "$REPO/.npmrc"
  run write_npmrc "external" "https://npm.pkg.github.com" "" "$REPO"
  [[ "$output" == "false" ]]
  # The file written by a prior step (e.g. setup-node) is left intact.
  grep -qx "//npm.pkg.github.com/:_authToken=preexisting" "$REPO/.npmrc"
}
