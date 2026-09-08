#!/usr/bin/env bash
# Remove managed iceberg installs and legacy blocks from this project.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/scripts/install-common.sh"

for f in AGENTS.md CLAUDE.md .windsurf/rules/iceberg.md .github/copilot-instructions.md; do
  remove_block "$f"
done
remove_cursor_rules

for dir in .agents/skills/iceberg .cursor/skills/iceberg .windsurf/skills/iceberg .github/skills/iceberg; do
  [ -f "$dir/.iceberg-installed" ] || continue
  rm -f "$dir/SKILL.md" "$dir/.iceberg-installed"
  echo "removed $dir/SKILL.md"
  prune_empty_dirs "$dir"
done

# Codex keeps hooks in the user config, not in the project.
CODEX_CONFIG="${CODEX_HOME:-$HOME/.codex}/config.toml"
TOML_BEGIN="# iceberg:begin"
TOML_END="# iceberg:end"
if [ -f "$CODEX_CONFIG" ] && grep -qF "$TOML_BEGIN" "$CODEX_CONFIG"; then
  awk -v b="$TOML_BEGIN" -v e="$TOML_END" 'index($0,b){skip=1} !skip{print} index($0,e){skip=0}' \
    "$CODEX_CONFIG" > "$CODEX_CONFIG.tmp"
  mv "$CODEX_CONFIG.tmp" "$CODEX_CONFIG"
  echo "cleaned $CODEX_CONFIG"
fi

# A project hook file from an older iceberg. Codex never read it.
if [ -f .codex/hooks.json ] && grep -q "iceberg\|inject.sh\|short.md" .codex/hooks.json; then
  rm -f .codex/hooks.json && echo "removed .codex/hooks.json"
fi
# Drop only empty directories; keep any user files or other skills.
prune_empty_dirs .agents/skills .agents .cursor/skills .cursor/rules .cursor \
  .codex .windsurf/skills .windsurf/rules .windsurf .github/skills .github
echo "done."
