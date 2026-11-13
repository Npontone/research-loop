#!/usr/bin/env bash
# Run a research-loop study as a chain of short, fresh-context Claude sessions.
#
# Each pass is a new headless session: it resumes from the study files, runs at most
# ONE experiment, writes the report + Next, commits, and exits. The loop stops when
# Next says STATUS: STOP or BLOCKED, when a pass makes no commit (no progress), or
# after MAX_PASSES.
#
# Usage (bash; Git Bash on Windows). Run it from your project root, the folder you
# normally start Claude Code in, so the project's CLAUDE.md, memory, skills and hooks load:
#   path/to/run-study.sh <study-dir> [max-passes] [max-usd-per-pass]
# Example:
#   ./run-study.sh studies/2026-11-12-foo 6 5
#
# Environment overrides:
#   PROJECT_DIR      folder to launch Claude from (default: current directory)
#   PERMISSION_MODE  claude --permission-mode value (default: auto). Unattended passes
#                    need a mode that doesn't stop for approval prompts; pick one you trust.
#
# Pass logs: <study>/outputs/_sessions/pass-NN.json (gitignored).
# Detach it with:  nohup path/to/run-study.sh <dir> > run.log 2>&1 &
#   (on Linux, `setsid nohup ...` also survives closing the terminal)

set -u
STUDY="${1:?usage: run-study.sh <study-dir> [max-passes] [max-usd-per-pass]}"
MAX_PASSES="${2:-6}"
MAX_USD="${3:-}"
PROJECT_DIR="${PROJECT_DIR:-$PWD}"
PERMISSION_MODE="${PERMISSION_MODE:-auto}"
command -v claude >/dev/null || { echo "claude CLI not found on PATH"; exit 1; }

STUDY="$(cd "$STUDY" && pwd)" || { echo "no such dir: $1"; exit 1; }
STUDY_WIN="$(cygpath -m "$STUDY" 2>/dev/null || echo "$STUDY")"   # C:/... form for the prompt
LOG="$STUDY/RESEARCH_LOG.md"
[ -f "$LOG" ] || { echo "no RESEARCH_LOG.md in $STUDY"; exit 1; }
git -C "$STUDY" rev-parse HEAD >/dev/null 2>&1 || { echo "$STUDY has no commits yet; commit once first"; exit 1; }

SESS="$STUDY/outputs/_sessions"
mkdir -p "$SESS"
grep -qxF 'outputs/_sessions/' "$STUDY/.gitignore" 2>/dev/null || echo 'outputs/_sessions/' >> "$STUDY/.gitignore"

status() { grep -m1 -oE '^STATUS: *[A-Z]+' "$LOG" | sed 's/STATUS: *//'; }

PROMPT="Use the research-loop skill to resume the study at $STUDY_WIN.
This is one pass of an automated chain of fresh sessions; no human is watching.
Run at most ONE experiment (pre-register it, run it, attack it, and get the skeptic review if
it is a positive claim). Then do the full section 5 report: FINDINGS.md, tests.csv, a
rewritten Next with the STATUS line, and a git commit. Then end your turn.
Set STATUS: STOP only if a stop criterion in the skill is met, and STATUS: BLOCKED if
everything left is human-only (list it under Blocked on you). Never ask questions: record
assumptions in the log and continue."

BUDGET_ARGS=()
[ -n "$MAX_USD" ] && BUDGET_ARGS=(--max-budget-usd "$MAX_USD")

cd "$PROJECT_DIR" || { echo "no such project dir: $PROJECT_DIR"; exit 1; }
for ((i=1; i<=MAX_PASSES; i++)); do
  s="$(status)"
  if [ "$s" = "STOP" ] || [ "$s" = "BLOCKED" ]; then
    echo "[$(date '+%F %T')] STATUS: $s; stopping before pass $i"; break
  fi
  before="$(git -C "$STUDY" rev-parse HEAD)"
  out="$(printf '%s/pass-%02d.json' "$SESS" "$i")"
  echo "[$(date '+%F %T')] pass $i/$MAX_PASSES -> $out"
  claude -p "$PROMPT" --permission-mode "$PERMISSION_MODE" --output-format json ${BUDGET_ARGS[@]+"${BUDGET_ARGS[@]}"} \
    < /dev/null > "$out" 2>&1
  rc=$?
  after="$(git -C "$STUDY" rev-parse HEAD)"
  echo "[$(date '+%F %T')] pass $i exit=$rc status=$(status) commit=${after:0:8}"
  if [ "$before" = "$after" ]; then
    echo "pass $i made no commit; stopping so a stuck pass isn't repeated. See $out"; break
  fi
done
echo "done. Final status: $(status). Read $STUDY/FINDINGS.md"
