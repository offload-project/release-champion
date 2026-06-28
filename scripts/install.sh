#!/usr/bin/env bash
# Package-manager detection for the pre-build dependency install step.
#
# The publish flow always shells out to `npm publish`, but the *install* that
# precedes a user's build command should honour whatever package manager the
# repo actually uses — running `npm ci` against a yarn/pnpm/bun project ignores
# the lockfile and defeats reproducibility. We pick the manager from the
# lockfile and run its frozen-lockfile install.

set -euo pipefail

# Detect the package manager for a project directory from its lockfile.
# Echoes one of: npm, yarn, pnpm, bun — or "none" when no lockfile is present.
# Usage: detect_package_manager [dir]
detect_package_manager() {
  local dir="${1:-.}"
  if [[ -f "$dir/package-lock.json" || -f "$dir/npm-shrinkwrap.json" ]]; then
    echo "npm"
  elif [[ -f "$dir/yarn.lock" ]]; then
    echo "yarn"
  elif [[ -f "$dir/pnpm-lock.yaml" ]]; then
    echo "pnpm"
  elif [[ -f "$dir/bun.lock" || -f "$dir/bun.lockb" ]]; then
    echo "bun"
  else
    echo "none"
  fi
}

# Echo the reproducible (frozen-lockfile) install command for a detected manager.
# With no lockfile ("none") we fall back to a plain `npm install`, since `npm ci`
# requires a lockfile to exist.
# Usage: install_command <npm|yarn|pnpm|bun|none>
install_command() {
  case "$1" in
    npm)  echo "npm ci" ;;
    yarn) echo "yarn install --frozen-lockfile" ;;
    pnpm) echo "pnpm install --frozen-lockfile" ;;
    bun)  echo "bun install --frozen-lockfile" ;;
    *)    echo "npm install" ;;
  esac
}
