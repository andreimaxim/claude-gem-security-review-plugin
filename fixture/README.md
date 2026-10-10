# Margin Notes

A small Rails JSON notebook backed by SQLite. Notes have draft/published status,
an archive flag, and JSON metadata. Listings use Jbuilder; exports use inline jobs,
an in-process cache, and a Live/SSE endpoint.

Requires Ruby 3.4.7. Install the locked bundle, then prepare the local database:

```sh
mise trust mise.toml
mise install
mise exec -- bundle install
mise exec -- bin/rails db:prepare
mise exec -- bin/rails server
```

The application runs Rails 8.0.5 and retains its original Rails 7.0 framework
defaults. The installed Rails version and `load_defaults` are separate choices.
SQLite stores development data in `db/development.sqlite3`; no database daemon
or Redis service is needed. This is local development configuration, not a
production deployment setup.

The JSON API supports `GET /notes.json`, `POST /notes` with `note[title]`, and
`GET /notes/:id`. Creation redirects to the new note. `GET /health` returns the
application status, while `GET /stream` emits the current note count.

## Development on an orb

`.agents/setup` installs system libraries, SQLite, mise, Ruby and the locked
bundle, then prepares the database. It changes to the repository root before
trusting that root's `mise.toml`. It starts no services and runs no tests.

Use `amp orb service start margin-notes --command 'mise exec -- bin/rails server -b 0.0.0.0 -p 3000' --port 3000 --portal`
to expose a supervised development server. Local development configuration is
not suitable for a production deployment.

See [CLAUDE.md](CLAUDE.md) for application commands and [TESTING.md](TESTING.md)
for the small Minitest suite and its conventions.
