# Evaluator workflow

Research Rails **7.0.8.7 → 8.1.4** against
[Margin Notes](https://github.com/andreimaxim/margin-notes). The frozen corpus has
31 upgrade impacts and nine unchanged controls. [BASELINE.md](BASELINE.md)
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
installs the target bundle and Claude Code 2.1.296. Setup runs no tests or trials.
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
33 runs, 85 assertions, 0 failures, 0 errors, 0 skips
33 runs, 85 assertions, 0 failures, 0 errors, 0 skips
PASS: 31 distinct upgrade impacts and 9 controls reproduced.
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
versions, plus a Jbuilder 2.13.0 → 2.13.0 control. These are seven requests, not
seven independent issue sets. Repeat a selected request with the same app,
plugin and prompt, recording separate results rather than pooling discoveries.

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

The optional Linux CLI runner uses Bubblewrap for an answer-free local worker
mount with fresh HOME and no evaluator checkout or Git credentials. Separate
testing-agent Orbs provide the intended workspace boundary; namespace testing
is not a prerequisite for the Rails reproduction above. `test_workflow.rb`
exercises packaging, namespace containment and streaming/grade protocol checks;
it does not run a model or prove research accuracy.

## Run one selected Claude trial

This consumes model usage. Supply `ANTHROPIC_API_KEY` or
`CLAUDE_CODE_OAUTH_TOKEN` through a secret manager. `CLAUDE_RUNTIME` can select an
installed CLI prefix. Each call uses a fresh session; no paid batch runs implicitly.

```sh
ruby run.rb /tmp/notebook-package rails /tmp/notebook-run-01
ruby summarize.rb /tmp/notebook-run-01
```

The runner keeps streaming stdin open until worker completion and the main
follow-up, matches the three tool inputs, and binds the report to the acknowledged
worker ID. It retains raw traces, request, manifest, timing and handoff state;
it times out after 900 seconds and never retries. Summarization deduplicates tool
IDs and uses the final usage record rather than summing streaming messages.
Unresolved model/effort is flagged. Cost fields are estimates, not invoices.
Preserve execution failures separately from research-quality results.

## Grade independently

Give a reviewer the report, rubric and tagged evidence, without model, effort,
timing or cost metadata. Require literal quotations and source-backed reasoning.
For `rails`, review all 31 positives; for a component, review its rows. Compare
negative statements against all nine controls and record contradictions as
false claims. Same-version requests have no expected positives.

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
`sources`. The reviewer owns semantic correctness, not a keyword matcher.

```sh
ruby grade.rb /tmp/notebook-run-01 /private/review-01.json
```

The validator checks completeness, literal quotes, frozen references and report,
request and rubric identity. It writes review-hash filenames without overwriting.
Keep initial reviews and adjudications separately. Paid model trials have not
certified the CLI lifecycle or research accuracy end to end.

See [EXPERIMENTS.md](EXPERIMENTS.md) for prompt iteration and independent holdouts.
