# Redis upgrade smoke review

Verdict: **insufficient research**. The low-risk conclusion agrees with the observed app checks, but exact target-source verification and caller coverage are incomplete. No required Redis-only app repair was reproduced.

Model: Opus 5.5 / low. Worker: 28.382s. Recorded session cost: $0.21187. Report: 415 words; 10037 worker tokens (different quantities).

## F1 — material_omission (material)

> the only place the app touches Redis is the Rails cache store setting

The report correctly finds no direct Redis client use, but does not trace the actual Rails.cache callers. Exports read/write snapshots and delete matching keys; cache-status reads around a write in another thread. Grepping for redis alone misses these workflows. Baseline and target runtime checks independently exercised them and found no Redis-only difference.

- https://github.com/andreimaxim/margin-notes/blob/182ac788d97c26675dba5f8bd2b1b9dabb651baa/app/controllers/exports_controller.rb
- https://github.com/andreimaxim/margin-notes/blob/182ac788d97c26675dba5f8bd2b1b9dabb651baa/app/controllers/notes_controller.rb
- https://github.com/andreimaxim/margin-notes/blob/182ac788d97c26675dba5f8bd2b1b9dabb651baa/app/services/notebook_workflows.rb
- https://github.com/rails/rails/blob/v7.0.8.7/activesupport/lib/active_support/cache/redis_cache_store.rb

## F2 — material_omission (material)

> What changes in redis 5.x (summary from memory, not checked against the redis-rb changelog)

The uncertainty is honestly labelled, not a false claim. However, this source-backed upgrade task needs exact target evidence. The worker used one web search, no web fetch, and no exact Redis source read. Its sources are mirrors and bot PRs; one citation contains an unresolved template token. The evaluator verified the gemspec's Ruby >= 2.6.0 and redis-client >= 0.22.0 requirements separately.

- https://github.com/redis/redis-rb/blob/v5.4.1/redis.gemspec
- https://github.com/redis/redis-rb/blob/v5.4.1/lib/redis.rb

## F3 — minor_inaccuracy (minor)

> Removed in 5: `Redis.current`, the old `driver: :hiredis` option (replaced by the separate `hiredis-client` gem)

Redis.current is removed, but the target still documents a driver option supporting :ruby and :hiredis. Changing the hiredis implementation/package is not the same as removing that option. This app selects neither hiredis nor Redis.current, so the imprecision does not prescribe an app repair.

- https://github.com/redis/redis-rb/blob/v5.4.1/lib/redis.rb
- https://github.com/redis/redis-rb/blob/v4.8.1/lib/redis.rb

## Execution and provenance

Original harness execution_failure preserved. Worker completed and main delivered the exact payload; corrected matcher confirms content correlation offline. No clean shutdown rerun was performed.

The preflight Node path failure used no model. The single paid trial completed research in 28.382 seconds; its runner was stopped after remaining idle because of the wrong origin predicate. Native main/subagent JSONL files were recovered from the live worker HOME through its Linux /proc filesystem view before stopping it; they were not exported by normal SDK shutdown. The retained traces are not a complete on-wire API-request dump. No report text was altered.

## Limits

- One smoke trial, not a five-run benchmark group; no variation or accuracy percentage.
- No frozen Redis positive-issue rubric; current app uses Rails.cache rather than distinct Redis command migrations.
- Passing smoke tests do not establish production safety, performance, failover or every cache operation.
- The trial pins app 182ac78; current corpus uses 5a17e59 after independently reviewed queue corrections. Original manifest and freeze remain unchanged.
