#!/usr/bin/env sh
# Cursor hook. Prints the rules as the JSON Cursor expects for context
# injection: {"additional_context": "..."}
#
# Cursor has no per-turn injecting hook — beforeSubmitPrompt returns only
# `continue` and `user_message`. Only sessionStart and postToolUse can return
# additional_context, so this script serves both.
#
# No jq, no python. awk is enough, and the input is our own ASCII rule file.
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SHORT="$DIR/short.md"

[ -f "$SHORT" ] || { echo '{"additional_context":""}'; exit 0; }

awk '
  BEGIN { printf "{\"additional_context\":\"" }
  {
    line = $0
    gsub(/\\/, "\\\\", line)
    gsub(/"/,  "\\\"", line)
    gsub(/\t/, "\\t",  line)
    printf "%s\\n", line
  }
  END { print "\"}" }
' "$SHORT"
