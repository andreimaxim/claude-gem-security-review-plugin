# Fixtures

The shared notes form a small, coherent notebook rather than one record for
every assertion. They are all synthetic and contain no imported user data.

| Fixture | Meaning |
| --- | --- |
| `morning_notes` | An unarchived draft with a reminder in its metadata |
| `reading_list` | An unarchived published reading note |
| `old_ideas` | An archived draft retained in the notebook |

The explicit ids establish a stable list order. These records have no foreign-key
relationships. Fixed timestamps keep examples reproducible.

Reuse a record when its role fits the scenario, not just because it is convenient.
Keep a one-test variation visible in that test. A recurring notebook state can
belong in shared fixtures, but repeated setup is not automatically a reason to
change global defaults. Do not change the archived note into a published record
merely to satisfy an unrelated example.

The export-filter test narrows candidates to the draft and archived note and
asserts that only the unarchived one remains. The metadata test changes one
record, reloads it, and checks the exact persisted hash. Database fixtures and
transactional tests reset these variations between tests.

See Rails' [fixture guide](https://guides.rubyonrails.org/testing.html#fixtures)
for YAML syntax and label-based lookup.
