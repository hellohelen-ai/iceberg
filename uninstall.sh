#!/usr/bin/env bash
# Remove every iceberg block from this project.
set -euo pipefail
BEGIN="<!-- iceberg:begin -->"
END="<!-- iceberg:end -->"

for f in AGENTS.md CLAUDE.md .windsurf/rules/iceberg.md .github/copilot-instructions.md; do
  [ -f "$f" ] || continue
  grep -qF "$BEGIN" "$f" || continue
  awk -v b="$BEGIN" -v e="$END" 'index($0,b){skip=1} !skip{print} index($0,e){skip=0}' "$f" > "$f.tmp"
  mv "$f.tmp" "$f"
  echo "cleaned $f"
done
if [ -f .cursor/rules/iceberg.mdc ]; then
  rm -f .cursor/rules/iceberg.mdc && echo "removed .cursor/rules/iceberg.mdc"
fi

if [ -f .cursor/hooks.json ] && grep -q "cursor-context.sh" .cursor/hooks.json; then
  rm -f .cursor/hooks.json && echo "removed .cursor/hooks.json"
fi

# Only remove the Codex hook file if it is ours and holds nothing else.
if [ -f .codex/hooks.json ] && grep -q "iceberg\|short.md" .codex/hooks.json; then
  rm -f .codex/hooks.json && echo "removed .codex/hooks.json"
fi
echo "done."
