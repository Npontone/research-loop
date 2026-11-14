---
name: research-loop
description: Autonomous research loop for data analysis. Turn a general direction into a brief, audit the data, pre-register tests, run experiments with controls, try to falsify the results, log everything (nulls included), and report. Use for any research, analysis, validation or exploration task bigger than a one-off question, and when resuming a study that has a RESEARCH_LOG.md.
---

# Research loop

You are running the research yourself. The user gave a direction, not a procedure.
Work autonomously and leave a trail a sceptical reviewer, or you in a future session,
could follow.

Paths below are relative to the project root (the folder Claude Code was started in) unless
stated. If the project's `CLAUDE.md` defines its own study location, environment or
standards, those override the defaults here.

## 0. Resume or start

- **Resuming:** read the study's `BRIEF.md`, then the `Next` section of `RESEARCH_LOG.md`,
  then `FINDINGS.md`, then `tests.csv`. Continue from there. Don't redo work the log records.
  Read older log entries only when `Next` points you to them, not the whole log.
  If the study has no `METHODS.md` (it predates the template), copy it in. Fill it in for
  each experiment that already has a result, working from that experiment's script.
- **Starting:** copy the `templates/study/` folder that sits next to this SKILL.md to
  `studies/<YYYY-MM-DD>-<slug>/` (or wherever the project's `CLAUDE.md` says studies go).
  Run `git init` and fill in `BRIEF.md` from the user's direction. If the direction is vague,
  pick the most useful concrete question, write down why, and proceed. Ask only if two
  readings would lead to substantially different work and the choice is the user's.
- **Either way:** write the study's absolute path (one line) to `.claude/active-study` in the
  project root. The post-compaction hook reads it to put the study state back into context.
- Check the project's notes, `CLAUDE.md` and memory for known defects in the data you'll touch.

## 1. Audit the data (always, before any modelling)

Write `scripts/00_audit.py` (or `.R`) and log what it finds. Check at least:

- units, ranges, physical plausibility; sentinel / fill values (-999, 0, NaN coded as numbers);
  clipping or censoring
- timestamps: time zone, gaps, install/removal dates, step changes
- spatial data: CRS and datum; whether points actually land where expected
- sample structure: how many truly independent units (sites, subjects, sensors, scenes, dates)?
- whether any upstream processing (calibration, gap-fill, compositing, imputation) creates artifacts

A defect found here is a result. Record it in FINDINGS.md under "Data defects".

## 2. Pre-register, then run

For each experiment, **write a log entry before running it**:

```
### E<n> — <name>  (pre-registered <timestamp>)
Hypothesis:
Test / metric:
Method: <model/test> via <package>.<function>(<key args>); <language>
Baseline(s) it must beat:
Controls:
Would be falsified by:
```

At the same time, add one row per test to `tests.csv` with `outcome` set to `pending`.
Robustness variants and attacks (section 3) get their own rows too. The ledger, not your
memory, is the count of tests tried.

Then run it with a numbered script in `scripts/`, outputs in `outputs/E<n>/`, and append
the result to the same entry and fill in the ledger row. Don't edit the pre-registration
after seeing results. If the plan changes, add a new entry.

### Document the method, not just the action

"Fitted a regression" or "ran a permutation test" is not a method. A reader must be able
to re-implement the step from the description alone, without opening the script. For every
statistical or processing step that produces a reported number, record:

- **What:** the model or test by its proper name (OLS, logistic with L2 penalty, Theil–Sen,
  Spearman ρ, sign-flip permutation, block bootstrap, random forest...).
- **How:** language, package and function, e.g. `statsmodels.formula.api.ols`,
  `sklearn.linear_model.LogisticRegression`, `scipy.stats.spearmanr`, R `lme4::lmer`.
  Write "custom, `scripts/03_x.py:func_name`" for hand-rolled code.
- **Specification:** the formula or feature set and the response; random effects; the link
  function; transforms and scaling.
- **Settings that change the answer:** non-default arguments, and defaults that matter
  (sklearn's `LogisticRegression` is L2-penalised with C=1 by default, so say so), plus solver,
  n iterations/resamples/permutations, CV scheme and fold definition, and the random seed.
- **Inputs:** which rows and columns, filters and exclusions (with the n left after each),
  aggregation level, and window or threshold values.
- **Uncertainty:** how CIs/p-values were computed (analytic, bootstrap over what unit,
  permutation of what), and the multiple-testing correction.

Bad: `Logistic model on baseline features, leave-one-site-out AUC.`
Good: `Logistic regression, sklearn 1.4.2 LogisticRegression(penalty="l2", C=1.0,
solver="lbfgs"), features [x1, x2, x3] as site-centred means, standardised within training
folds; leave-one-site-out CV (n_sites=23); AUC via sklearn roc_auc_score; null = 1000
within-site label permutations, seed 42.`

Where it goes:

1. **Pre-registration**: the `Method:` line gives the intended method at this level of detail.
2. **Result entry**: add a `Method as run:` line, written from the script, not from memory.
   Note every deviation from the pre-registered method and why.
3. **`METHODS.md`**: one paper-style subsection per experiment (past tense, prose, every
   item above), plus the shared preprocessing. Update it whenever a result entry is written.
   It should be ready to adapt into a paper's methods section.
4. **Software versions**: each script writes `outputs/E<n>/session_info.txt` with the
   interpreter version and the versions of the packages it imports (Python:
   `sys.version` + `importlib.metadata.version(pkg)`; R: `sessionInfo()`). Copy the versions
   into the Software table in `METHODS.md`. Don't type versions from memory.
5. **`tests.csv`**: the `method` column gives the short form, e.g.
   `OLS statsmodels; HC3 SEs`. Add the column to older ledgers that lack it.

**Required controls** (use all that apply, and say why when one doesn't):

- a trivial baseline: climatology/season-only, group mean, persistence, nearest neighbour
- a null: a permutation or shuffled-label test, or a synthetic null
- a holdout that respects structure: leave-one-site/subject/scene/year-out, not random rows
- an effective-n check (autocorrelation, shared-date or shared-batch effects)
- a known-confound check (whatever is known to drive the outcome in this field)

## 3. Try to break it

Before calling anything a result, attack it:

- Does it survive a different but defensible choice of threshold, window, or outlier rule?
- Is it driven by one site, subject, date or batch? Drop each in turn.
- Does the baseline or the null explain it?
- Is it physically or mechanistically plausible in sign and size?

Log the attack and its outcome. A result that only survives one analysis path is a **lead**.

**Then get an independent review.** Commit first, so the reviewer sees the current files.
Then spawn the `skeptic` agent with the study folder path and the claim exactly as worded in
FINDINGS.md. Give it no summary of how you got there; it should judge from the files.
Paste its report into the log under the experiment as `Skeptic review`, then deal with
every objection:

- **fatal / major:** run the resolving test, or downgrade the claim to a lead
- **minor:** fix it, or write one line on why it doesn't apply

Don't argue an objection away without evidence. Only a verdict of `holds` (or `weakened`
with the suggested wording adopted) lets a claim into the **Results** section. Run the
skeptic once per claim, and again if the claim changes substantially. It doesn't need to
review nulls.

## 4. Iterate, hand off, or stop

After each experiment, decide the next most informative one and write the reason in the log.

**Session budget.** Long sessions degrade (context rot). The files are the memory, so
sessions are disposable. End the session with a full section 5 report, with `STATUS: CONTINUE`
in `Next`, when any of these happens:

- you've finished 2 experiments in this session (or 1 if told to in the prompt)
- the context has been compacted
- you catch yourself re-reading a file you already read this session, or unsure what an
  earlier experiment found

Don't push on to "just one more". A fresh session resumes from `Next` at no cost.

**Context hygiene** (keeps each session lean):

- Scripts write full results to `outputs/E<n>/` and print a short summary (at most ~20
  lines: key metrics, n, effective n, file paths). Don't print whole tables or arrays.
- Don't `cat` large files. Use `head`, a column subset or a summary script.
- Send exploratory digging, large-file inspection and debugging with long tracebacks to a
  subagent that reports back a conclusion. Keep the main session as the coordinator.
- When a long background job is running, check its log tail, not the whole log.

Stop and report when:

- the question is answered (supported, refuted, or untestable with these data)
- the budget in BRIEF.md is reached
- everything left is blocked on a human-only item (see below)
- three consecutive experiments give no new information. Report what that implies.

Long compute: run it in the background, and keep auditing or writing while it runs.

**Human-only decisions** (ask, or list under "Blocked on you"): choosing or changing the
research question, anything needing field or domain knowledge you can't get from the data,
spending money or quota, deleting anything outside the study folder, sharing anything
externally, and final interpretation for publication.

## 5. Report (every session end, not just the final one)

1. Update `FINDINGS.md`:
   - **Answer**, in one paragraph
   - **Results**, with effect sizes and uncertainty
   - **Leads**
   - **Nulls**
   - **Data defects**
   - **Caveats**
   - **Blocked on you**
   - the **number of tests tried**, counted from the rows of `tests.csv`
   - each Result and Lead names its method in short form (model, package, CV/uncertainty
     scheme) and points to its `METHODS.md` subsection
   - check that `METHODS.md` covers every experiment with a result entry
2. Rewrite `RESEARCH_LOG.md` `Next` so a cold session can resume from it alone. It replaces
   the previous `Next`; the dated entries below it stay append-only. Use the template fields:
   `STATUS:` line first (`CONTINUE`, `STOP`, or `BLOCKED`), then current state, ruled out,
   open leads, the next experiment and why, and any running background jobs. Use `STOP` only
   when a stop criterion above is met, and `BLOCKED` when everything left is human-only.
3. `git add -A && git commit` in the study repo (keep large outputs out via `.gitignore`).
4. Save non-obvious, reusable lessons to memory: data defects, tool traps, environment
   gotchas. Don't save results that are already in FINDINGS.md.
5. Tell the user, briefly: the answer, the strongest evidence and the method that produced
   it (one line: model, package, validation scheme), the biggest caveat, what's
   blocked on them, and where FINDINGS.md is.

## Never

- modify input data
- report raw n where effective n is far smaller
- report a p-value without saying how many tests were tried
- quietly drop an experiment that failed
- present a lead as a finding
- report a number without its method in reproducible detail (package, function, settings, seed)
