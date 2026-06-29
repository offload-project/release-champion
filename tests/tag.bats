#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/tag.sh"

  # Stub `gh` on PATH: record every call (one arg per line) and emit a tag-object
  # SHA for the git/tags endpoint so create_tag can read it back.
  STUB_DIR="$(mktemp -d)"
  export GH_CALLS="$STUB_DIR/calls.log"

  cat > "$STUB_DIR/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$GH_CALLS"
case "$*" in
  *git/tags*) echo '{"sha":"TAGOBJ123"}' ;;
  *)          echo '{}' ;;
esac
EOF
  chmod +x "$STUB_DIR/gh"
  PATH="$STUB_DIR:$PATH"
}

teardown() {
  rm -rf "$STUB_DIR"
}

@test "create_tag: succeeds and hits both API endpoints" {
  run create_tag "owner/repo" "v1.2.3" "abc123" "Release v1.2.3"
  [ "$status" -eq 0 ]
  grep -Fxq "repos/owner/repo/git/tags" "$GH_CALLS"
  grep -Fxq "repos/owner/repo/git/refs" "$GH_CALLS"
}

@test "create_tag: creates the tag object from the commit SHA" {
  create_tag "owner/repo" "v1.2.3" "abc123" "Release v1.2.3"
  grep -Fxq "tag=v1.2.3" "$GH_CALLS"
  grep -Fxq "object=abc123" "$GH_CALLS"
  grep -Fxq "type=commit" "$GH_CALLS"
  grep -Fxq "message=Release v1.2.3" "$GH_CALLS"
}

@test "create_tag: points the ref at the returned tag-object SHA" {
  create_tag "owner/repo" "v1.2.3" "abc123" "Release v1.2.3"
  grep -Fxq "ref=refs/tags/v1.2.3" "$GH_CALLS"
  # The ref must use the tag object's SHA from the first call, not the commit SHA.
  grep -Fxq "sha=TAGOBJ123" "$GH_CALLS"
  ! grep -Fxq "sha=abc123" "$GH_CALLS"
}

@test "create_tag: never shells out to git push" {
  # The whole point of the API approach is to avoid `git push`. Stub git too and
  # assert it is not invoked.
  cat > "$STUB_DIR/git" <<'EOF'
#!/usr/bin/env bash
echo "git $*" >> "$GH_CALLS"
EOF
  chmod +x "$STUB_DIR/git"

  create_tag "owner/repo" "v1.2.3" "abc123" "Release v1.2.3"
  ! grep -q "^git " "$GH_CALLS"
}
