# iceberg (skill)

The rules, as a skill. Install with:

```bash
npx skills add hellohelen-ai/iceberg
```

Then say `/iceberg` if your agent does not pick it up on its own.

`SKILL.md` and `../../short.md` say the same thing. `short.md` is the short form
the Claude Code hook injects every turn; `SKILL.md` is the long form an agent loads
on demand.

Both cover `-a`, the flag that asks for a long answer that still keeps its shape.
In the plugin, a `-a` turn swaps `short.md` out for `../../long.md`. The skill has
no hook to swap with, so it carries the expanded rules inline instead.
