#!/usr/bin/env bash
# Shared migration and uninstall helpers. Paths are relative to the project.

remove_block() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -qF '<!-- iceberg:begin -->' "$file" || return 0
  awk '
    index($0,"<!-- iceberg:begin -->"){skip=1}
    !skip{print}
    index($0,"<!-- iceberg:end -->"){skip=0}
  ' "$file" > "$file.iceberg.tmp"
  mv "$file.iceberg.tmp" "$file"
  if [ "$file" != CLAUDE.md ] && [ -z "$(tr -d '[:space:]' < "$file")" ]; then
    rm -f "$file"
  fi
  echo "  removed legacy iceberg block from $file"
}

remove_cursor_rules() {
  local file=.cursor/rules/iceberg.mdc
  if [ -f "$file" ] && grep -qF 'description: Iceberg - keep replies short' "$file"; then
    rm -f "$file"
    echo "  removed $file"
  fi
  if [ -f .cursor/hooks.json ] && grep -qF 'cursor-context.sh' .cursor/hooks.json; then
    if command -v python3 >/dev/null 2>&1; then
      python3 "$HERE/scripts/clean-cursor-hooks.py" .cursor/hooks.json
    else
      echo "  legacy Cursor hook is now inert; install Python 3 and re-run to remove its registration."
    fi
  fi
}

prune_empty_dirs() {
  local dir
  for dir in "$@"; do
    [ -d "$dir" ] || continue
    rmdir "$dir" 2>/dev/null || true
  done
}
