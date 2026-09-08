#!/usr/bin/env sh
# Prints the rules on stdout. Claude Code and Codex both add a UserPromptSubmit
# hook's stdout to the model's context, so this one script serves both.
#
# It picks one rule file per turn:
#   bare -a in the message -> long.md   (the long answer, kept in shape)
#   otherwise              -> short.md   (the four-line rules)
#
# Emit exactly one rule file per invocation. Earlier turns may remain in the
# conversation; each prompt scopes its rules to the current turn.
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SHORT="$DIR/short.md"
LONG="$DIR/long.md"

payload=$(cat)

# A standalone -a token, anywhere in the message. A quote counts as a boundary
# so the no-parser path below still matches a -a that ends the JSON string.
FLAG='(^|[[:space:]"])-a([[:space:]"]|$)'

# Pull .prompt out of the hook payload. jq if it is here, python3 if not.
if command -v jq >/dev/null 2>&1; then
  user_prompt=$(printf '%s' "$payload" | jq -r '.prompt // ""' 2>/dev/null || echo "")
elif command -v python3 >/dev/null 2>&1; then
  user_prompt=$(printf '%s' "$payload" | python3 -c \
    'import json,sys;print(json.load(sys.stdin).get("prompt",""))' 2>/dev/null || echo "")
else
  # No JSON parser. Match against the raw payload, treating \n as whitespace.
  user_prompt=$(printf '%s' "$payload" | sed 's/\\[nrt]/ /g')
fi

# -a is also a real flag, so `git commit -a` matches here. The hook cannot tell
# the two apart; long.md ends with the line that lets the model decide. A
# false positive therefore still needs a short-answer guard in long.md.
if printf '%s' "$user_prompt" | grep -qE "$FLAG" && [ -f "$LONG" ]; then
  cat "$LONG"
elif [ -f "$SHORT" ]; then
  cat "$SHORT"
fi

exit 0
