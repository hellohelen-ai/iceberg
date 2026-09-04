<p align="center">
  <strong>show one eighth. keep seven eighths below the surface.</strong>
</p>

<p align="center">
  Your coding agent does ten minutes of work and writes you a book report about it.<br>
  Iceberg makes it stop. Same work. Same accuracy. One line.
</p>

<p align="center">
  <a href="#see-it">See it</a> ·
  <a href="#install">Install</a> ·
  <a href="#the-rules">Rules</a> ·
  <a href="#lifting-the-limit">Lift the limit</a> ·
  <a href="#customize">Customize</a>
</p>

---

## See it

<table>
<tr>
<th width="50%">Normal agent</th>
<th width="50%">Iceberg agent</th>
</tr>
<tr>
<td valign="top">

> ## Summary of Changes
>
> I've successfully implemented the fix for the authentication issue you described. Here's a breakdown of what I did:
>
> ### What I changed
> 1. First, I updated `auth.ts` to refresh the token before the retry
> 2. Then I added a guard clause to handle the null case
> 3. Finally, I updated the tests to cover both paths
>
> ### Next steps
> You may want to consider adding telemetry here so you can track how often this path is hit in production. Let me know if you'd like me to do that!

</td>
<td valign="top">

> Fixed. The retry reused the stale token.
>
> More: why it went stale?

</td>
</tr>
</table>

Same fix. Same files. The only thing that died was the throat-clearing.

**84% fewer output tokens** than telling your agent `Answer concisely.` — measured over 15 real prompts, not estimated. [The harness is in `evals/`](./evals), and it prints the unflattering numbers too.

Code, commands, file paths, and exact error strings are never compressed. Only the prose around them is.

## Install

**The skill.** One command, 17 agents — Codex, Cursor, Warp, Amp, Antigravity, and more, plus a Claude Code symlink:

```bash
npx skills add hellohelen-ai/iceberg
```

Say `/iceberg` if your agent does not wake up on its own.

**The plugin.** Claude Code only, and stronger — it re-injects the rules on *every* turn, so they never fall out of context on a long session:

```
/plugin marketplace add hellohelen-ai/iceberg
/plugin install iceberg@iceberg
```

**By hand.** Clone it and drop a marked block into whatever file your agent reads:

```bash
git clone https://github.com/hellohelen-ai/iceberg.git ~/iceberg
cd your-project
~/iceberg/install.sh all      # or: codex cursor windsurf copilot
```

Re-runnable. `~/iceberg/uninstall.sh` removes every block it added.

## The rules

| # | Rule |
|---|---|
| 1 | Answer first, in one line. Then stop. |
| 2 | Pull, do not push. Offer more; never dump it. |
| 3 | Four lines. Hard ceiling. |
| 4 | No paragraphs, headings, or summary blocks. |
| 5 | Action last, on its own line, one item. |
| 6 | Simplified Technical English. Short words, active voice. |
| 7 | Never recap the diff. |

Rule 5 is the one people underestimate. If you must do something, it is the last thing you read — not buried in paragraph three.

## Lifting the limit

Four words turn it off for one turn:

**explain** · **in detail** · **walk me through** · **report**

Say *"stop iceberg"* or *"normal mode"* to end it for the session.

## What never gets cut

Negations — *not*, *never*, *no*, *only*, *except*. Dropping one flips the meaning, which costs far more than the line it saved.

Numbers, units, code blocks, and error strings stay verbatim.

## Which install should I use?

| Method | Agents | Re-injected every turn |
|---|---|---|
| `npx skills add` | 17 | on demand |
| Claude Code plugin | Claude Code | yes — `UserPromptSubmit` hook |
| `install.sh codex` | Codex | yes — `UserPromptSubmit` hook |
| `install.sh cursor` | Cursor | yes — `alwaysApply` rule |
| `install.sh windsurf` | Windsurf | yes |
| `install.sh copilot` | Copilot | read once |

Per-turn beats read-once. A static instruction file sits a hundred messages back in the context by the time it matters.

Codex hooks take the same shape as Claude Code's, and its `UserPromptSubmit` adds plain stdout to the context — so `install.sh codex` writes a `.codex/hooks.json` as well as the `AGENTS.md` block.

Cursor is the exception. Its `beforeSubmitPrompt` hook fires every turn but cannot inject context; only `sessionStart` can, and that runs once. So Cursor gets an `alwaysApply` rule instead, which the editor re-sends anyway.

## Does it work

15 prompts, three arms, Sonnet. Token counts straight from `usage.output_tokens`.

| Arm | System prompt | Mean output tokens |
|---|---|---|
| baseline | none | 367 |
| terse | `Answer concisely.` | 524 |
| **iceberg** | `Answer concisely.` + the rules | **84** |

84% under `terse`. 0 of 15 replies broke the four-line limit.

The number to read is iceberg vs terse, not iceberg vs baseline — anyone can type "be concise" for free, so that is the bar.

And note the middle row: **`Answer concisely.` came out 43% longer than saying nothing at all.** A vague ask for brevity does not get you brevity. A line ceiling does.

Reproduce it: `python3 evals/run.py` — about $1.60 on Sonnet.

## Customize

Two files, and they say the same thing:

- `prompt.md` — the short form the Claude Code hook injects every turn
- `skills/iceberg/SKILL.md` — the long form an agent loads on demand

Edit either. Change the line limit, drop rule 5, add your own. That is the whole product.

## Why "iceberg"

Hemingway's Iceberg Theory: omit what the reader can infer. The omitted part is still there, and it is what gives the writing its weight.

> *"The dignity of movement of an iceberg is due to only one-eighth of it being above water."*

## License

MIT
