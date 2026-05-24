#!/usr/bin/env python3
"""
PostToolUse hook: reminds to run /code-review after significant git commits.
Triggers when:
  - commit message contains "Phase"   (end-of-phase commit)
  - OR more than 3 Swift files changed (large code change)
"""
import json, sys, subprocess, os

data = json.load(sys.stdin)
cmd  = data.get("tool_input", {}).get("command", "")

if "git commit" not in cmd:
    sys.exit(0)

has_phase = "Phase" in cmd

try:
    result = subprocess.run(
        ["git", "show", "--name-only", "--pretty=format:", "HEAD"],
        capture_output=True, text=True,
        cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    )
    swift_files = sum(1 for line in result.stdout.splitlines() if line.endswith(".swift"))
except Exception:
    swift_files = 0

if has_phase or swift_files > 3:
    print(json.dumps({
        "systemMessage": "💡 Запусти /code-review — проверь изменения на баги и tech debt"
    }))
