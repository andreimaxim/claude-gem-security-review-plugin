# Evaluator workflow

Research Rails **7.0.8.7 → 8.1.4** against
[Margin Notes](https://github.com/andreimaxim/margin-notes). The frozen corpus has
21 scored upgrade impacts and nine unchanged controls. Ten further diagnostics
are unscored. [BASELINE.md](BASELINE.md)
defines the stacks and limits.

Run evaluation preparation and grading here. Start testing agents in fresh
Margin Notes Orbs, with the plugin and frozen request, rather than a thread that
has read the rubric. Keep evaluator patches, evidence and grading results out
of the testing agent's workspace. Public answers can still be fetched online;
this is not a contamination-proof benchmark.

## Orb setup

Add `andreimaxim/margin-notes` to this Amp project's **Other repos to check out**.
Amp provides the application alongside this repository. The root `.agents/setup`
calls `evals/setup`: it prepares the app's PostgreSQL/Redis services and baseline
bundle, installs Ruby 3.2.9 through mise, trusts both project configurations,
installs the target bundle, Claude Code 2.1.296 and Agent SDK 0.3.296. Setup runs no tests or trials.
Resume restarts managed services without installing dependencies.

For manual setup, run from `evals/`:

```sh
./setup
eval "$(~/.local/bin/mise activate bash --shims)"
```

`MARGIN_NOTES_ROOT` overrides the default additional-repository path. Ruby is
selected through `.ruby-version`; use ordinary Ruby and Rails commands with mise
activated or its shims on PATH. No `mise exec` prefix is needed.

## Reproduce the upgrade and reference repair

The application must match `fixture_source.json`, with no tracked or untracked
changes. **Use a disposable evaluator Orb and do not edit the app during this
check.** It temporarily patches the existing checkout and uses the app's test
database for the repaired suite. Observation databases are separately created
and dropped. It reverses its own patches on success or an ordinary exception;
an interrupted process may require reversing the applied stages manually.

```sh
ruby verify.rb
ruby check.rb /path/to/margin-notes /tmp/upgrade-observations.json
```

The result file must not already exist. The check runs the baseline, upgrades
Rails, records each of six prerequisite failures immediately before repairing
it, and compares the remaining observations after those repairs. It then applies
the complete reference repair plus Minitest tests and checks both seeds. Success:

```text
34 runs, 90 assertions, 0 failures, 0 errors, 0 skips
34 runs, 90 assertions, 0 failures, 0 errors, 0 skips
PASS: 21 distinct upgrade impacts and 9 controls reproduced.
```

To inspect a repaired app yourself, apply these from its root in a disposable Orb:

```sh
git apply /path/to/claude-gem-security-review-plugin/evals/patches/rails-8.1-fixes.patch
git apply /path/to/claude-gem-security-review-plugin/evals/patches/regression-tests.patch
bundle install
bin/rails db:prepare
bin/rails test --seed 12345
```

Keep the baseline repository unchanged for research trials. The complete repair
patch includes the exact target lockfile and compatibility fixes; `patches/stages/`
contains the individual prerequisites used to reproduce otherwise masked errors.

## Freeze the request and evidence

The primary tool request is:

```json
{"gem":"rails","currentVersion":"7.0.8.7","requestedVersion":"8.1.4"}
```

The fixed runner prompt is defined in `run.rb` and hashed by `freeze.json`:

> Research the application impact of upgrading rails from 7.0.8.7 to 8.1.4. Use the gem-upgrade research tool once and wait for its report.

The researcher starts with a minimal system prompt asking for application impact
and source-backed findings, with read-only tools and a three-string contract.
Preparation also defines overlapping component requests for
actionpack, actionview, activejob, activerecord and activesupport at those exact
versions, plus a Jbuilder 2.13.0 → 2.13.0 control. These overlap; they are not
independent issue sets. An additional Redis 4.8.1 → 5.4.1 request is available for
an exploratory end-to-end check, with no frozen quality rubric. There are eight
requests. Use five fresh runs per model/prompt configuration for each selected
benchmark case, recording separate results rather than pooling discoveries.

For the Redis smoke trial, `redis.Gemfile.lock` holds Rails at 7.0.8.7 while
upgrading the client to 5.4.1. `ruby redis_check.rb /path/to/margin-notes
/tmp/redis-observations.json` checks the current app observations and its five
Minitest smoke tests under both clients. These callers use Rails.cache; they
do not establish a positive benchmark for unused Redis command APIs.

`sdk-runner.mjs` freezes the main agent's dispatcher system prompt. The researcher
has its own whole system prompt from `prompts/research.md`; it does not inherit
the dispatcher prompt. Project CLAUDE.md instructions are loaded separately.

`freeze.json` hashes the plugin, rubric, scripts, target lockfile, reference
patches and app pin. The app Git tree pins its baseline source and lockfile.
`sources.json` independently hashes exact tagged source copies. `verify.rb`
checks these identities, unique IDs, source presence, anchors and expected
before/after distinctions. An anchor alone does not prove an issue: inspect the
source semantics and run `check.rb` before accepting a corpus change.
`capture_sources.rb` and `freeze.rb` refuse to overwrite a freeze. Revisions
require a reviewed commit and new runtime verification, never a change made to
improve a candidate score. Preserve results with their original manifest.

## Prepare a package

```sh
ruby prepare.rb /path/to/margin-notes /tmp/notebook-package
```

Use a new destination outside this repository. Preparation packages tracked app
files and the frozen plugin, adding a logging-only observer for resolved worker
model/effort. The manifest and evaluator files remain outside worker mounts.
The tar includes tracked encrypted credentials ciphertext; decryption keys,
generated databases, logs and Git history are excluded.

The SDK runner uses Bubblewrap for an answer-free local worker
mount with fresh HOME and no evaluator checkout or Git credentials. Separate
testing-agent Orbs provide the intended workspace boundary; namespace testing
is not a prerequisite for the Rails reproduction above. `test_workflow.rb`
checks package/live-source parity, deterministic packaging and handoff/grading
protocol cases. It runs no isolation checks or model sessions.

## Run one selected Claude trial

This consumes model usage. Supply `ANTHROPIC_API_KEY` or
`CLAUDE_CODE_OAUTH_TOKEN` through a secret manager. `CLAUDE_RUNTIME` can select an
installed CLI/SDK prefix. Each call uses a fresh session; no paid batch runs implicitly.
The SDK budget is $5 per session, with a 900-second runner deadline and no retries.

```sh
ruby run.rb /tmp/notebook-package rails /tmp/notebook-run-01
ruby summarize.rb /tmp/notebook-run-01
```

The runner keeps streaming stdin open until worker completion and the main
follow-up, matches the three tool inputs, and binds the report to the acknowledged
worker ID. It requires the exact ID-bearing completion payload in a successful
task-notification-origin result, joining events in either order. An explicit
conflicting run ID is rejected. This verifies functional report delivery, not
authenticated producer provenance. It retains raw traces, request, manifest,
native main/subagent JSONL transcripts, stderr, timing and handoff state.
Summarization deduplicates tool
IDs and uses the final usage record rather than summing streaming messages.
Unresolved model/effort is flagged. Cost fields are estimates, not invoices.
Preserve execution failures separately from research-quality results.

Commit reviewed evidence under `evals/results/<case-and-run>/`: preserve the
original report, raw SDK trace, native session transcripts, request, manifest,
summary, stderr and independent review. Scan for credentials before publication.
Record hashes and label any redactions. One-time smoke checks are not five-run
benchmark groups and cannot establish run-to-run variation.

## Grade independently

Give a reviewer the report, rubric and tagged evidence, without model, effort,
timing or cost metadata. Require literal quotations and source-backed reasoning.
For `rails`, review all 21 positives; for a component, review its rows. Compare
negative statements against all nine controls and record contradictions as
false claims. Same-version requests have no expected positives. Redis smoke
reports require a source/runtime review, not a score against the Rails rubric.

```json
{
  "report_sha256": "SHA-256 of report.txt",
  "findings": [{
    "id": "U001", "status": "found", "quote": "literal report quotation",
    "reason": "why the report establishes this app/source distinction",
    "sources": ["exact URL from sources.json"]
  }],
  "false_claims": []
}
```

Include every expected issue, using `found`, `omitted` or `uncertain`; omissions
have empty quotations. False claims require `quote`, `reason` and frozen
`sources`. References can use `sources.json` URLs or the pinned app's GitHub blob
URLs for paths recorded in the package manifest. The reviewer owns semantic
correctness, not a keyword matcher.

```sh
ruby grade.rb /tmp/notebook-run-01 /private/review-01.json
```

The validator checks completeness, literal quotes, frozen references and report,
request and rubric identity. It writes review-hash filenames without overwriting.
Keep initial reviews and adjudications separately. A successful transport check
does not certify research accuracy or benchmark repeatability.

See [EXPERIMENTS.md](EXPERIMENTS.md) for prompt iteration and independent holdouts.
