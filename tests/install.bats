#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/install.sh"

  # A throwaway project directory to drop lockfiles into.
  REPO="$(mktemp -d)"

  mk_lock() {
    printf '' > "$REPO/$1"
  }
}

teardown() {
  rm -rf "$REPO"
}

# ── detect_package_manager ───────────────────────────────────────

@test "detect_package_manager: npm from package-lock.json" {
  mk_lock "package-lock.json"
  run detect_package_manager "$REPO"
  [[ "$output" == "npm" ]]
}

@test "detect_package_manager: npm from npm-shrinkwrap.json" {
  mk_lock "npm-shrinkwrap.json"
  run detect_package_manager "$REPO"
  [[ "$output" == "npm" ]]
}

@test "detect_package_manager: yarn from yarn.lock" {
  mk_lock "yarn.lock"
  run detect_package_manager "$REPO"
  [[ "$output" == "yarn" ]]
}

@test "detect_package_manager: pnpm from pnpm-lock.yaml" {
  mk_lock "pnpm-lock.yaml"
  run detect_package_manager "$REPO"
  [[ "$output" == "pnpm" ]]
}

@test "detect_package_manager: bun from bun.lock" {
  mk_lock "bun.lock"
  run detect_package_manager "$REPO"
  [[ "$output" == "bun" ]]
}

@test "detect_package_manager: bun from bun.lockb" {
  mk_lock "bun.lockb"
  run detect_package_manager "$REPO"
  [[ "$output" == "bun" ]]
}

@test "detect_package_manager: none when no lockfile present" {
  run detect_package_manager "$REPO"
  [[ "$output" == "none" ]]
}

@test "detect_package_manager: npm lockfile wins over others" {
  mk_lock "package-lock.json"
  mk_lock "yarn.lock"
  mk_lock "pnpm-lock.yaml"
  run detect_package_manager "$REPO"
  [[ "$output" == "npm" ]]
}

@test "detect_package_manager: defaults to current dir" {
  run detect_package_manager
  [[ "$output" == "none" ]]
}

# ── install_command ──────────────────────────────────────────────

@test "install_command: npm uses ci" {
  run install_command "npm"
  [[ "$output" == "npm ci" ]]
}

@test "install_command: yarn uses frozen lockfile" {
  run install_command "yarn"
  [[ "$output" == "yarn install --frozen-lockfile" ]]
}

@test "install_command: pnpm uses frozen lockfile" {
  run install_command "pnpm"
  [[ "$output" == "pnpm install --frozen-lockfile" ]]
}

@test "install_command: bun uses frozen lockfile" {
  run install_command "bun"
  [[ "$output" == "bun install --frozen-lockfile" ]]
}

@test "install_command: none falls back to npm install" {
  run install_command "none"
  [[ "$output" == "npm install" ]]
}

@test "install_command: unknown value falls back to npm install" {
  run install_command "deno"
  [[ "$output" == "npm install" ]]
}
