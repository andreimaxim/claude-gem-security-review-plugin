# Validation evidence

Each runtime check records its app pin in its observations JSON. The paid
trial's pin remains in `manifest.json`; these are different snapshots, not
interchangeable runs. The current app pin simplifies orb setup/resume and their
documentation; application code, dependencies and benchmark expectations are
unchanged. Setup and resume passed with PostgreSQL accepting connections and
Redis returning `PONG`. No new model session was run.

## Rails ground truth

`ruby evals/check.rb APP_DIRECTORY NEW_RESULTS_JSON` reproduced 21 scored
impacts, nine controls and ten unscored diagnostics. Six boot prerequisites were
recorded before their individual repairs. The full reference repair and Minitest
patch passed both seeds:

```text
34 runs, 90 assertions, 0 failures, 0 errors, 0 skips
34 runs, 90 assertions, 0 failures, 0 errors, 0 skips
PASS: 21 distinct upgrade impacts and 9 controls reproduced.
```

The check restored the clean application checkout. JSON records actual versions,
observations, app identity, rubric version and the freeze used for this check.

## Redis ground truth

`ruby evals/redis_check.rb APP_DIRECTORY NEW_RESULTS_JSON` held Rails at 7.0.8.7,
Ruby at 3.2.9 and the servers fixed, using Redis 4.8.1 and 5.4.1 bundles:

```text
baseline: 5 runs, 20 assertions, 0 failures, 0 errors, 0 skips
target: 5 runs, 20 assertions, 0 failures, 0 errors, 0 skips
PASS: current app observations and smoke suite agree under both Redis clients.
```

`runtime-observations.json` is the trial-pin check; `current-redis-runtime-observations.json`
is the corrected corpus-pin check. Neither is a positive-issue Redis rubric.

## Plugin, transport and evidence

- Claude Code 2.1.296: plugin tests **5 pass, 0 fail**; strict plugin validation passed.
- `ruby evals/verify.rb`: frozen plugin/app/rubric identity and **105 tagged source files** passed.
- `ruby evals/test_workflow.rb APP_DIRECTORY`: deterministic packaging, live-file parity,
  overwrite rejection, valid/invalid handoff cases, deduplication and grading identity passed.
- Exactly one paid SDK session: one matching research dispatch; observed worker
  `claude-opus-5-5` / `low`; task completed; main result exactly equals the labelled
  original report. Corrected matcher accepts this saved trace offline.
- Original runner outcome remains `execution_failure`: it expected the wrong
  origin and was stopped while idle. A normal corrected SDK shutdown was not rerun.
- Native main/subagent JSONL was copied from the live worker's projects directory
  before stopping it. Normal SDK export did not occur in this trial.
- An unpaid temporary Node process wrote a native JSONL checkpoint in the runner's
  persistent log mount; the checkpoint survived process-group TERM. The scratch
  check was removed. This checks retention, not filesystem isolation.
- Evidence was scanned against available provider credential values and Anthropic
  token patterns without printing those values; no matches. No redactions applied.

## Report rendering

The self-contained HTML uses the established individual-report detail layout:
compact run metadata, severity-bordered review findings, literal quotations and
evidence, followed by the complete original report shown directly. Execution
diagnostics and runtime checks sit in secondary detail after the original text.
It was rendered with agent-browser Chromium at 1280px and 390px, both at 2× scale.
The evidence disclosure and JSON/CSV download buttons were exercised. The original
text matches the retained report; no external assets load and no document overflow
occurs at either width. Desktop, original-report and narrow-layout screenshots
were inspected. No model session or grading change was involved in rendering.

Code-review outcomes and their limits are in `REVIEWERS.md`. This evidence does
not establish five-run benchmark repeatability or authenticated worker provenance.
