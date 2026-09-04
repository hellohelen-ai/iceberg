#!/usr/bin/env bash
# iceberg — make your coding agent laconic.
# Usage:  ./install.sh [target ...]   targets: claude codex cursor windsurf copilot agents all
# Adds a marked block to the agent's instruction file. Re-runnable. Remove with ./uninstall.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT="$HERE/prompt.md"
BEGIN="<!-- iceberg:begin -->"
END="<!-- iceberg:end -->"

[ -f "$PROMPT" ] || { echo "missing prompt.md"; exit 1; }

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
  { printf '\n%s\n' "$BEGIN"; cat "$PROMPT"; printf '%s\n' "$END"; } >> "$file"
  echo "  updated $file"
}

install_claude() {
  echo "claude code:"
  echo "  run these two commands in Claude Code:"
  echo "    /plugin marketplace add hellohelen-ai/iceberg"
  echo "    /plugin install iceberg@iceberg"
  echo "  or, for 30+ agents:  npx skills add hellohelen-ai/iceberg"
}

install_target() {
  case "$1" in
    claude)   install_claude ;;
    codex)    echo "codex:";    write_block "AGENTS.md" ;;
    agents)   echo "agents.md:"; write_block "AGENTS.md" ;;
    cursor)   echo "cursor:";   mkdir -p .cursor/rules; cp "$HERE/adapters/cursor.mdc" .cursor/rules/iceberg.mdc; echo "  updated .cursor/rules/iceberg.mdc" ;;
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
