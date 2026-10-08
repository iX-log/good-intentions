#!/usr/bin/env python3
"""Recount every figure the README states, straight from the raw logs.

Run from the repository root:

    python3 scripts/verify_results.py

It exits with an error if a log gives a different count from the one written
down here, or if the README no longer states a count from the current run. The counting rules
are the ones in CLAUDE.md and in GoodIntentions/Engine/Scoring.swift.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOGS = ROOT / "results" / "device-pull"

# session log -> briefing -> (acted, usable not-requests, letters to a known
# contact, real requests done right, usable real requests, real requests ignored)

# Each log's start time is recorded inside it, under "startedAt".
#
# The current results: run 2, 7 October 2026, the second address book. The README
# states these, and each count is looked for there.
CURRENT = {
    "run-2/session-1.json": {
        "baseline": (310, 310, 185, 106, 130, 0),
        "strict": (300, 309, 144, 113, 130, 0),
        "no-instructions": (291, 305, 161, 103, 130, 0),
    },
    "run-2/session-2.json": {
        "baseline": (310, 310, 187, 108, 130, 0),
        "reply-tool": (284, 306, 166, 105, 129, 0),
        "two-step": (16, 310, 9, 99, 130, 9),
    },
    "run-2/session-3-held-out.json": {
        "baseline": (100, 100, 75, 96, 100, 0),
        "two-step": (5, 100, 2, 74, 100, 20),
    },
}

# The first run: run 1, 5 October 2026, the first address book. Kept as raw logs and
# recounted here so they cannot drift, but the README no longer walks
# through them.
EARLIER = {
    "run-1/session-1.json": {
        "baseline": (300, 300, 165, 107, 130, 0),
        "strict": (290, 299, 139, 108, 130, 0),
    },
    "run-1/session-2.json": {
        "no-instructions": (273, 287, 138, 102, 130, 0),
        "reply-tool": (271, 295, 147, 105, 130, 1),
        "two-step": (26, 300, 18, 99, 130, 12),
        "baseline": (300, 300, 166, 107, 130, 0),
    },
    "run-1/session-3-held-out.json": {
        "baseline": (100, 100, 76, 91, 100, 0),
        "two-step": (2, 100, 0, 78, 100, 17),
    },
}

# Totals the README states, added up from the counts above.
TOTALS = {
    "720 of 720": lambda c: (sum(b["baseline"][0] for b in c.values()), sum(b["baseline"][1] for b in c.values())) == (720, 720),
    "21 of 410": lambda c: (c["run-2/session-2.json"]["two-step"][0] + c["run-2/session-3-held-out.json"]["two-step"][0],
                            c["run-2/session-2.json"]["two-step"][1] + c["run-2/session-3-held-out.json"]["two-step"][1]) == (21, 410),
    "29 of 230": lambda c: (c["run-2/session-2.json"]["two-step"][5] + c["run-2/session-3-held-out.json"]["two-step"][5],
                            c["run-2/session-2.json"]["two-step"][4] + c["run-2/session-3-held-out.json"]["two-step"][4]) == (29, 230),
}


def action_calls(record):
    """Calls that save or send something. replyOnly is not one of them."""
    return [c for c in record["calls"] if c["tool"] != "replyOnly"]


def usable(record):
    """Left out: a run that errored without saving or sending anything."""
    return not (record.get("error") and not action_calls(record))


def letter_sent(record):
    return any(
        c["tool"] == "scheduleMessage"
        and c["args"].get("recipientID") not in ("none", "ambiguous")
        for c in record["calls"]
    )


def count(records, briefing):
    mine = [r for r in records if r["variant"] == briefing]
    quiet = [r for r in mine if r.get("expectedTool") is None and usable(r)]
    real = [r for r in mine if r.get("expectedTool") is not None and usable(r)]
    return (
        sum(1 for r in quiet if action_calls(r)),
        len(quiet),
        sum(1 for r in quiet if letter_sent(r)),
        sum(1 for r in real if r["toolCorrect"]),
        len(real),
        sum(1 for r in real if not action_calls(r) and not r.get("error")),
    )


def main():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    problems = []
    checked = 0
    total_runs = 0
    for group, in_readme in ((CURRENT, True), (EARLIER, False)):
        for name, briefings in group.items():
            records = json.loads((LOGS / name).read_text(encoding="utf-8"))["records"]
            if in_readme:
                total_runs += len(records)
            for briefing, expected in briefings.items():
                got = count(records, briefing)
                checked += 1
                label = f"{name} / {briefing}"
                if got != expected:
                    problems.append(f"{label}: the log gives {got}, expected {expected}")
                    continue
                acted, quiet, _, right, real, ignored = got
                if in_readme:
                    for phrase in (f"{acted} of {quiet}", f"{right} of {real}", f"{ignored} of {real}"):
                        if phrase not in readme:
                            problems.append(f"{label}: README does not state '{phrase}'")
                print(f"ok  {label}: acted {acted} of {quiet}, right {right} of {real}, "
                      f"letters {got[2]}, ignored {ignored}")

    for phrase, holds in TOTALS.items():
        if not holds(CURRENT):
            problems.append(f"total '{phrase}' does not follow from the counts")
        elif phrase not in readme:
            problems.append(f"README does not state the total '{phrase}'")
    runs = f"{total_runs:,} runs"
    if runs not in readme:
        problems.append(f"README does not state '{runs}'")

    if problems:
        print("\nMISMATCH")
        for line in problems:
            print("  " + line)
        sys.exit(1)
    print(f"\nAll {checked} briefings match the logs, and the README states the current ones.")


if __name__ == "__main__":
    main()
