# Validation evidence

The final app pin is recorded in `current-corpus-runtime-observations.json`.
The paid trial's older pin remains in `manifest.json`; these are deliberately
different snapshots, not interchangeable runs.

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

The self-contained HTML was rendered with agent-browser Chromium at 1280px and
390px, both at 2× scale. Original-report disclosure and JSON/CSV download buttons
were exercised. The original text matches the retained report; no external assets
load and no document overflow occurs at either width. Default desktop, expanded
original-report and narrow-layout screenshots were inspected and corrected.
The narrow layout uses labelled runtime cards, not clipped table columns.

Code-review outcomes and their limits are in `REVIEWERS.md`. This evidence does
not establish five-run benchmark repeatability or authenticated worker provenance.
