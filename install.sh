#!/usr/bin/env bash
# iceberg — make your coding agent laconic.
# Usage:  ./install.sh [target ...]   targets: claude codex cursor windsurf copilot agents all
# Adds a marked block to the agent's instruction file. Re-runnable. Remove with ./uninstall.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHORT="$HERE/short.md"
BEGIN="<!-- iceberg:begin -->"
END="<!-- iceberg:end -->"

[ -f "$SHORT" ] || { echo "missing short.md"; exit 1; }

write_block() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  # strip any previous block
  if grep -qF "$BEGIN" "$file"; then
    awk -v b="$BEGIN" -v e="$END" '
      index($0,b){skip=1} !skip{print} index($0,e){skip=0}
    ' "$file" > "$file.iceberg.tmp"
    mv "$file.iceberg.tmp" "$file"
  fi
  { printf '\n%s\n' "$BEGIN"; cat "$SHORT"; printf '%s\n' "$END"; } >> "$file"
  echo "  updated $file"
}

install_claude() {
  echo "claude code:"
  echo "  run these two commands in Claude Code:"
  echo "    /plugin marketplace add hellohelen-ai/iceberg"
  echo "    /plugin install iceberg@iceberg"
  echo "  to try it before installing:  claude --plugin-dir $HERE"
}

# Codex does not read .codex/hooks.json, and it does not read hooks from a
# project directory at all. Hooks live in $CODEX_HOME/config.toml (user scope,
# ~/.codex/config.toml by default). Verified against codex-cli 0.153.2: a
# project .codex/hooks.json and a project .codex/config.toml both fire nothing;
# the same handler in the user config.toml fires.
#
# Codex also gates every hook behind a trust hash it computes itself, so writing
# the block is not enough — the user has to approve the hook once inside Codex.
# We cannot forge that hash, and should not try.
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
TOML_BEGIN="# iceberg:begin"
TOML_END="# iceberg:end"

write_codex_hook() {
  local file="$CODEX_HOME_DIR/config.toml"
  mkdir -p "$CODEX_HOME_DIR"
  touch "$file"

  if grep -qF "$TOML_BEGIN" "$file"; then
    awk -v b="$TOML_BEGIN" -v e="$TOML_END" '
      index($0,b){skip=1} !skip{print} index($0,e){skip=0}
    ' "$file" > "$file.iceberg.tmp"
    mv "$file.iceberg.tmp" "$file"
  fi

  {
    printf '\n%s\n' "$TOML_BEGIN"
    printf '[[hooks.UserPromptSubmit]]\n'
    printf 'description = "iceberg — inject the rules; a bare -a swaps in the long form"\n'
    printf '[[hooks.UserPromptSubmit.hooks]]\n'
    printf 'type = "command"\n'
    printf 'command = "%s/hooks/inject.sh"\n' "$HERE"
    printf '%s\n' "$TOML_END"
  } >> "$file"

  # An earlier version of this script wrote a project hook file that Codex
  # never read. Clear it so nobody debugs a file that does nothing.
  if [ -f .codex/hooks.json ] && grep -q "inject.sh" .codex/hooks.json; then
    rm -f .codex/hooks.json
    echo "  removed .codex/hooks.json (Codex never read it)"
  fi

  echo "  updated $file (UserPromptSubmit, -a aware)"
  echo "  one more step: open Codex and approve the iceberg hook."
  echo "  Codex will not run an untrusted hook, and only Codex can trust it."
}

# Cursor gets two layers. The alwaysApply rule is the one that carries the
# rules turn to turn. The sessionStart hook is a second copy at the front of the
# system context — Cursor has no per-turn injecting hook to use instead.
write_cursor() {
  mkdir -p .cursor/rules
  cp "$HERE/adapters/cursor.mdc" .cursor/rules/iceberg.mdc
  echo "  updated .cursor/rules/iceberg.mdc (alwaysApply)"

  if [ -f .cursor/hooks.json ] && ! grep -q "cursor-context.sh" .cursor/hooks.json; then
    echo "  .cursor/hooks.json already exists and is not ours — left alone."
    echo "  To add the second layer by hand, register this under sessionStart:"
    echo "    $HERE/hooks/cursor-context.sh"
    return
  fi

  cat > .cursor/hooks.json <<JSON
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "command": "$HERE/hooks/cursor-context.sh" }
    ]
  }
}
JSON
  echo "  updated .cursor/hooks.json (sessionStart)"
}

install_target() {
  case "$1" in
    claude)   install_claude ;;
    codex)    echo "codex:";    write_codex_hook; write_block "AGENTS.md" ;;
    agents)   echo "agents.md:"; write_block "AGENTS.md" ;;
    cursor)   echo "cursor:";   write_cursor ;;
    windsurf) echo "windsurf:"; write_block ".windsurf/rules/iceberg.md" ;;
    copilot)  echo "copilot:";  write_block ".github/copilot-instructions.md" ;;
    *) echo "unknown target: $1"; exit 1 ;;
  esac
}

TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(all)
if [ "${TARGETS[0]}" = "all" ]; then
  TARGETS=(claude codex cursor windsurf copilot)
fi

for t in "${TARGETS[@]}"; do install_target "$t"; done
echo "done."
