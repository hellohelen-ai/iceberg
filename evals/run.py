#!/usr/bin/env python3
"""Measure what iceberg actually saves.

Runs every prompt through Claude Code under three system prompts and records
the output token count the API reports. No estimates, no hand-written examples.

  python3 run.py                 # run everything, write snapshot.json
  python3 run.py --model opus    # a different model
  python3 run.py --report        # re-print the table from the snapshot
"""
import argparse
import json
import subprocess
import statistics
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).parent
ROOT = HERE.parent
SNAPSHOT = HERE / "snapshot.json"

TERSE = "Answer concisely."

ARMS = {
    "baseline": None,
    "terse": TERSE,
    "iceberg": TERSE + "\n\n" + (ROOT / "prompt.md").read_text(),
}


def ask(prompt: str, system: str | None, model: str) -> dict:
    cmd = ["claude", "-p", "--model", model, "--output-format", "json",
           "--no-session-persistence"]
    if system:
        cmd += ["--system-prompt", system]
    proc = subprocess.run(cmd, input=prompt, capture_output=True, text=True)
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


def run(model: str, workers: int) -> dict:
    prompts = json.loads((HERE / "prompts.json").read_text())
    jobs = [(p, arm) for p in prompts for arm in ARMS]

    def one(job):
        p, arm = job
        result = ask(p["prompt"], ARMS[arm], model)
        print(f"  {arm:9} {p['id']:20} {result['output_tokens']:5} tokens", flush=True)
        return {"id": p["id"], "arm": arm, **result}

    print(f"{len(jobs)} calls on {model}...", flush=True)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(one, jobs))

    return {"model": model, "arms": list(ARMS), "results": results}


def prose_lines(text: str) -> int:
    """Lines that count against the limit.

    Code blocks and table rows are exempt — rule 4 allows a table for parallel
    data, and no one wants a truncated SQL statement.
    """
    count, in_code = 0, False
    for line in text.strip().splitlines():
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code = not in_code
            continue
        if in_code or not stripped or stripped.startswith("|"):
            continue
        count += 1
    return count


def report(snapshot: dict) -> None:
    results = snapshot["results"]
    by_arm = {arm: [r["output_tokens"] for r in results if r["arm"] == arm]
              for arm in snapshot["arms"]}

    print(f"\nmodel: {snapshot['model']}   prompts: {len(by_arm['baseline'])}\n")
    print(f"  {'arm':10} {'mean':>7} {'median':>7} {'max':>7}")
    for arm, tokens in by_arm.items():
        print(f"  {arm:10} {statistics.mean(tokens):7.0f} "
              f"{statistics.median(tokens):7.0f} {max(tokens):7}")

    def cut(frm: str, to: str) -> float:
        a, b = statistics.mean(by_arm[frm]), statistics.mean(by_arm[to])
        return (a - b) / a * 100

    print(f"\n  iceberg vs terse      {cut('terse', 'iceberg'):5.0f}%  <- the honest number")
    print(f"  iceberg vs baseline   {cut('baseline', 'iceberg'):5.0f}%")
    print(f"  terse vs baseline     {cut('baseline', 'terse'):5.0f}%")

    over = [r["id"] for r in results
            if r["arm"] == "iceberg" and prose_lines(r["text"]) > 4]
    print(f"\n  over the 4-line limit: {len(over)}/{len(by_arm['iceberg'])}"
          + (f"  {over}" if over else ""))
    print(f"  total cost: ${sum(r['cost_usd'] for r in results):.2f}\n")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="sonnet")
    ap.add_argument("--workers", type=int, default=5)
    ap.add_argument("--report", action="store_true", help="re-print from snapshot.json")
    args = ap.parse_args()

    if args.report:
        if not SNAPSHOT.exists():
            sys.exit("no snapshot.json — run without --report first")
        report(json.loads(SNAPSHOT.read_text()))
        return

    snapshot = run(args.model, args.workers)
    SNAPSHOT.write_text(json.dumps(snapshot, indent=2) + "\n")
    report(snapshot)


if __name__ == "__main__":
    main()
