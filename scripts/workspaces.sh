#!/usr/bin/env bash
# Workspace discovery for monorepo (fixed/locked) publishing.
#
# "Fixed mode" means every package shares the single version computed from
# conventional commits — there is still one tag and one CHANGELOG.md. These
# helpers only answer two questions: which package directories exist, and which
# of those are publishable.

set -euo pipefail

# Read the workspace glob patterns from a package.json's "workspaces" field.
# Handles both the array form (["packages/*"]) and the object form
# ({ "packages": ["packages/*"] }). Emits one pattern per line; emits nothing
# when there is no workspaces field.
# Usage: read_workspace_patterns [package.json path]
read_workspace_patterns() {
  local pkg_json="${1:-package.json}"
  [[ -f "$pkg_json" ]] || return 0

  node -e '
    const fs = require("fs");
    const pkg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    let ws = pkg.workspaces;
    if (!ws) process.exit(0);
    if (!Array.isArray(ws)) ws = ws.packages || [];
    for (const p of ws) console.log(p);
  ' "$pkg_json"
}

# Discover all workspace package directories under a root.
# Expands each workspace glob and emits every directory that contains a
# package.json. Emits nothing when the root declares no workspaces.
# Usage: discover_packages [root dir]
discover_packages() {
  local root="${1:-.}"
  local patterns
  patterns=$(read_workspace_patterns "$root/package.json")
  [[ -z "$patterns" ]] && return 0

  local pattern dir
  # nullglob so a pattern that matches nothing expands to nothing rather than
  # the literal glob string.
  shopt -s nullglob
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    for dir in "$root"/$pattern/; do
      dir="${dir%/}"
      [[ -f "$dir/package.json" ]] && echo "$dir"
    done
  done <<< "$patterns"
  shopt -u nullglob
}

# Whether a package directory is marked private (and therefore must not be
# published). Returns success (0) when private.
# Usage: is_private_package <dir>
is_private_package() {
  local dir="$1"
  [[ -f "$dir/package.json" ]] || return 1
  node -e '
    const fs = require("fs");
    const pkg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    process.exit(pkg.private === true ? 0 : 1);
  ' "$dir/package.json"
}

# Whether a package has a scoped name (@scope/name), which npm publishes as
# restricted by default — first publish needs --access public.
# Usage: is_scoped_package <dir>
is_scoped_package() {
  local dir="$1"
  [[ -f "$dir/package.json" ]] || return 1
  node -e '
    const fs = require("fs");
    const pkg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    process.exit(typeof pkg.name === "string" && pkg.name.startsWith("@") ? 0 : 1);
  ' "$dir/package.json"
}
