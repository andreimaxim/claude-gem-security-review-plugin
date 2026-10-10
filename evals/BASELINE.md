# Rails upgrade baseline

[Margin Notes](https://github.com/andreimaxim/margin-notes) is a small PostgreSQL
notebook application with a JSON API, Jbuilder views, export jobs, Redis caching,
live note counts and compose form fragments. Its baseline has four Minitest smoke
tests and contributor guides. `fixture_source.json` pins its revision and tree.

## Locked versions

| Surface | Baseline | Target |
| --- | --- | --- |
| Ruby | 3.2.9 | 3.2.9 |
| Rails | 7.0.8.7 | 8.1.4 |
| Framework defaults | 7.0 | 7.0 |
| pg | 1.5.9 | 1.5.9 |
| redis | 4.8.1 | 4.8.1 |
| Puma | 5.6.9 | 6.6.1 |
| Jbuilder | 2.13.0 | 2.13.0 |
| Minitest | 5.25.5 | 5.25.5 |

Ruby 3.2.9 meets both Rails versions' requirements. Keeping the runtime and
database drivers fixed makes this a framework upgrade, not a Ruby upgrade.
BigDecimal 3.1.8 and concurrent-ruby 1.3.4 are held constant. Minitest 5 retains
Rails 7 compatibility. Baseline and target lockfiles freeze the complete stacks;
Rails-required transitive changes remain part of the comparison. Puma must
upgrade because Puma 5 rejects the Rack 3 stack selected by Rails 8.

The checked application uses PostgreSQL 15.19 and Redis 7.0.15 in the Orb.
The system packages install the distribution's server versions, not a frozen
production image. Server-version changes require rerunning the runtime check.
The app uses inline Active Job execution; Redis backs its cache, not a job queue.
Its development signing key and permissive hosts are not production settings.

## Reproduced impacts

The corpus contains **31 distinct upgrade impacts and nine unchanged controls**.
Six prerequisite failures are reproduced separately: Puma/Rack compatibility,
keyword enum declarations, positional serialization coders, `partial_writes`,
untyped virtual enums and aliases targeting ordinary methods. After repairing
those prerequisites, 25 further observations cover queries, rendering, routing,
Redis keys, job serialization/retries and application helper APIs.

Some observations are upstream bug fixes or changed integration behavior, not
new exceptions or required app repairs. Controls and repeated trials do not add
positive issues. `answer_key.rb` records each app surface, before/after result,
tagged source and prerequisite repair. `sources.json` hashes the exact Rails and
Puma evidence. File hashes and anchor checks establish identity; runtime checks
and semantic review establish the behavior.

`check.rb` reproduces all observations, then applies the reference repair and
regression-test patches. The repaired app passes **33 tests, 85 assertions** at
seeds 12345 and 67890. The reference tests assert public request, model, job and
workflow behavior, including asymmetric controls for bulk updates and cache
expiry. These evaluator-only tests are not in the worker's baseline checkout.
The probes also record low-level integration differences such as SSE write
boundaries; the regression suite checks the resulting event bytes instead of
requiring a particular write count.

## Scope

This is a synthetic application, not a production workload or a comprehensive
Rails migration inventory. Defaults remain 7.0. The benchmark does not measure
Ruby upgrades, newer-default adoption, deployment behavior or production
performance. Runtime verification does not measure research accuracy: paid
Claude research trials have not been run.

See [the evaluator workflow](README.md) for setup, patches and frozen requests.
