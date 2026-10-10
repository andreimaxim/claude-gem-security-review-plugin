# Gem upgrade research benchmark

A Claude Code research plugin and a reproducible benchmark using a small SQLite
Rails app. The benchmark contains **20 distinct, source-verified upgrade impacts**,
plus seven nonissue controls. These are not 20 CVEs; repeated trials do not
increase the issue count.

The standalone application is maintained in
[margin-notes](https://github.com/andreimaxim/margin-notes).
`fixture_source.json` pins the application revision and tree used by the evaluator.

Add `andreimaxim/margin-notes` to this Amp project's **Other repos to check out**
setting so the evaluator Orb has the existing app directory available. See
[Orb setup](README.md#orb-setup) for dependency setup and worker isolation.

## Run the application and checks

From this repository's `evals/` directory on an Amp Orb or Debian Linux machine
with root/sudo access:

```sh
./setup
eval "$(~/.local/bin/mise activate bash --shims)"
ruby verify.rb
ruby check.rb /path/to/margin-notes
ruby test_workflow.rb /path/to/margin-notes
```

Setup installs SQLite, Ruby through mise, the locked target bundle, Bubblewrap and Claude
Code 2.1.296. No PostgreSQL, Redis, daemon or application credential is needed.
The application's own orb setup installs its baseline bundle.
It is idempotent. Installing gems/native extensions on a fresh machine can take
several minutes; warm setup takes seconds. Ruby is selected from `.ruby-version`.
Setup puts shims on `PATH` for future shells; activate mise once in an existing
shell rather than prefixing individual commands. Ruby scripts also work with a
manually installed matching Ruby, Bundler and GNU tar.

Margin Notes is an actual Rails application, not a release-change catalogue. It
has note creation/listing, Jbuilder JSON, exports, a Live/SSE endpoint, inline
jobs, MemoryStore caching, migrations and a schema. Run Rails commands from its
application directory using `bin/rails COMMAND`.
Use `server -b 0.0.0.0` to serve the app with Puma (on an orb, start it through
`amp orb service start` with `--portal`, rather than a detached shell process).
Health, creation and listing are exercised through Rails' real Rack stack by the
runtime check. The synthetic app has intentionally brittle integration surfaces
for migration research. Its fixed development signing key and permissive hosts
are **not a production deployment configuration**.

## Exact version choices

| Surface | Baseline | Target |
| --- | --- | --- |
| Ruby | 3.4.7 | 3.4.7 |
| Rails | 8.0.5 | 8.1.4 |
| Framework defaults | 7.0 | 7.0 |
| sqlite3 gem | 2.1.0 | 2.1.0 |
| Jbuilder | 2.13.0 | 2.13.0 |
| Puma | 6.6.1 | 6.6.1 |

The baseline runs Rails 8.0.5 with retained 7.0 defaults; the target is Rails
8.1.4 without opting into newer defaults. Both Rails tags require
Ruby ≥ 3.2.0 and sqlite3 ≥ 2.1. The same runtime and driver isolate Rails behavior;
this is **not a Ruby upgrade benchmark**. SQLite engine minimums differ (3.8 vs
3.23), but the bundled engine already satisfies both, so that is not counted as
an application issue. Jbuilder is deliberately held constant rather than counted
as a speculative incompatibility. BigDecimal 3.1.8 and concurrent-ruby 1.3.4 are
held constant too. The app's baseline lockfile and this evaluator's target
lockfile freeze all resolved dependencies;
their Rails-required transitive differences remain part of the stack comparison.
Puma makes `rails server` runnable; its tagged
[gemspec](https://raw.githubusercontent.com/puma/puma/v6.6.1/puma.gemspec)
supports Ruby ≥ 2.4. It is not an additional upgrade issue.
SQLite shared-cache mode is explicitly enabled
for the fixture's read-uncommitted export transactions; no evaluator-only
connection configuration is needed.

The tagged source files, original URLs, hashes and Rails licenses are in
`evidence/` and `sources.json`. Every positive row has an app location,
source pair and a before/after assertion in `answer_key.rb`. Behavior fixes,
API/deprecation concerns and integration-review changes are distinguished; they
are not all security vulnerabilities or required app rewrites.

## Research and evaluator isolation

Load the plugin using the instructions in
[the plugin README](../README.md). Its researcher
takes only `gem`, `currentVersion`, `requestedVersion`, uses Opus 5.5 at low
effort, and has read-only research tools and a minimal prompt.

**Do not give a testing agent this repository checkout or evaluator findings.**
Use the answer-free package and filesystem namespace described in
[README.md](README.md). The runner cannot see this checkout, host HOME,
rubrics, evaluator tools or reports; it has no unsafe same-host fallback.

Filesystem isolation does not prevent Internet contamination. This project's
GitHub remote is public. A web-enabled worker could fetch the answer key.
Nothing in the runner makes public answers secret from WebSearch.
The filesystem boundary still prevents
direct local access; GitHub credentials are not forwarded.

## Scope and repetitions

Runtime checks require exactly 20 positive issues and verify both versions for
every row. This corpus covers SQLite, query construction, caches, streaming,
HTTP parsing/rendering/routing,
job serializers and text/time helpers. Some changes fix baseline bugs or change
integration behavior without requiring a repair; the rubric labels these cases.
It does not cover every Rails change, production performance, or Ruby upgrades.

Use the same frozen package for repeated runs and give every trial a fresh
session and output directory. Compare per-run recall, false claims and uncertainty
as well as their distribution; never merge repeated discoveries into extra issues.
No paid model trial or research accuracy result is claimed by the local checks.

The application also has four ordinary Minitest smoke-test sources and a small
set of contributor guides. They cover basic notebook behavior, not the grading
rubric. Runtime verification of the current frozen revision is pending. Run the
documented checks before conducting trials; file hashes establish identity, not
runtime correctness.
