#!/usr/bin/env sh
# Prints the rules on stdout. Claude Code and Codex both add a UserPromptSubmit
# hook's stdout to the model's context, so this one script serves both.
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cat "$DIR/prompt.md"
