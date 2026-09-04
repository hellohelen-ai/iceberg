# Evals

What iceberg actually saves, measured — not estimated, and not from hand-written
examples.

```bash
python3 run.py              # 45 calls, writes snapshot.json
python3 run.py --report     # re-print the table, no calls
python3 run.py --model opus
```

## The three arms

Every prompt runs three times, through the same Claude Code the plugin targets:

| Arm | System prompt |
|---|---|
| `baseline` | none |
| `terse` | `Answer concisely.` |
| `iceberg` | `Answer concisely.` + `prompt.md` |

Token counts come from `usage.output_tokens` in the API response. They are
exact.

## Read `iceberg` vs `terse`

That is the honest delta — what the rules add on top of simply asking for
brevity, which is what a user would otherwise do for free.

Comparing against `baseline` instead conflates the rules with the generic ask
and inflates the number. Both are printed; only the first one is the claim.

## Results

15 prompts, Sonnet, 2026-09-03. `snapshot.json` holds every reply.

| Arm | Mean output tokens | Median | Max |
|---|---|---|---|
| `baseline` | 367 | 416 | 563 |
| `terse` | 524 | 536 | 710 |
| `iceberg` | **84** | 78 | 192 |

- **84% fewer output tokens than `Answer concisely.`**
- 77% fewer than no system prompt at all
- 15 of 15 replies held the four-line limit *in this run* — see Compliance

## "Answer concisely." made it worse

`terse` came in **43% longer than `baseline`** — asking a model to be brief
produced more text than not asking it anything.

The wording is the likely cause. "Concisely" is an adjective with no target, so
the model still opens with a heading, still numbers its points, still closes
with next steps — it just feels efficient while doing it. `prompt.md` gives a
line ceiling, a required shape, and a named thing to omit.

One run, one model, 15 prompts. Take it as a strong hint, not a law.

## Variance

Absolute token counts move a lot between runs. The ratio does not.

| Run | baseline | terse | iceberg | iceberg vs terse | terse vs baseline |
|---|---|---|---|---|---|
| 1 | 367 | 524 | 84 | 84% | +43% |
| 2 | 650 | 847 | 93 | 89% | +30% |
| 3 | 596 | 877 | 104 | 88% | +47% |

Same 15 prompts, same model, three runs. `baseline` nearly doubled between run 1
and run 2; the models are not deterministic and neither is their appetite for
headings.

The published claim is 84% — the lowest of the three. The backfire is quoted as
a range, 30–47%, because a single figure there would be false precision.

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

`prose_lines()` in `run.py` counts what the limit covers. Fenced code blocks and
table rows are exempt — rule 4 permits a table for parallel data, and a truncated
SQL statement helps no one.

Across the three runs: 0, 1, and 2 replies over the limit out of 15. Call it
~93% compliance, not 100%. The misses are all the same shape — the model answers
in one line, then adds a bullet list of causes. It keeps the required shape and
breaks the ceiling.

Fixing that means either tightening rule 3 to name bullets explicitly, or
accepting that a four-item cause list is a fair use of the budget. It is not
fixed today, and the number above says so.

## Adding prompts

Append to `prompts.json` and re-run. Keep them realistic: things a developer
actually asks mid-task, where a wall of text is the tempting answer.

Cost: about $1.60 per full run on Sonnet.
