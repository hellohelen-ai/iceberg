#!/usr/bin/env sh
# SessionStart hook. Prints one line when a newer iceberg tag exists, and
# nothing at all otherwise.
#
# Nothing here blocks the session. The network call runs detached and writes a
# cache; this run only ever reads the cache the *previous* session left behind.
# A plugin whose whole pitch is fewer tokens has no business spending your
# startup time, or your context, on its own release notes.
set -eu

REPO="hellohelen-ai/iceberg"
DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/iceberg"
CACHE="$CACHE_DIR/update.json"
STALE_SECONDS=86400

INSTALLED=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$DIR/.claude-plugin/plugin.json" 2>/dev/null | head -1)
[ -n "$INSTALLED" ] || exit 0

mkdir -p "$CACHE_DIR" 2>/dev/null || exit 0

# Report first, from whatever the last check left. Never make the user wait.
if [ -f "$CACHE" ]; then
  LATEST=$(sed -n 's/.*"latest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CACHE" | head -1)
  if [ -n "$LATEST" ] && [ "$LATEST" != "$INSTALLED" ]; then
    # Only newer, never older — a local build ahead of the tag is not an update.
    NEWEST=$(printf '%s\n%s\n' "$INSTALLED" "$LATEST" | sort -V | tail -1)
    [ "$NEWEST" = "$LATEST" ] && \
      echo "iceberg $INSTALLED → $LATEST available. Run /iceberg:update."
  fi
fi

# Refresh in the background, at most once a day.
if [ -f "$CACHE" ]; then
  NOW=$(date +%s)
  THEN=$(sed -n 's/.*"checked_at"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$CACHE" | head -1)
  [ -n "$THEN" ] && [ "$((NOW - THEN))" -lt "$STALE_SECONDS" ] && exit 0
fi

command -v curl >/dev/null 2>&1 || exit 0
(
  LATEST=$(curl -sS --max-time 10 "https://api.github.com/repos/$REPO/tags" 2>/dev/null \
    | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([0-9][^"]*\)".*/\1/p' \
    | sort -V | tail -1)
  [ -n "$LATEST" ] || exit 0
  printf '{"latest":"%s","checked_at":%s}\n' "$LATEST" "$(date +%s)" > "$CACHE.tmp" \
    && mv "$CACHE.tmp" "$CACHE"
) >/dev/null 2>&1 &

exit 0
