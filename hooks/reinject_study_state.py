"""SessionStart hook (matcher: compact).

After auto-compaction, print the active study's state verbatim so it re-enters
context exactly rather than via the lossy compaction summary. Stdout from a
SessionStart hook is added to Claude's context.

The active study is whatever path the research-loop skill last wrote to
<project>/.claude/active-study, where <project> is $CLAUDE_PROJECT_DIR (or the
current directory). Prints nothing (and exits 0) if there is none.
"""
import csv
import io
import os
import re
import sys
from pathlib import Path

POINTER = Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()) / ".claude" / "active-study"
MAX_LEDGER_ROWS = 40


def read(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def next_section(log: str) -> str:
    m = re.search(r"^## Next\s*$(.*?)(?=^---\s*$|^## |\Z)", log, re.M | re.S)
    return m.group(1).strip() if m else "(no Next section found)"


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    if not POINTER.exists():
        return
    study = Path(read(POINTER).strip())
    if not study.is_dir():
        return

    out = io.StringIO()
    w = out.write
    w(f"# Context was compacted. Active research-loop study: {study}\n")
    w("Below is the study state, taken verbatim from its files. Trust these over the "
      "compaction summary. Per the research-loop session budget, finish the current step, "
      "write the section 5 report with STATUS: CONTINUE, commit, and end the session.\n\n")

    w("## BRIEF.md\n" + read(study / "BRIEF.md").strip() + "\n\n")
    w("## RESEARCH_LOG.md -> Next\n" + next_section(read(study / "RESEARCH_LOG.md")) + "\n\n")

    ledger = read(study / "tests.csv")
    if ledger.strip():
        rows = list(csv.reader(io.StringIO(ledger)))
        header, body = rows[0], [r for r in rows[1:] if any(c.strip() for c in r)]
        counts = {}
        for r in body:
            d = dict(zip(header, r))
            counts[d.get("outcome", "?") or "?"] = counts.get(d.get("outcome", "?") or "?", 0) + 1
        w(f"## tests.csv: {len(body)} tests tried; by outcome: {counts}\n")
        shown = body[-MAX_LEDGER_ROWS:]
        if len(body) > len(shown):
            w(f"(showing last {len(shown)} rows)\n")
        buf = io.StringIO()
        csv.writer(buf, lineterminator="\n").writerows([header] + shown)
        w(buf.getvalue() + "\n")

    sys.stdout.write(out.getvalue())


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # never block a session over the hook
        sys.stdout.write(f"(reinject_study_state hook failed: {e})\n")
