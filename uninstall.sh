#!/usr/bin/env bash
# Remove every iceberg block from this project.
set -euo pipefail
BEGIN="<!-- iceberg:begin -->"
END="<!-- iceberg:end -->"

# Files install.sh creates itself. If stripping the block empties one, it held
# nothing but iceberg, so remove it instead of leaving a blank file behind.
is_ours() {
  case "$1" in
    AGENTS.md|.windsurf/rules/iceberg.md|.github/copilot-instructions.md) return 0 ;;
    *) return 1 ;;
  esac
}

for f in AGENTS.md CLAUDE.md .windsurf/rules/iceberg.md .github/copilot-instructions.md; do
  [ -f "$f" ] || continue
  grep -qF "$BEGIN" "$f" || continue
  awk -v b="$BEGIN" -v e="$END" 'index($0,b){skip=1} !skip{print} index($0,e){skip=0}' "$f" > "$f.tmp"
  mv "$f.tmp" "$f"
  if is_ours "$f" && [ -z "$(tr -d '[:space:]' < "$f")" ]; then
    rm -f "$f" && echo "removed $f"
  else
    echo "cleaned $f"
  fi
done
if [ -f .cursor/rules/iceberg.mdc ]; then
  rm -f .cursor/rules/iceberg.mdc && echo "removed .cursor/rules/iceberg.mdc"
fi

if [ -f .cursor/hooks.json ] && grep -q "cursor-context.sh" .cursor/hooks.json; then
  rm -f .cursor/hooks.json && echo "removed .cursor/hooks.json"
fi

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
# Drop the directories we made, but only while they are empty.
for d in .cursor/rules .cursor .codex .windsurf/rules .windsurf .github; do
  [ -d "$d" ] || continue
  rmdir "$d" 2>/dev/null && echo "removed $d/" || true
done
echo "done."
