# Evals

What iceberg actually saves, measured — not estimated, and not from hand-written
examples.

```bash
python3 run.py                # short suite, 45 calls, writes snapshot-short.json
python3 run.py --suite long   # -a suite, 36 calls, writes snapshot-long.json
python3 run.py --report       # re-print the table, no calls
python3 run.py --model opus
```

Two suites. `short` measures the default rules in `short.md`. `long` measures
the `-a` rules in `long.md`. They answer different questions, and their
numbers do not combine.

## The three arms

Every prompt runs three times, through the same Claude Code the plugin targets:

| Arm | System prompt |
|---|---|
| `baseline` | none |
| `terse` | `Answer concisely.` |
| `iceberg` | `Answer concisely.` + `short.md` |

Token counts come from `usage.output_tokens` in the API response. They are
exact.

## Read `iceberg` vs `terse`

That is the honest delta — what the rules add on top of simply asking for
brevity, which is what a user would otherwise do for free.

Comparing against `baseline` instead conflates the rules with the generic ask
and inflates the number. Both are printed; only the first one is the claim.

## The harness must not measure the plugin twice

If iceberg is enabled in your own `~/.claude/settings.json`, its
`UserPromptSubmit` hook fires on every `claude -p` call the harness makes —
including `baseline` and `terse`. The control arms then answer *in iceberg
style*, and the measured gap collapses toward zero.

This happened. An early run of the `long` suite put `baseline` at 1747 mean
tokens; with the hook excluded the same arm came in at 1111, and one spot check
went from 72 tokens to 537 on the identical prompt.

`ask()` now passes `--setting-sources project,local`, which drops user settings
and with them the plugin, and runs each call in an empty temp directory so no
`CLAUDE.md` reaches the context. If you fork the harness, keep both.

## Results

15 prompts, Sonnet, 2026-09-04, isolated harness. `snapshot-short.json` holds every
reply.

| Arm | Mean output tokens | Median | Max |
|---|---|---|---|
| `baseline` | 555 | 566 | 1014 |
| `terse` | 793 | 791 | 1250 |
| `iceberg` | **94** | 60 | 249 |

- **88% fewer output tokens than `Answer concisely.`**
- 83% fewer than no system prompt at all
- 11 of 15 replies held the four-line limit — see Compliance

The earlier run below is kept because the ratio held across a harness fix.

### Earlier run

15 prompts, Sonnet, 2026-09-03.

| Arm | Mean output tokens | Median | Max |
|---|---|---|---|
| `baseline` | 367 | 416 | 563 |
| `terse` | 524 | 536 | 710 |
| `iceberg` | **84** | 78 | 192 |

- 84% fewer output tokens than `Answer concisely.`
- 77% fewer than no system prompt at all
- 15 of 15 replies held the four-line limit *in that run* — see Compliance

## "Answer concisely." made it worse

The `terse` arm came in **43% longer than `baseline`** — asking a model to be brief
produced more text than not asking it anything.

The wording is the likely cause. "Concisely" is an adjective with no target, so
the model still opens with a heading, still numbers its points, still closes
with next steps — it just feels efficient while doing it. `short.md` gives a
line ceiling, a required shape, and a named thing to omit.

One run, one model, 15 prompts. Take it as a strong hint, not a law.

## Variance

Absolute token counts move a lot between runs. The ratio does not.

| Run | baseline | terse | iceberg | iceberg vs terse | terse vs baseline |
|---|---|---|---|---|---|
| 1 | 367 | 524 | 84 | 84% | +43% |
| 2 | 650 | 847 | 93 | 89% | +30% |
| 3 | 596 | 877 | 104 | 88% | +47% |
| 4 | 555 | 793 | 94 | 88% | +43% |

Run 4 is the first with the harness isolated. Same 15 prompts, same model. `baseline` nearly doubled between run 1
and run 2; the models are not deterministic and neither is their appetite for
headings.

The published claim is 84% — the lowest of the four. The backfire is quoted as a
range, 30–47%, because a single figure there would be false precision.

Re-run it before quoting a number of your own.

## Comparing against another skill

```bash
python3 run.py --compare /path/to/other/SKILL.md
```

Adds a fourth arm from any other rule file. Useful for checking where you sit,
but token count alone will mislead you: a skill that compresses a full answer
and a skill that withholds most of the answer until asked are not doing the same
job, and the shorter one is not automatically better.

## Compliance

Token count cannot tell a shaped answer from a merely short one, so `run.py`
also checks every rule a machine can check without judging taste.

| Check | Rule | Passes when |
|---|---|---|
| `bluf` | 1 | line 1 is the answer, alone — not a heading, not a list item |
| `no_preamble` | 8 | no "great question", "sure", "here's", "let me" |
| `arrow_last` | 5 | the last line starts with an arrow |
| `ceiling` | 3 | prose lines are within the limit |
| `headings_short` | 4 / 2 | every heading is 1 to 4 words |
| `no_long_para` | 4 / 2 | no run of plain lines over 3 |

`prose_lines()` counts what the ceiling covers. Fenced code blocks and table
rows are exempt — a table is permitted for parallel data, and a truncated SQL
statement helps no one.

### Where the terse rules miss

Run 4, `short` suite, `iceberg` arm:

| Check | Rate |
|---|---|
| `bluf` | 100% |
| `no_preamble` | 100% |
| `headings_short` | 100% |
| `no_long_para` | 100% |
| `ceiling` | 73% |
| `arrow_last` | **20%** |

Two known gaps.

**The ceiling.** Across four runs: 0, 1, 2 and 4 replies over the limit out of
15. The misses are all the same shape — the model answers in one line, then adds
a bullet list of causes. It keeps the required shape and breaks the ceiling.
Fixing it means either tightening rule 3 to name bullets explicitly, or
accepting that a four-item cause list is a fair use of the budget.

**The arrow.** Rule 5 asks for an arrow line last. It appears 20% of the time.
The rule is conditional — *anything I must do* — and on a question with no
action the model correctly writes none, so 100% is the wrong target. But 20% is
below what the rule implies, and the check cannot separate "nothing to do" from
"forgot". Neither is fixed today.

## The `long` suite

`-a` asks for the long answer. The eval asks whether the long answer is still
disciplined, or just long.

```bash
python3 run.py --suite long
```

12 prompts that deserve depth — architecture calls, migrations, trade-offs.
Every prompt carries a literal ` -a`. All four arms see it; only the iceberg arm
knows what it means, and the others read it as noise. That is what happens
without the plugin, so it is the fair input.

| Arm | System prompt |
|---|---|
| `baseline` | none |
| `verbose` | `Answer in detail.` |
| `iceberg-a` | `Answer in detail.` + `long.md` |

12 prompts, Sonnet, 2026-09-04. `snapshot-long.json` holds every reply.

| Arm | Mean tokens | Median | Max | Mean prose lines |
|---|---|---|---|---|
| `baseline` | 1111 | 694 | 3462 | 8 |
| `verbose` | 3343 | 3348 | 5207 | 40 |
| `iceberg-a` | **599** | 596 | 847 | 25 |

**82% fewer output tokens than `Answer in detail.`** — and the `-a` reply is
still six times the length of a default iceberg reply, which is the point.

`verbose` is the mirror image of the `short` suite's backfire: `Answer in detail.`
came in **three times longer than no system prompt at all**. Asking for depth
buys volume. `long.md` sets a ceiling and a shape, so it buys sections.

Compliance, same run:

| Check | `baseline` | `verbose` | `iceberg-a` |
|---|---|---|---|
| `bluf` | 92% | 75% | **100%** |
| `arrow_last` | 0% | 0% | **100%** |
| `ceiling` (40) | 100% | 67% | **100%** |
| `headings_short` | 75% | 0% | **92%** |
| `no_long_para` | 100% | 100% | **100%** |

`arrow_last` is 100% here against 20% in the `short` suite. A question worth `-a`
almost always has a next step, so the conditional in rule 5 fires.

## BLUF, tested

`long.md` already puts the bottom line first. The open question was whether
naming the framework — and adding its two other habits, *so what* and the
inverted pyramid — would do better.

It did not.

```bash
python3 run.py --suite long --compare variants/bluf.md
```

`variants/bluf.md` is `long.md` with rule 1 restated as BLUF, plus a *so what*
line and an explicit ordering rule: put the most load-bearing section first, so
a reader who stops halfway still holds the important half.

| | `iceberg-a` | `bluf` |
|---|---|---|
| Mean tokens | **599** | 731 |
| vs `verbose` | **82%** | 78% |
| `headings_short` | **92%** | 67% |
| `bluf` check | 100% | 92% — see below |

22% more tokens for the same job, and looser headings. The inverted-pyramid rule
invites a heading that summarises the section — `Common causes, ranked by
frequency`, `40 engineers, one Rails app` — which reads well and breaks the 1-to-4
word rule. One `long.md` reply in 12 broke the rule; the variant broke it in four.

**Discount the `bluf` check here.** It requires a break after line 1, and the
variant's own rule 2 puts the *so what* line immediately after the answer. The
single failure is the variant obeying itself, not drifting. The check encodes
`long.md`'s shape, so it cannot referee a ruleset with a different one.

The finding is not "BLUF is wrong". `long.md` *is* BLUF — bottom line first,
then depth, in fewer tokens. It just does not name the framework, and naming it
bought nothing.

One run, 12 prompts, one model. Re-run before you act on it.

To try your own ruleset, drop it in `variants/` and point `--compare` at it.

## Adding prompts

Append to `prompts-short.json` or `prompts-long.json` and re-run. Keep them realistic: things a developer
actually asks mid-task, where a wall of text is the tempting answer.

Cost: about $1.10 for the `short` suite, $1.70 for the `long` suite, on Sonnet.
