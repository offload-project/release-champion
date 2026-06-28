#!/usr/bin/env bash
# npm authentication for the publish step.
#
# A missing npm-token does NOT imply Trusted Publishers. OIDC is only available
# when the workflow granted `id-token: write`, which GitHub signals by setting
# ACTIONS_ID_TOKEN_REQUEST_URL. With neither a token nor OIDC, the publish must
# rely on whatever npm auth already exists (e.g. setup-node with NODE_AUTH_TOKEN,
# or a pre-existing ~/.npmrc) — so we must not write/clobber a project .npmrc.

set -euo pipefail

# Decide the auth mode for publishing. Echoes one of:
#   token    - an explicit npm-token was provided
#   oidc     - no token, but OIDC is available (Trusted Publishers)
#   external - neither; rely on pre-existing npm auth (don't clobber .npmrc)
# Usage: npm_auth_mode <npm-token> <oidc-request-url>
npm_auth_mode() {
  local token="$1" oidc_url="$2"
  if [[ -n "$token" ]]; then
    echo "token"
  elif [[ -n "$oidc_url" ]]; then
    echo "oidc"
  else
    echo "external"
  fi
}

# Normalise a registry URL into the host form npm uses as an .npmrc auth key,
# e.g. https://npm.pkg.github.com/ -> //npm.pkg.github.com
# Usage: registry_host <registry-url>
registry_host() {
  echo "$1" | sed 's|https:||' | sed 's|/$||'
}

# Write the project .npmrc for the given auth mode, into <dir> (default ".").
# Echoes "true" when a .npmrc was written, "false" when it was intentionally
# left untouched (external auth). Does not emit status logs — the caller owns
# user-facing messaging.
# Usage: write_npmrc <mode> <registry> <token> [dir]
write_npmrc() {
  local mode="$1" registry="$2" token="$3" dir="${4:-.}"
  local host
  host=$(registry_host "$registry")

  case "$mode" in
    token)
      printf '%s/:_authToken=%s\n' "$host" "$token" > "$dir/.npmrc"
      printf 'registry=%s\n' "$registry" >> "$dir/.npmrc"
      echo "true"
      ;;
    oidc)
      # OIDC: npm performs the token exchange at publish time, so we only need
      # the registry set. Requires npm >= 11.5.1.
      printf 'registry=%s\n' "$registry" > "$dir/.npmrc"
      echo "true"
      ;;
    *)
      echo "false"
      ;;
  esac
}
