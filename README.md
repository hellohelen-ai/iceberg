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
  <a href="#when-you-do-want-the-long-version--a">The <code>-a</code> flag</a> ·
  <a href="#customize">Customize</a>
</p>

---

## See it

Both of these answer *"I have two async functions that both write to the same
record and sometimes the second write is lost. What is happening?"* Both are
correct. Both are real replies from the eval — see `evals/snapshot.json`.

<table>
<tr>
<th width="50%">Your agent today · 1,000 tokens</th>
<th width="50%">With iceberg · 52 tokens</th>
</tr>
<tr>
<td valign="top">

> That's almost certainly a **lost update** race condition. The general mechanism:
>
> 1. Function A reads the record.
> 2. Function B reads the record (before A's write lands).
> 3. Function A writes back its version.
> 4. Function B writes back *its* version — based on the stale read from step 2 — silently clobbering A's write.
>
> Because both functions are `async`, they interleave at `await` points rather than running atomically…
>
> **Common concrete causes:**
> - Read-modify-write pattern instead of an atomic update
> - `Promise.all`/fire-and-forget with no ordering guarantee
> - No transaction / isolation at the DB level
> - No optimistic locking
>
> **Typical fixes, roughly in order of preference:**
> - Use an atomic operation at the storage layer…
> - Add optimistic concurrency control…
> - Wrap both operations in a transaction…
> - Serialize the two writes with a mutex/lock/queue…
>
> If you paste the two functions I can point at the exact spot and suggest the minimal fix.

</td>
<td valign="top">

> Race condition: both functions read-modify-write the same record concurrently, so the second write overwrites the first (lost update).
>
> More: fix with locking/transactions?

</td>
</tr>
</table>

Same diagnosis. Same term of art. One of them lets you get back to work.

Code, commands, file paths, and exact error strings are never compressed. Only
the prose around them is.

## Install

**The skill.** One command, 17 agents — Codex, Cursor, Warp, Amp, Antigravity, and more, plus a Claude Code symlink:

```bash
npx skills add hellohelen-ai/iceberg
```

Say `/iceberg` if your agent does not wake up on its own.

**The plugin.** Stronger than the skill — it re-injects the rules on *every*
turn through a `UserPromptSubmit` hook, so they never fall out of context on a
long session. Claude Code:

```
/plugin marketplace add hellohelen-ai/iceberg
/plugin install iceberg@iceberg
```

Try it first, without installing anything:

```bash
claude --plugin-dir ~/iceberg
```

Codex reads the same repo — `.codex-plugin/plugin.json` points at the same
skill and an equivalent hook. Add it to a marketplace catalog at
`~/.agents/plugins/marketplace.json`, or use `install.sh codex` below, which
writes a project-level `.codex/hooks.json` and needs no catalog.

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
| 8 | A long answer still has a shape. |

Rule 5 is the one people underestimate. If you must do something, it is the last thing you read — not buried in paragraph three.

## When you do want the long version — `-a`

Sometimes four lines is not enough. Put a bare `-a` anywhere in your message and
you get the long answer for **that turn only**:

```
why does this deadlock -a
```

`-a` lifts the length ceiling. It lifts nothing else. You still get the answer on
line 1 — you can stop reading there and be right — and you still get the one
action, alone, on the last line. What changes is what sits between them:

| | Normal | `-a` |
|---|---|---|
| Line 1 | the answer | the answer |
| Ceiling | 4 lines | 40 lines |
| Headings | banned | 1–4 words, one idea each |
| Paragraphs | banned | 3 lines, max |
| Last line | the action | the action |

So the long version is *structured*, not *loose*. Preamble, your own question
restated back at you, "great question", and the closing offer of more help are cut
in both modes. **Expanded means more information — not more words per unit of
information.**

The same shape now applies to the four words that already lifted the ceiling:

**explain** · **in detail** · **walk me through** · **report**

Say *"stop iceberg"* or *"normal mode"* to end it for the session.

**How the plugin does it.** The `UserPromptSubmit` hook reads your message and
*swaps* the injected rules — `prompt.md` on a normal turn, `expand.md` on a `-a`
turn. It never injects both. Terse rules and expanded rules contradict each other
on purpose, so only one of them is ever in the context.

One known collision: `-a` is a real flag, so *"run `git commit -a`"* trips the
match. The hook hands the model `expand.md`, and `expand.md`'s last line tells it
to fall back to four lines when the `-a` belongs to a command. The cost of a false
positive is a few tokens, never a wrong answer.

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

Only the two `UserPromptSubmit` rows can swap rule files mid-session, so only they
get the strong form of `-a`. Everywhere else `-a` is rule 8 of the static block —
same behaviour, weaker grip, because the four-line rules stay in the context
alongside it.

Per-turn beats read-once. A static instruction file sits a hundred messages back in the context by the time it matters.

Codex hooks take the same shape as Claude Code's, and its `UserPromptSubmit` adds plain stdout to the context. Both call the same `hooks/inject.sh`, which resolves the rule file — `prompt.md`, or `expand.md` on a `-a` turn — from its own location, so neither has to interpolate a root variable into a `cat` argument. `install.sh codex` writes a `.codex/hooks.json` as well as the `AGENTS.md` block.

Cursor is the exception. It has no `UserPromptSubmit`; `beforeSubmitPrompt` fires every turn but returns only `continue` and `user_message`, so it can block your prompt and never add to it. Only `sessionStart` and `postToolUse` can return `additional_context`.

So `install.sh cursor` lays down two layers: the `alwaysApply` rule, which the editor re-sends turn to turn, and a `sessionStart` hook that puts a copy at the front of the system context. If you already have a `.cursor/hooks.json`, the installer leaves it alone and prints the one line to add.

## Does it work

Start from your agent as it ships — Claude Code, opened, asked a question, no
rules of any kind added. That is the row called **"your agent today"**. Across 15
real dev questions and three runs, its average reply is **538 tokens**, roughly
400 words, or the wall of text in the left column above.

Then add one system prompt and ask the same 15 questions again:

| What you add | Mean reply | vs. your agent today |
|---|---|---|
| nothing — your agent today | 538 tokens | — |
| `Answer concisely.` | 749 tokens | **39% longer** |
| iceberg's 7 rules | **94 tokens** | **83% shorter** |

Two things fall out of that table.

**Asking for concision backfires.** `Answer concisely.` produced *more* text than
adding nothing at all, in all three runs. "Concisely" is an adjective with no target, so
the model keeps the heading, the numbered list, and the closing offer — it just
feels brisk while writing them.

**Rules work where adjectives don't.** A four-line ceiling, a required shape, and
a named thing to omit get you replies 83% shorter than your agent's default — and
87% shorter than the concision ask most people reach for first.

Token counts come straight from `usage.output_tokens`. Every raw reply is in
`evals/snapshot.json`. Reproduce it with `python3 evals/run.py` — about $2 on
Sonnet.

Those numbers cover the four-line path. `-a` is not in the eval yet — it is a
different job, and counting its tokens against the terse arm would measure nothing.

Caveat worth reading: absolute counts swing hard between runs (baseline came back
367, 650, 596 on identical inputs). The ratios held. [`evals/README.md`](./evals)
shows all three runs and the ~93% rule-compliance rate.

## Staying current

Iceberg tells you when it is out of date, then updates itself:

```
iceberg 0.3.0 → 0.4.0 available. Run /iceberg:update.
```

A `SessionStart` hook prints that line, and `/iceberg:update` does the work.

The check never costs you a wait. It reads a cache the *previous* session left
behind and refreshes it in a detached background process, at most once a day. No
cache, no network, or no newer tag means the hook prints nothing at all — a
plugin that sells brevity should not spend your context on its own release
notes.

To update by hand instead:

```bash
claude plugin marketplace update iceberg
claude plugin update iceberg@iceberg
```

The skill is a plain file, so re-running `npx skills add hellohelen-ai/iceberg`
overwrites it with the current version. `install.sh` is re-runnable for the same
reason.

If you cloned the repo, `git pull` is enough — the hook reads `prompt.md` off
disk on every turn, so nothing is cached.

## Customize

Three files, and they say the same thing in three lengths:

- `prompt.md` — the short form the hook injects on a normal turn
- `expand.md` — what the hook injects instead on a `-a` turn
- `skills/iceberg/SKILL.md` — the long form an agent loads on demand

Edit any of them. Change the line limit, drop rule 5, move `-a` to `-v`, add your
own. That is the whole product.

## Why "iceberg"

Hemingway's Iceberg Theory: omit what the reader can infer. The omitted part is still there, and it is what gives the writing its weight.

> *"The dignity of movement of an iceberg is due to only one-eighth of it being above water."*

## License

MIT
