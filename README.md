# research-loop

A Claude Code plugin for running data analysis autonomously. You give Claude a direction ("does X explain Y?", "validate this product",
"explore this dataset"). It designs and runs the study itself, and it leaves an audit trail a
skeptical reviewer can follow.

It was built for environmental remote-sensing research, where datasets have defects that can invalidate a naive analysis. The method itself is domain-agnostic.

## What it makes Claude do

1. **Brief.** Turn a vague direction into a concrete, testable question (`BRIEF.md`).
2. **Audit the data first.** Check units, values, time zones, CRS, sample structure
   and gap-filling artifacts before any modelling. A defect found here counts as a result.
3. **Pre-register.** Write the hypothesis, metric, baseline, controls and falsification
   criterion before running each experiment. Every test goes into a ledger (`tests.csv`),
   so the number of tests tried is always known.
4. **Beat a trivial baseline** (climatology, group mean, persistence) and a permutation
   null, using holdouts that respect structure (leave-one-site/subject/year-out) and
   reporting effective n.
5. **Try to break every positive result.** Robustness variants, drop-one-unit checks, and an
   independent **`skeptic` subagent** that reads only the files, never the conversation, and
   returns a verdict. A claim it doesn't clear stays a *lead*.
6. **Log everything, nulls included.** Report in `FINDINGS.md` (answer, results, leads,
   nulls, data defects, caveats, what's blocked on you) and commit.
7. **Keep sessions short.** The files are the memory. Each session ends with a `Next`
   section a cold session can resume from. After auto-compaction, a hook re-injects the
   study state.

## Contents

```
.claude-plugin/          plugin + marketplace manifests
skills/research-loop/    SKILL.md (the method) and templates/study/ (the study scaffold)
agents/skeptic.md        independent hostile reviewer subagent
hooks/                   SessionStart(compact) hook that restores study state
scripts/run-study.sh     runs a study unattended as a chain of fresh sessions
```

The scaffold each study gets:

```
studies/<YYYY-MM-DD>-<slug>/   (its own git repo)
  BRIEF.md          question, data, budget, assumptions
  RESEARCH_LOG.md   Next (rewritten each session) + append-only pre-registered entries
  FINDINGS.md       answer, results, leads, nulls, data defects, caveats, blocked-on-you
  tests.csv         ledger of every test tried
  scripts/  outputs/  data/
```

## Install

As a plugin, from inside Claude Code:

```
/plugin marketplace add Npontone/research-loop
/plugin install research-loop@research-loop
```

Or copy it by hand into a project:

- `skills/research-loop/` → `<project>/.claude/skills/research-loop/`
- `agents/skeptic.md` → `<project>/.claude/agents/skeptic.md`
- optional: copy `hooks/reinject_study_state.py` into `<project>/.claude/hooks/` and add the
  `SessionStart` entry from `hooks/hooks.json` to `<project>/.claude/settings.json`,
  replacing `${CLAUDE_PLUGIN_ROOT}` with the path you copied it to.

The hook needs Python 3 on PATH (`python3` or `python`). If neither is found, the hook
does nothing and the rest still works.

## Use

Ask for research in plain words, or invoke it directly:

```
/research-loop Does canopy height explain the soil-moisture residuals at site A?
```

To resume, start a new session and say "resume the study in studies/2026-11-13-foo".

### Unattended: a chain of fresh sessions

Long sessions degrade (context rot). `scripts/run-study.sh` runs a study as a chain of short
headless `claude -p` sessions. Each pass resumes from the study files, runs at most **one**
experiment, writes the report and `Next`, commits, and exits. The next pass starts with
a clean context. The chain stops when:

- `Next` says `STATUS: STOP` or `STATUS: BLOCKED`, or
- a pass makes no commit (it's stuck, so it isn't repeated), or
- it reaches `max-passes`.

```bash
# from your project root (bash, or Git Bash on Windows); the study needs one commit first
path/to/run-study.sh studies/2026-11-13-foo 6 5     # up to 6 passes, max $5 each
nohup path/to/run-study.sh studies/2026-11-13-foo > run.log 2>&1 &   # detached
```

Per-pass JSON logs go to `<study>/outputs/_sessions/`, which is gitignored. Set
`PROJECT_DIR` to launch from somewhere other than the current directory. Set
`PERMISSION_MODE` to change the `--permission-mode` (default `auto`). Unattended passes
can't answer approval prompts, so choose a mode you're comfortable leaving alone with
your files. A plugin install puts the script in the plugin cache, so for regular use
copy it somewhere handy.

## Adapting it to your project

Put your project's specifics in the project's `CLAUDE.md`, which the skill and the skeptic
both defer to: where studies go, which Python/R environment to use, the known defects in
your data, the confounds that matter in your field, and compute limits. The skills
defaults are generic.

## License

MIT. See [LICENSE](LICENSE).
