# iceberg (skill)

The self-contained option for agents without a per-prompt hook. Install with:

```bash
npx skills add hellohelen-ai/iceberg
```

Or use `install.sh cursor`, `windsurf`, `copilot`, or `agents` to copy the skill
into your project's skill directory. Say "use iceberg mode" to activate it.

`SKILL.md` contains both answer modes and their triggers: short by default,
expanded for a bare `-a` or requests such as "explain" and "in detail". The
expanded rules live inline because this install has no hook to select a file.

The hook uses `../../short.md` and `../../long.md` separately. It selects only
on `-a` and injects one file per turn. Those files do not define the skill's
behavior. Hook users do not need to activate the skill too.
