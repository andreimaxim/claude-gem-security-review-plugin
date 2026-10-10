# Controllers

Apply the shared conventions in [TESTING.md](../../TESTING.md).

## Request boundary

`NotesController` uses `ActionController::API`, with explicit rendering modules
for Jbuilder. The note resource has `index`, `show`, and `create` routes. Older
export and diagnostic actions live in the same controller; follow their existing
callers rather than assuming all actions are a uniform REST interface.

Keep parameter handling and responses in controllers, and note queries behind
public model APIs. `create` permits the title and redirects to the persisted
note. `index` selects notes ordered by id and renders a Jbuilder representation.
`show` currently renders a small inline JSON response. These are different
contracts; do not replace one with another as incidental cleanup.

## Request tests

Tests under `test/controllers/` exercise the real routes, controller, models,
database, and rendered view together. Assert status, meaningful response values,
and persisted changes rather than expecting a particular model method call.

For example, after posting a new note, follow the redirect and inspect the note's
caption and metadata. This proves more than checking a redirect alone. For the
list, assert the count and each note's id by position; the controller orders by id.

Use square brackets for response-hash values. Use `fetch` only when a missing key
must differ from a key whose value is JSON `null`, as with a new note's metadata.

The route and response conventions are documented in the Rails
[routing](https://guides.rubyonrails.org/routing.html) and
[API controller](https://guides.rubyonrails.org/api_app.html) guides. Check the
bundled Action Pack implementation when exact version behavior matters.
