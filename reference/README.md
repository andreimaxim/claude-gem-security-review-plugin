# Historical migration evidence

`migration.tar.gz` is the original 43,614-byte transfer from the uncommitted local
`fix-cves` checkout of WEForum/fws-virtual-assistant on runner citadel. It is not a
snapshot of either repository's remote main. Its SHA-256 is:

```
62b2dede9f79da60d68e9af47bf37c2cf791e8848c09b78b6167eb2f5e4b545e
```

The seven installed plugin files match its internal `SHA256SUMS` byte for byte.
The archive includes 15 legacy scripts/templates and MIGRATION.md. Legacy Python
scripts remain archival reference only; the new portable evaluator is Ruby.
Historical business source, sessions, reports, dependencies and credentials were
not transferred and remain in the source checkout. Do not run a large paid model
matrix just because the old scripts are archived here.

To verify the internal manifest, extract the archive into a temporary directory
and run `sha256sum -c SHA256SUMS` there. All 23 entries were checked on migration.
The root MIGRATION.md is preserved as historical context; the root README records
the later clarification that this fixture must start on Rails 8 with 7.0 defaults.

## Application guidance adaptation

The standalone app's guidance uses a limited, rewritten subset of `CLAUDE.md`,
`TESTING.md`, controller/model/view/fixture guides and three `writing-rails-*`
skills from the authorized fws-events checkout at source revision
`a072033ab300019062a3bfb6db910b0516733a89`. Relevant documentation history was
inspected as well, including the fixture-policy development described in
[its source thread](https://ampcode.com/threads/T-01a10c53-5a7b-712d-97a5-5f39eed98a11).

Only generic conventions demonstrated by this notebook are retained: real-stack
Minitest requests, public model behavior, explicit collection assertions, and
synthetic fixture selection. Business data, proprietary implementations,
authentication, external integrations, telemetry, query budgets and mutation
tooling were not copied. Examples, commands and dataset names are notebook-specific.
Source business documents are not stored in the application package or this repo.

## Standalone app history

`margin-notes.bundle` preserves the five local application commits, including the
generated Rails 7.0.8.7 starting point, features, Minitest sources and guidance,
Rails 8.0.5 upgrade retaining 7.0 defaults, and orb setup last. It contains only
the new synthetic application repository, not the evaluator or source business
application. This is a staged history constructed during migration, not evidence
of earlier development dates. No timestamps were backdated.

The mirrored final revision and testing limit are recorded in
`eval/fixture_source.json`. The app commits are local until an authorized push.
The bundle allows recovering that exact history even if this orb is lost.
