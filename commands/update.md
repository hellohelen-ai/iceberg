---
description: Update iceberg to the newest release
---

Update the iceberg plugin, then tell the user the result in one line.

1. Run `claude plugin marketplace update iceberg`.
2. Run `claude plugin update iceberg@iceberg -y`.
3. Refresh the update cache so the banner stops showing:
   `rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/iceberg/update.json"`

Report the old and new version numbers and that a restart applies the change.
If the plugin was not installed through a marketplace — a `git clone` plus
`install.sh`, or `--plugin-dir` — say so and tell the user to run `git pull` in
that checkout instead.
