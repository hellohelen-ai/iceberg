#!/usr/bin/env python3
"""Measure what iceberg actually saves.

Runs every prompt through Claude Code under several system prompts and records
the output token count the API reports. No estimates, no hand-written examples.

  python3 run.py                          # short suite, writes snapshot-short.json
  python3 run.py --suite long             # -a suite, writes snapshot-long.json
  python3 run.py --model opus             # a different model
  python3 run.py --report                 # re-print the table from the snapshot
  python3 run.py --suite long --compare variants/bluf.md
"""
import argparse
import json
import re
import subprocess
import tempfile
import statistics
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).parent
ROOT = HERE.parent

TERSE = "Answer concisely."
DETAILED = "Answer in detail."

# Two suites. `short` measures the default rules against a user who simply asks
# for brevity. `long` measures the -a rules against a user who simply asks for
# depth — the same question, one level up.
#
# In the long suite every prompt carries a literal ` -a`. All arms see it.
# Only the iceberg arm knows what it means; the others read it as noise, which
# is exactly what happens without the plugin.
SUITES = {
    "short": {
        "prompts": "prompts-short.json",
        "snapshot": "snapshot-short.json",
        "rules": "short.md",
        "control": ("terse", TERSE),
        "arm": "iceberg",
        "limit": 4,
    },
    "long": {
        "prompts": "prompts-long.json",
        "snapshot": "snapshot-long.json",
        "rules": "long.md",
        "control": ("verbose", DETAILED),
        "arm": "iceberg-a",
        "limit": 40,
    },
}


def build_arms(suite: dict, compare: str | None) -> dict:
    control_name, control_text = suite["control"]
    arms = {
        "baseline": None,
        control_name: control_text,
        suite["arm"]: control_text + "\n\n" + (ROOT / suite["rules"]).read_text(),
    }
    # An optional extra arm, for tuning a ruleset against the shipped one.
    # Point --compare at any rule file, e.g. variants/bluf.md.
    if compare:
        path = Path(compare)
        if not path.is_absolute():
            path = HERE / compare
        arms[path.stem] = control_text + "\n\n" + path.read_text()
    return arms


# The eval must not measure the plugin twice. If iceberg is enabled in the
# user's own settings, its UserPromptSubmit hook injects short.md into every
# `claude -p` call — including the control arms — and the measured gap
# collapses. `--setting-sources project,local` drops user settings, and an
# empty working directory keeps any CLAUDE.md out of the context.
CLEAN = ["--setting-sources", "project,local"]
SANDBOX = tempfile.mkdtemp(prefix="iceberg-eval-")


def ask(prompt: str, system: str | None, model: str) -> dict:
    cmd = ["claude", "-p", "--model", model, "--output-format", "json",
           "--no-session-persistence", *CLEAN]
    if system:
        cmd += ["--system-prompt", system]
    proc = subprocess.run(cmd, input=prompt, capture_output=True, text=True,
                          cwd=SANDBOX)
    if proc.returncode != 0:
        raise RuntimeError(f"claude exited {proc.returncode}: {proc.stderr[:200]}")
    data = json.loads(proc.stdout)
    if data.get("is_error"):
        raise RuntimeError(f"claude returned an error: {data.get('result', '')[:200]}")
    return {
        "output_tokens": data["usage"]["output_tokens"],
        "cost_usd": data.get("total_cost_usd", 0.0),
        "text": data["result"],
    }


def run(suite_name: str, suite: dict, arms: dict, model: str, workers: int) -> dict:
    prompts = json.loads((HERE / suite["prompts"]).read_text())
    jobs = [(p, arm) for p in prompts for arm in arms]

    def one(job):
        p, arm = job
        result = ask(p["prompt"], arms[arm], model)
        print(f"  {arm:10} {p['id']:20} {result['output_tokens']:5} tokens", flush=True)
        return {"id": p["id"], "arm": arm, **result}

    print(f"{len(jobs)} calls on {model}, suite {suite_name}...", flush=True)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(one, jobs))

    return {"model": model, "suite": suite_name, "arms": list(arms), "results": results}


# --- shape checks -----------------------------------------------------------

ARROWS = ("→", "->", "➔", "➜")
PREAMBLE = re.compile(
    r"^(great question|good question|sure[,!.]|certainly|of course|happy to|"
    r"let me|i'?ll |here'?s |thanks for )", re.I)


def prose(text: str) -> list[str]:
    """The lines that count against the limit.

    Fenced code blocks and table rows are exempt — a table is allowed for
    parallel data, and no one wants a truncated SQL statement. Blank lines are
    kept as empty strings so paragraph runs stay visible.
    """
    out, in_code = [], False
    for line in text.strip().splitlines():
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code = not in_code
            continue
        if in_code or stripped.startswith("|"):
            continue
        out.append(stripped)
    return out


def prose_lines(text: str) -> int:
    return len([l for l in prose(text) if l])


def is_heading(line: str) -> bool:
    return bool(re.match(r"^#{1,6}\s", line)) or bool(re.fullmatch(r"\*\*[^*]+\*\*:?", line))


def heading_words(line: str) -> int:
    return len(re.sub(r"^#{1,6}\s|\*|:$", "", line).split())


def is_item(line: str) -> bool:
    return bool(re.match(r"^([-*+]|\d+\.)\s", line))


def is_arrow(line: str) -> bool:
    return line.startswith(ARROWS)


def shape_checks(text: str, limit: int) -> dict:
    """Every rule in the ruleset that a machine can check without judging taste."""
    lines = prose(text)
    body = [l for l in lines if l]
    if not body:
        return {}

    first = body[0]
    # Line 1 must stand alone: not a heading, not a list item, and followed by a
    # break rather than more of the same thought.
    after_first = lines[lines.index(first) + 1:]
    stands_alone = bool(after_first) and (after_first[0] == "" or is_heading(after_first[0]))

    headings = [l for l in body if is_heading(l)]

    runs, run = [], 0
    for line in lines:
        if line and not is_heading(line) and not is_item(line) and not is_arrow(line):
            run += 1
        else:
            runs.append(run)
            run = 0
    runs.append(run)

    return {
        "bluf": not is_heading(first) and not is_item(first) and (stands_alone or len(body) == 1),
        "no_preamble": not PREAMBLE.match(first),
        "arrow_last": is_arrow(body[-1]),
        "ceiling": len(body) <= limit,
        "headings_short": all(1 <= heading_words(h) <= 4 for h in headings),
        "no_long_para": max(runs) <= 3,
    }


# --- report -----------------------------------------------------------------

def report(snapshot: dict) -> None:
    suite = SUITES[snapshot["suite"]]
    results = snapshot["results"]
    arms = snapshot["arms"]
    control = suite["control"][0]
    limit = suite["limit"]

    by_arm = {arm: [r for r in results if r["arm"] == arm] for arm in arms}
    tokens = {arm: [r["output_tokens"] for r in rs] for arm, rs in by_arm.items()}

    print(f"\nmodel: {snapshot['model']}   suite: {snapshot['suite']}"
          f"   prompts: {len(tokens['baseline'])}\n")
    print(f"  {'arm':12} {'mean':>7} {'median':>7} {'max':>7} {'lines':>7}")
    for arm, toks in tokens.items():
        lines = statistics.mean(prose_lines(r["text"]) for r in by_arm[arm])
        print(f"  {arm:12} {statistics.mean(toks):7.0f} "
              f"{statistics.median(toks):7.0f} {max(toks):7} {lines:7.0f}")

    def cut(frm: str, to: str) -> float:
        a, b = statistics.mean(tokens[frm]), statistics.mean(tokens[to])
        return (a - b) / a * 100

    print()
    for arm in arms:
        if arm in ("baseline", control):
            continue
        print(f"  {arm} vs {control:12} {cut(control, arm):5.0f}%"
              + ("  <- the honest number" if arm == suite["arm"] else ""))
    print(f"  {control} vs baseline{'':6} {cut('baseline', control):5.0f}%")

    # Shape compliance. Token count alone cannot tell a shaped answer from a
    # short one, so check every rule a machine can check.
    checks = list(shape_checks(by_arm[arms[-1]][0]["text"], limit))
    print(f"\n  compliance (limit {limit} lines)")
    print("  " + " " * 12 + "".join(f"{c:>16}" for c in checks))
    for arm in arms:
        scored = [shape_checks(r["text"], limit) for r in by_arm[arm]]
        rates = [sum(s.get(c, False) for s in scored) / len(scored) * 100 for c in checks]
        print(f"  {arm:12}" + "".join(f"{r:15.0f}%" for r in rates))

    over = [r["id"] for r in by_arm[suite["arm"]] if prose_lines(r["text"]) > limit]
    if over:
        print(f"\n  over the {limit}-line limit: {len(over)}  {over}")
    print(f"\n  total cost: ${sum(r['cost_usd'] for r in results):.2f}\n")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--suite", default="short", choices=list(SUITES))
    ap.add_argument("--model", default="sonnet")
    ap.add_argument("--workers", type=int, default=5)
    ap.add_argument("--report", action="store_true", help="re-print from the snapshot")
    ap.add_argument("--compare", metavar="RULEFILE",
                    help="add an arm from another rule file, e.g. variants/bluf.md")
    args = ap.parse_args()

    suite = SUITES[args.suite]
    snapshot_path = HERE / suite["snapshot"]

    if args.report:
        if not snapshot_path.exists():
            sys.exit(f"no {suite['snapshot']} — run without --report first")
        report(json.loads(snapshot_path.read_text()))
        return

    arms = build_arms(suite, args.compare)
    snapshot = run(args.suite, suite, arms, args.model, args.workers)
    snapshot_path.write_text(json.dumps(snapshot, indent=2) + "\n")
    report(snapshot)


if __name__ == "__main__":
    main()
