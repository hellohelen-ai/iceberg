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
  echo "  to try it before installing:  claude --plugin-dir $HERE"
}

# Codex reads the same shape of hook as Claude Code, and its UserPromptSubmit
# adds plain stdout to the context. So Codex gets per-turn injection too, not
# just a file it reads once at session start. inject.sh picks the rule file:
# prompt.md normally, expand.md on a turn that carries a -a.
write_codex_hook() {
  mkdir -p .codex
  cat > .codex/hooks.json <<JSON
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HERE/hooks/inject.sh\""
          }
        ]
      }
    ]
  }
}
JSON
  echo "  updated .codex/hooks.json (injected every turn, -a aware)"
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
