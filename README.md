# iceberg

Make your coding agent laconic.

Show 1/8. Keep 7/8 below the surface. The agent still does all the work — it just stops narrating it.

```
Before                                  After
────────────────────────────────────    ────────────────────────────
## Summary of Changes                   Fixed. The retry used the
I've successfully implemented the...     stale token.
### What I did
1. First, I updated the auth...          More: why it went stale?
2. Then I refactored the...
### Next Steps
You may want to consider...
```

## What it does

One prompt, injected on every turn. Seven rules:

| # | Rule |
|---|---|
| 1 | Answer first, in one line. Then stop. |
| 2 | Pull, do not push. Offer more; never dump it. |
| 3 | Hard limit: 4 lines. |
| 4 | No paragraphs, headings, or summary blocks. |
| 5 | Action last, on its own line, one item. |
| 6 | Simplified Technical English. Short words, active voice. |
| 7 | Never recap the diff. |

Say **explain**, **in detail**, **walk me through**, or **report** to lift the limit for one turn.

## Install

### Claude Code (plugin)

```
/plugin marketplace add hellohelen-ai/iceberg
/plugin install iceberg@iceberg
```

The plugin registers a `UserPromptSubmit` hook. It re-injects the rules every turn, so they never fall out of context.

### Everything else

```bash
git clone https://github.com/hellohelen-ai/iceberg.git
cd your-project
~/iceberg/install.sh codex      # AGENTS.md
~/iceberg/install.sh cursor     # .cursor/rules/iceberg.mdc
~/iceberg/install.sh windsurf   # .windsurf/rules/iceberg.md
~/iceberg/install.sh copilot    # .github/copilot-instructions.md
~/iceberg/install.sh all        # all of the above
```

Re-runnable. `./uninstall.sh` removes every block it added.

| Agent | File | Injected every turn? |
|---|---|---|
| Claude Code | plugin hook | yes |
| Codex | `AGENTS.md` | no — read once |
| Cursor | `.cursor/rules/iceberg.mdc` | yes (`alwaysApply`) |
| Windsurf | `.windsurf/rules/iceberg.md` | yes |
| Copilot | `.github/copilot-instructions.md` | no — read once |

A per-turn hook beats a static file. The rules stay at the front of the context, not buried a hundred messages back.

## Customize

Edit `prompt.md`. That is the whole product. Change the line limit, drop rule 5, add your own.

## Why "iceberg"

Hemingway's Iceberg Theory: omit what the reader can infer. The omitted part is still there, and it is what gives the writing its weight.

## License

MIT
