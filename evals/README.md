# Evaluator-only workflow

This directory must not be mounted in the testing agent's environment. The
worker sees a prepared application and plugin only. Run preparation and grading
as the evaluator; start the research agent with a fresh session, not the thread
that has read this rubric.

The application is [margin-notes](https://github.com/andreimaxim/margin-notes).
`fixture_source.json` pins its revision and tree. Supply the
existing application directory in the Orb to preparation and runtime checks.
They require that exact revision with no tracked changes.
The benchmark compares Rails 8.0.5 → 8.1.4.
App tests and guides contain no rubric; answer-bearing material stays here.
Runtime verification of the current frozen revision is pending. Hash generation
records file identity; it is not a substitute for running the checks below.

Run the commands below from `evals/`, with mise activated or the setup-installed
shims on `PATH`. Use the app's own orb setup to install its baseline bundle.
This project's `.agents/setup` delegates to `evals/setup`, which installs the
evaluator toolchain, target bundle and pinned CLI. Runtime comparison explicitly
selects each stack's Gemfile; mise needs no `BUNDLE_GEMFILE` setting.

## Orb setup

In this Amp project's settings, add `andreimaxim/margin-notes` to **Other repos
to check out**. Amp makes the application available alongside this repository
in the Orb. Pass that checkout's absolute path as `APP_DIRECTORY`.

The application must be at the revision in `fixture_source.json` with no tracked
changes. Additional-repository checkout alone does not guarantee that version.
Prepare each repository's dependencies from its own directory:

```sh
cd /path/to/margin-notes
./.agents/setup
cd /path/to/claude-gem-security-review-plugin/evals
./setup
eval "$(~/.local/bin/mise activate bash --shims)"
```

This project's root `.agents/setup` invokes the evaluator setup automatically
when Amp prepares an Orb. Setup installs dependencies; it runs no tests or model
trials. Checking out both repos does not isolate the worker: use the prepared
package and runner below, which exclude the evaluator checkout from its mounts.

## Freeze and validate before trials

The committed `freeze.json` hashes the application revision pin, plugin, rubric,
target lockfile and evaluator scripts. The app's Git tree pins its baseline
lockfile and source files. `sources.json` independently hashes the two
exact tagged source copies. `verify.rb` checks identities, unique IDs, source
pairs, anchors, positive before/after distinctions and unchanged controls.
`check.rb` checks app paths and boots the same unmodified app on both locked stacks, migrates
disposable file databases, checks 20 impacts/seven controls, and exercises health,
creation, Jbuilder listing, a real SSE endpoint and inline job serialization.
No target-only prerequisite patching is needed.

```sh
ruby verify.rb
ruby check.rb /path/to/margin-notes
```

Review source semantics before accepting a row; a hash or source anchor alone
does not prove it. New rubric versions require a reviewed commit and rerunning
the same runtime checks. `capture_sources.rb` and `freeze.rb` refuse to overwrite
an existing freeze. Remove/replace a freeze only in that explicit revision,
never to make a candidate score better. Preserve old results with their original
manifest and review, rather than silently regrading them.

## Prepare an answer-free package

```sh
ruby prepare.rb /path/to/margin-notes /tmp/notebook-package
ruby test_workflow.rb /path/to/margin-notes
```

Choose a new directory outside the evaluator repository. Preparation packages
only tracked files from the pinned app and frozen plugin files from this repository.
It never includes this repository's evaluator files in either worker mount.
The reproducible application tar contains the app's tracked files, including its
encrypted credentials ciphertext. Decryption keys, generated databases, logs and
Git history are excluded. The plugin copy adds a logging-only observer
to capture worker step model/effort; it does not change the original plugin or
override its model/effort/tools. The request manifest and count live outside both
worker mounts. Five upgrade requests (Rails and four used components) overlap
in coverage; they are not five new issue sets. An additional Jbuilder same-version
request is a control. The 20 positive issues and seven nonissue assertions are
separate from request/trial counts.

On Linux, the actual runner uses Bubblewrap user, mount and PID namespaces. It
mounts only `/app`, `/plugin`, the pinned CLI runtime, system binaries/libraries,
DNS and public CA certificates. The app/plugin are read-only; HOME, `/tmp` and
`/proc` are fresh. The evaluator checkout, host HOME, parent processes and result
directory are absent. The containment test probes known absolute rubric paths,
parent directories, `/proc/1/root` and app writes, and runs Claude's version check
inside the same namespace. Unsupported namespace setup is a failure, never an
invitation to run the agent unisolated.

This is a filesystem boundary, **not an Internet secrecy boundary**. The public
repository's answer key could be fetched online. Do not
claim contamination-proof evaluation. Start candidates without prior findings,
do not mount the evaluator checkout, and do not forward GitHub credentials.

## Run one explicitly selected trial

This command consumes model usage; setup/checks do not. Supply provider
authentication via `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` through your
secret manager, not a checked-in file. The worker receives only these explicit
authentication/proxy variables, not the evaluator environment, Git credentials,
global effort overrides or host Claude settings. No authentication file is
mounted. `CLAUDE_RUNTIME` can select an already installed isolated CLI prefix.

```sh
ruby run.rb /tmp/notebook-package rails /tmp/notebook-run-01
ruby summarize.rb /tmp/notebook-run-01
```

For run-to-run variance, repeat `run.rb` with the same package and case but new
output directories, then summarize and grade each independently. Every invocation
starts a fresh agent session. Choose the number of repetitions explicitly; there
is no automatic paid batch. Keep per-run recall/false claims/uncertainty rather
than pooling findings across trials, and record execution failures separately.

The runner keeps streaming stdin open through the worker notification and main
follow-up result in either arrival order. It matches the actual three tool inputs
to the selected request and binds the report to the acknowledged worker ID.
The plugin mount must match the manifest's exact file set; output directories
must be outside worker-mounted plugin and CLI directories.
It retains raw stdout/stderr, request, preparation manifest,
exit status, timing and handoff state. It stops after 900 seconds, preserves
failure evidence and never retries. `test_workflow.rb` checks the streaming
lifecycle using a local protocol peer, **not a model trial**. Native CLI tests and
strict validation check the plugin contract, not research accuracy.

Summarization deduplicates tool-use IDs and retains the final result's usage
record, not the sum of repeated streaming messages. Missing resolved worker
model/effort is explicitly flagged; registration is not a substitute for an
observed resolved model. Cost fields are provider/list-price estimates, not
invoices. Raw trace data remains the source of truth. Execution failures must
remain separate from research-quality findings.

## Grade reports without revealing trial identity

Give an independent reviewer only `report.txt`, the rubric and tagged evidence,
not execution/summary files containing model, effort, timing or cost. Have them
record exact report quotations, omitted findings, uncertainty and false claims.
`grade.rb` validates a review JSON against the report hash and frozen source URLs:

```json
{
  "report_sha256": "SHA-256 of report.txt",
  "findings": [
    {
      "id": "U001",
      "status": "found",
      "quote": "literal report quotation",
      "reason": "why this meets or misses the source/app distinction",
      "sources": ["exact URL from sources.json"]
    }
  ],
  "false_claims": []
}
```

Include every expected issue for the requested gem (all issues for `rails`).
Statuses are `found`, `omitted`, `uncertain`; omissions use an empty quote.
False claims have literal `quote`, `reason` and frozen `sources`. Same-version
requests have no expected positive findings; inspect spurious change claims.
Compare negative statements with all seven control assertions as part of the
review, and record contradictions as false claims. Do not treat a keyword match
or a source URL as semantic correctness.

```sh
ruby grade.rb /tmp/notebook-run-01 /private/review-01.json
```

The validator checks completeness, literal quotations and references; the reviewer
still owns semantic judgment. It requires the report hash to match both its
captured summary and review, and the request to match its manifest case.
It rejects a checkout whose freeze differs from the
trial's manifest. Grades use review-hash filenames and refuse overwriting.
Preserve initial reviews and adjudications as separate files. Paid model trials
have not certified this workflow end to end.
