#!/usr/bin/env bash
# iceberg — make your coding agent laconic.
# Usage:  ./install.sh [target ...]   targets: claude codex cursor windsurf copilot agents all
# Hook installs inject one prompt per turn; other targets install the skill.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$HERE/skills/iceberg/SKILL.md"
source "$HERE/scripts/install-common.sh"

[ -f "$SKILL" ] || { echo "missing skills/iceberg/SKILL.md"; exit 1; }

install_skill() {
  local dir="$1" file="$1/SKILL.md"
  if [ -L "$dir" ] || [ -L "$file" ] || { [ -f "$file" ] && [ ! -f "$dir/.iceberg-installed" ]; }; then
    echo "  $file already exists outside install.sh; update it with its original installer."
    return 1
  fi
  mkdir -p "$dir"
  cp "$SKILL" "$file"
  touch "$dir/.iceberg-installed"
  echo "  installed $file (on demand; say 'use iceberg mode' to activate)"
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

install_target() {
  case "$1" in
    claude)   install_claude ;;
    codex)
      echo "codex:"
      write_codex_hook
      remove_block "AGENTS.md"
      ;;
    agents)
      echo "agents:"
      install_skill ".agents/skills/iceberg"
      remove_block "AGENTS.md"
      ;;
    cursor)
      echo "cursor:"
      install_skill ".cursor/skills/iceberg"
      remove_cursor_rules
      prune_empty_dirs .cursor/rules
      ;;
    windsurf)
      echo "windsurf:"
      install_skill ".windsurf/skills/iceberg"
      remove_block ".windsurf/rules/iceberg.md"
      prune_empty_dirs .windsurf/rules
      ;;
    copilot)
      echo "copilot:"
      install_skill ".github/skills/iceberg"
      remove_block ".github/copilot-instructions.md"
      ;;
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
