#!/usr/bin/env python3
"""Evaluate skill triggering for globally installed skills.

Unlike skill-creator's run_eval which creates temp command files,
this script checks if claude -p invokes the Skill tool with the correct skill name.
"""

import json
import os
import select
import subprocess
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path


def run_single_query(query: str, skill_name: str, timeout: int = 30, model: str = None) -> str | None:
    """Run a query and return which skill was triggered (or None)."""
    cmd = ["claude", "-p", query, "--output-format", "stream-json", "--verbose", "--include-partial-messages"]
    if model:
        cmd.extend(["--model", model])

    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}

    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        cwd="/tmp",
        env=env,
    )

    buffer = ""
    pending_tool = None
    accumulated_json = ""

    try:
        start = time.time()
        while time.time() - start < timeout:
            if process.poll() is not None:
                remaining = process.stdout.read()
                if remaining:
                    buffer += remaining.decode("utf-8", errors="replace")
                break

            ready, _, _ = select.select([process.stdout], [], [], 1.0)
            if not ready:
                continue

            chunk = os.read(process.stdout.fileno(), 8192)
            if not chunk:
                break
            buffer += chunk.decode("utf-8", errors="replace")

            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                line = line.strip()
                if not line:
                    continue

                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue

                if event.get("type") == "stream_event":
                    se = event.get("event", {})
                    se_type = se.get("type", "")

                    if se_type == "content_block_start":
                        cb = se.get("content_block", {})
                        if cb.get("type") == "tool_use":
                            tool_name = cb.get("name", "")
                            if tool_name == "Skill":
                                pending_tool = "Skill"
                                accumulated_json = ""
                            else:
                                # First tool call is not Skill -> no skill triggered
                                return None

                    elif se_type == "content_block_delta" and pending_tool == "Skill":
                        delta = se.get("delta", {})
                        if delta.get("type") == "input_json_delta":
                            accumulated_json += delta.get("partial_json", "")

                    elif se_type in ("content_block_stop", "message_stop"):
                        if pending_tool == "Skill":
                            # Parse the accumulated JSON to get the skill name
                            try:
                                input_data = json.loads(accumulated_json)
                                return input_data.get("skill", "")
                            except json.JSONDecodeError:
                                return accumulated_json
                        if se_type == "message_stop":
                            return None

                elif event.get("type") == "assistant":
                    message = event.get("message", {})
                    for item in message.get("content", []):
                        if item.get("type") == "tool_use" and item.get("name") == "Skill":
                            return item.get("input", {}).get("skill", "")
                    return None

                elif event.get("type") == "result":
                    return None

        return None
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()


def eval_skill(skill_name: str, eval_path: str, model: str = None, num_workers: int = 8, runs: int = 1):
    """Evaluate triggering for a skill."""
    eval_set = json.loads(Path(eval_path).read_text())

    print(f"\n{'='*60}")
    print(f"Evaluating: {skill_name} ({len(eval_set)} queries, {runs} runs each)")
    print(f"{'='*60}")

    with ProcessPoolExecutor(max_workers=num_workers) as executor:
        future_map = {}
        for item in eval_set:
            for run_idx in range(runs):
                future = executor.submit(run_single_query, item["query"], skill_name, 30, model)
                future_map[future] = (item, run_idx)

        # Collect results
        query_results = {}
        for future in as_completed(future_map):
            item, _ = future_map[future]
            query = item["query"]
            if query not in query_results:
                query_results[query] = {"item": item, "triggers": []}
            try:
                triggered_skill = future.result()
                query_results[query]["triggers"].append(triggered_skill)
            except Exception as e:
                print(f"  Error: {e}", file=sys.stderr)
                query_results[query]["triggers"].append(None)

    # Analyze
    results = []
    for query, data in query_results.items():
        item = data["item"]
        triggers = data["triggers"]
        should_trigger = item["should_trigger"]

        correct_triggers = sum(1 for t in triggers if t == skill_name)
        any_triggers = sum(1 for t in triggers if t is not None)
        total = len(triggers)

        if should_trigger:
            passed = correct_triggers > 0
        else:
            passed = correct_triggers == 0

        other_skills = [t for t in triggers if t is not None and t != skill_name]
        results.append({
            "query": query,
            "should_trigger": should_trigger,
            "correct_triggers": correct_triggers,
            "any_triggers": any_triggers,
            "total": total,
            "passed": passed,
            "other_skills": other_skills,
        })

    # Print results
    tp = sum(1 for r in results if r["should_trigger"] and r["passed"])
    fn = sum(1 for r in results if r["should_trigger"] and not r["passed"])
    tn = sum(1 for r in results if not r["should_trigger"] and r["passed"])
    fp = sum(1 for r in results if not r["should_trigger"] and not r["passed"])

    precision = tp / (tp + fp) if (tp + fp) > 0 else 1.0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    accuracy = (tp + tn) / (tp + tn + fp + fn) if (tp + tn + fp + fn) > 0 else 0.0

    print(f"\nResults: precision={precision:.0%} recall={recall:.0%} accuracy={accuracy:.0%}")
    print(f"  TP={tp} FN={fn} TN={tn} FP={fp}")

    for r in sorted(results, key=lambda x: (x["should_trigger"], x["passed"]), reverse=True):
        status = "PASS" if r["passed"] else "FAIL"
        trigger_str = f"{r['correct_triggers']}/{r['total']}"
        other = f" (got: {r['other_skills'][0]})" if r["other_skills"] else ""
        expected = "should" if r["should_trigger"] else "should NOT"
        print(f"  [{status}] {trigger_str} {expected} trigger: {r['query'][:70]}{other}")

    return {
        "skill_name": skill_name,
        "precision": precision,
        "recall": recall,
        "accuracy": accuracy,
        "tp": tp, "fn": fn, "tn": tn, "fp": fp,
        "results": results,
    }


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--skill", required=True)
    parser.add_argument("--eval-set", required=True)
    parser.add_argument("--model", default="claude-sonnet-4-6")
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--runs", type=int, default=1)
    args = parser.parse_args()

    result = eval_skill(args.skill, args.eval_set, args.model, args.workers, args.runs)
    print(json.dumps(result, indent=2, default=str))
