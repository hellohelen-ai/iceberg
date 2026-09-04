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
- 0 of 15 replies broke the four-line limit

## "Answer concisely." made it worse

`terse` came in **43% longer than `baseline`** — asking a model to be brief
produced more text than not asking it anything.

The wording is the likely cause. "Concisely" is an adjective with no target, so
the model still opens with a heading, still numbers its points, still closes
with next steps — it just feels efficient while doing it. `prompt.md` gives a
line ceiling, a required shape, and a named thing to omit.

One run, one model, 15 prompts. Take it as a strong hint, not a law.

## Compliance

`prose_lines()` in `run.py` counts what the limit covers. Fenced code blocks
and table rows are exempt — rule 4 permits a table for parallel data, and a
truncated SQL statement helps no one.

## Adding prompts

Append to `prompts.json` and re-run. Keep them realistic: things a developer
actually asks mid-task, where a wall of text is the tempting answer.

Cost: about $1.60 per full run on Sonnet.
