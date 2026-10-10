# JSON views

Apply [TESTING.md](../../TESTING.md) and the
[controller guide](controllers.md) when changing responses.

`app/views/notes/index.json.jbuilder` owns the list envelope and each note's
`id`, `caption`, and `metadata` fields. It calls the model's public attribute
interfaces. Keep query selection in the controller/model rather than adding it
to the template. The app currently has one Jbuilder template and no shared
partials; do not assume a partial or fragment-cache convention exists.

Prove JSON through a request test, not by mocking Jbuilder calls. The note-list
test checks ordered identifiers and a caption value. Creation follows the
redirect to the inline detail response, including explicit `null` metadata.
Changing a model reader can affect either representation, so inspect both.

See [Jbuilder's documentation](https://github.com/rails/jbuilder#readme) for
template syntax and the Rails
[rendering guide](https://guides.rubyonrails.org/layouts_and_rendering.html) for
response behavior.
