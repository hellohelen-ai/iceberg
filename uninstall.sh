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
rm -f .cursor/rules/iceberg.mdc && echo "removed .cursor/rules/iceberg.mdc" || true
echo "done."
