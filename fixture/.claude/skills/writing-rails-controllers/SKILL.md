---
name: writing-rails-controllers
description: Guides changing Rails controllers and the request tests that prove their behavior. Use for routes, controller actions, parameters, responses, and tests under app/controllers or test/controllers.
---

# Writing Rails controllers

Treat controller implementation and its request tests as one change. Read the
[controller guide](../../../docs/guides/controllers.md) and
[testing guide](../../../TESTING.md). Consult the
[fixture guide](../../../docs/guides/fixtures.md) when selecting test data.

Trace the existing route through selection and rendering. Keep HTTP decisions
at the controller boundary and note behavior behind public model APIs. Exercise
the real request stack with `ActionDispatch::IntegrationTest`; assert response
values and persisted results rather than calls between application objects.

From the application root, use `mise exec -- bin/rails test
test/controllers/notes_controller_test.rb` for focused feedback and
`mise exec -- bin/rails test` for the suite.
