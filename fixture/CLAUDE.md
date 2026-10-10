# Margin Notes

A small Rails JSON application for storing notes and exporting them. It uses
SQLite, Jbuilder, in-process caching, inline jobs, and a streaming endpoint.

## Project references

- Read [TESTING.md](TESTING.md) for shared test conventions.
- Read [docs/guides/controllers.md](docs/guides/controllers.md),
  [docs/guides/models.md](docs/guides/models.md), and
  [docs/guides/views.md](docs/guides/views.md) for the layer you are changing.
- Read [docs/guides/fixtures.md](docs/guides/fixtures.md) when changing test data.
- Find similar code in this application before introducing a new pattern.

## Development commands

Run these from the application root. Ruby is pinned in `mise.toml`.

```sh
mise trust mise.toml
mise install
mise exec -- bundle install
mise exec -- bin/rails db:prepare
mise exec -- bin/rails server
mise exec -- bin/rails console
mise exec -- bin/rails dbconsole
mise exec -- bin/rails routes
mise exec -- bin/rails test
mise exec -- bin/rails test test/controllers/notes_controller_test.rb
mise exec -- bin/rails test test/models/note_test.rb
```

- SQLite needs no database daemon. The development file is `db/development.sqlite3`.
- Request and SQL logs go to stderr, including when running tests.
- This app deliberately retains `config.load_defaults 7.0`; changing the installed
  Rails version is not the same operation as changing framework defaults.
- Keep local development signing settings out of any production deployment.

## Task-specific guidance

Load the applicable repository skills when changing these layers:

- `writing-rails-controllers` for controllers and request tests.
- `writing-rails-models` for model behavior and model tests.
- `writing-rails-views` for Jbuilder representations and their request tests.

Load more than one when a change crosses layers.
