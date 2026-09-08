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
correct. Both are real replies from the eval — see `evals/snapshot-short.json`.

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

**The skill.** For agents without a per-prompt hook, install the self-contained skill:

```bash
npx skills add hellohelen-ai/iceberg
```

Say "use iceberg mode" to activate it, or use your agent's skill command
(`/iceberg` in Cursor, `@iceberg` in Windsurf). The full rules load on demand.

**The hook.** It injects one compact rule file on every prompt: `long.md` if
the message contains a standalone `-a`, otherwise `short.md`. You do not need
to activate the skill as well. For Claude Code, install the plugin:

```
/plugin marketplace add hellohelen-ai/iceberg
/plugin install iceberg@iceberg
```

Try it first, without installing anything:

```bash
claude --plugin-dir ~/iceberg
```

Codex reads the same repo — `.codex-plugin/plugin.json` points at the same
skill. Add it to a marketplace catalog at `~/.agents/plugins/marketplace.json`,
or use `install.sh codex` below, which writes the hook into your Codex config
and needs no catalog. Codex asks you to approve the hook once; see below.

**By hand.** Clone it and install a hook or a project skill:

```bash
git clone https://github.com/hellohelen-ai/iceberg.git ~/iceberg
cd your-project
~/iceberg/install.sh codex    # per-prompt hook in your Codex config
~/iceberg/install.sh cursor   # or: windsurf copilot agents, for a project skill
# ~/iceberg/install.sh all    # all targets, including the Codex hook
```

Re-runnable. `~/iceberg/uninstall.sh` removes the hook and project skills
managed by this script, plus legacy static installs. Plugin-manager and
`npx skills add` installs are managed separately.

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

With the **standalone skill**, **explain**, **in detail**, **walk me through**,
and **report** also request the expanded shape. Say *"stop iceberg"* or
*"normal mode"* to end the skill's style for the session.

With the **hook**, only `-a` selects the expanded prompt. Words such as
"explain" still get the short prompt. Disable or uninstall the hook to stop
automatic injection.

**How the plugin does it.** The `UserPromptSubmit` hook reads your message and
*swaps* the injected rules — `short.md` on a normal turn, `long.md` on a `-a`
turn. Each invocation emits just one file. Earlier turns can remain in the
conversation, so each prompt scopes its rules to the current turn. The short
prompt carries no expanded-mode rules or routing instructions.

One known collision: `-a` is a real flag, so *"run `git commit -a`"* trips the
match. The hook hands the model `long.md`, and `long.md`'s last line tells it
to answer in four lines when `-a` belongs only to a command. This semantic
exception stays in the expanded prompt because the regex cannot resolve it.

## What never gets cut

Negations — *not*, *never*, *no*, *only*, *except*. Dropping one flips the meaning, which costs far more than the line it saved.

Numbers, units, code blocks, and error strings stay verbatim.

## Which install should I use?

| Method | What it installs | When full rules load |
|---|---|---|
| `npx skills add` | Standalone skill for your selected agents | On demand |
| Claude Code plugin | Per-prompt hook; skill also available | One prompt file per turn |
| `install.sh codex` | User-level `UserPromptSubmit` hook | One prompt file per turn, after approval |
| `install.sh cursor` | `.cursor/skills/iceberg/SKILL.md` | On demand |
| `install.sh windsurf` | `.windsurf/skills/iceberg/SKILL.md` | On demand |
| `install.sh copilot` | `.github/skills/iceberg/SKILL.md` | On demand |
| `install.sh agents` | `.agents/skills/iceberg/SKILL.md` | On demand in compatible agents |

Skill locations follow the [Cursor](https://prod.cursor.com/docs/skills),
[Windsurf](https://docs.windsurf.com/windsurf/cascade/skills), and
[GitHub Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills)
documentation. `agents` uses the shared directory supported by the
[skills installer](https://github.com/vercel-labs/skills).

The hook owns routing; its two prompt files each describe one answer mode.
The standalone skill carries both modes and their triggers because it has no
hook to select a file. Use one approach per agent session to avoid loading both.

Codex takes the same `UserPromptSubmit` event and the same handler shape as Claude Code, and calls the same `hooks/inject.sh`. The script resolves its rule file — `short.md`, or `long.md` on a `-a` turn — from its own location, so neither agent has to interpolate a root variable into a `cat` argument.

**Codex keeps hooks in one place, and it is not your project.** Tested against `codex-cli 0.153.2`: a project `.codex/hooks.json` fires nothing, and so does a project `.codex/config.toml`. The handler has to live in `$CODEX_HOME/config.toml` — `~/.codex/config.toml` by default. Earlier iceberg releases wrote the project file, so Codex users got the `AGENTS.md` block and nothing else. `install.sh codex` writes a marked block into the Codex config, removes the dead project hook file, and removes the old iceberg block from `AGENTS.md`. It does not add static instructions.

**Codex will not run a hook you have not approved.** Every handler carries a trust hash that Codex computes itself, and an unapproved handler is skipped in silence — no warning, no output. No installer can forge that hash, and iceberg does not try. Run `install.sh codex`, open Codex, approve the iceberg hook once.

Because the config is user-scoped, `install.sh codex` is the one target that reaches outside the current project. `uninstall.sh` takes the block back out.

The Codex *plugin* route carries the skill only. `codex features list` reports `plugin_hooks` as **removed**, so the `hooks` key in `.codex-plugin/plugin.json` is inert on 0.153.2 — the marketplace install gives you the rules, and `install.sh codex` gives you the per-turn swap.

### Upgrading a script install

Pull the repo and re-run the same target (`install.sh codex`, `cursor`,
`windsurf`, `copilot`, or `agents`). The installer replaces its old static setup:

- Codex removes the marked iceberg block from `AGENTS.md`, keeping user text.
- Cursor installs the skill and removes iceberg's old rule and hook entries.
- Windsurf, Copilot, and `agents` install the skill and remove their old marked blocks.

Skill installs now load on demand. Activate iceberg in a new session after
upgrading. Cursor's old hook script remains as an inert compatibility stub;
Python 3 is needed only to remove its old JSON registration safely while keeping
other hooks. Without Python 3, the installer leaves the inert registration in place.
Skills installed by another tool are left alone; update those with that tool.

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
`evals/snapshot-short.json`. Reproduce it with `python3 evals/run.py` — about $2 on
Sonnet.

These are historical output-token measurements, not a benchmark of the current
trimmed prompts or their input-token savings.

Those numbers cover the four-line path. The separate `-a` suite and its
results are documented in [`evals/README.md`](./evals/README.md).

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

If you cloned the repo, `git pull` updates hook prompts on disk. Re-run
`install.sh <target>` to migrate an older static install or refresh a copied skill.

## Customize

Three files with separate jobs:

- `short.md` — the short form the hook injects on a normal turn
- `long.md` — what the hook injects instead on a `-a` turn
- `skills/iceberg/SKILL.md` — the standalone skill, with both modes and their triggers

Edit the file for your install path. To change the hook flag, edit the matcher
in `hooks/inject.sh`; changing a prompt does not change routing. To change the
standalone flag, edit the skill. Re-run the installer after editing a copied skill.

## Why "iceberg"

Hemingway's Iceberg Theory: omit what the reader can infer. The omitted part is still there, and it is what gives the writing its weight.

> *"The dignity of movement of an iceberg is due to only one-eighth of it being above water."*

## License

MIT
