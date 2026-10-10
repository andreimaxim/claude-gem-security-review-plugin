---
name: writing-rails-views
description: Guides changing Jbuilder JSON representations and their request tests. Use for templates under app/views and tests of rendered JSON under test/controllers.
---

# Writing Rails views

Treat the representation and its request tests as one change. Read the
[view guide](../../../docs/guides/views.md),
[controller guide](../../../docs/guides/controllers.md), and
[testing guide](../../../TESTING.md).

Trace which records the controller selects and which model readers the template
uses. Keep selection outside the view and prove meaningful JSON values through
the request boundary, not Jbuilder method calls.

From the application root, use `mise exec -- bin/rails test
test/controllers/notes_controller_test.rb` for focused feedback and
`mise exec -- bin/rails test` for the suite.
