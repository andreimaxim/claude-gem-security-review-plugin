# Testing

Tests live in `test/` and use Minitest with Rails' built-in support. Files end in
`_test.rb` and mirror the application layer. This is a small smoke suite, not
comprehensive coverage of every export, cache, job, and streaming path. There is
no coverage threshold or coverage instrumentation.

## Commands

From the application root:

```sh
mise exec -- bin/rails test
mise exec -- bin/rails test test/controllers/notes_controller_test.rb
mise exec -- bin/rails test test/models/note_test.rb
mise exec -- bin/rails test --seed 12345
```

Use the seed printed by Minitest to reproduce ordering failures with the same
selection of tests. The suite is serial; there is no parallel-worker setup.

## Test harness

Require `test_helper`, inherit the Rails test class for the layer, and use
`test "…" do` blocks. Controller tests use `ActionDispatch::IntegrationTest`;
model tests use `ActiveSupport::TestCase`. There is no RSpec, spec-style harness,
mocking library, external service credential, or production data dependency.

`test_helper` selects the application's `db/test.sqlite3`, ignoring an inherited
`NOTEBOOK_DB`. This file is disposable: test preparation and fixtures can replace
its contents. Do not put development data there. For pending migrations, use
`RAILS_ENV=test mise exec -- bin/rails db:prepare` with `NOTEBOOK_DB` unset.

Fixtures load for every test, and transactional tests roll back record changes.
Keep scenario-specific changes inside the test rather than depending on another
test's state. Tests here do not change the process-wide cache or configuration.

## Exercise public behavior

Treat tests as executable specifications. Use real application collaborators
and the fixture-backed database, then assert what a caller can observe: an HTTP
response, return value, or persisted state. Do not test private methods or pin
calls between controller and model objects. A behavior-preserving refactor should
not require rewriting the tests.

Names state facts about the application, such as "new notes appear in the list"
or "note metadata survives a reload", rather than naming assertions or method
calls. Keep only setup used by every test in a shared `setup` block.

Blank lines separate arrange, act, and assert. Parse response JSON next to the
request, then keep meaningful assertions visible in the test body. Use
`assert_response` for HTTP status and `assert_difference` for record creation.
Assert values, not merely successful status or the presence of JSON keys.

For complete record collections, assert count separately from identities. When
order is contractual, assert identifiers by position without sorting the result
or using `find` to hide an ordering error. For filters, arrange an included and
an otherwise eligible excluded record. Do not derive an expected value by calling
the implementation being tested.

Read the [fixture guide](docs/guides/fixtures.md) when selecting or changing the
shared dataset. Layer-specific examples live in the
[controller](docs/guides/controllers.md), [model](docs/guides/models.md), and
[view](docs/guides/views.md) guides.
