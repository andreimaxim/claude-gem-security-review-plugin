---
name: writing-rails-models
description: Guides changing Rails models and tests of their public behavior. Use for Active Record queries, attributes, serialization, and tests under app/models or test/models.
---

# Writing Rails models

Treat model behavior and its tests as one change. Read the
[model guide](../../../docs/guides/models.md) and
[testing guide](../../../TESTING.md). Consult the
[fixture guide](../../../docs/guides/fixtures.md) when selecting test data.

Trace public callers before changing a query or attribute interface. Keep note
selection and persistence behavior on `Note`; test the resulting records and
values rather than declarations or internal collaborators.

From the application root, use `mise exec -- bin/rails test
test/models/note_test.rb` for focused feedback and
`mise exec -- bin/rails test` for the suite. No mutation-testing tool is configured.
