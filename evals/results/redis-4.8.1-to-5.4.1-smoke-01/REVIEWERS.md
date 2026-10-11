# Independent benchmark reviews

These code and evidence reviews are separate from the single Redis worker's
research report and from its evaluator review in `REVIEW.md`.

| Reviewer | Follow-up result | Verification limits |
| --- | --- | --- |
| [Astra Max](https://ampcode.com/threads/T-01a1280b-0d78-702a-bf11-7c59ed27e0ec) | Confirmed the async retry fix on baseline and repaired target, and the unrepaired target failure. Checked eight offline handoff cases. Flagged the app README's inline wording, now corrected. | Did not rerun the entire corpus or inspect the recovered paid-trial artifacts. |
| [Opus 5.5](https://ampcode.com/threads/T-01a1280b-173b-7687-9c80-325ba0fad220) | Reproduced baseline successful async retry enqueueing and target RuntimeError. Confirmed Node lookup and plugin-origin matching. Found native-log loss on termination; the runner now mounts its fresh log directory persistently. | Did not rerun the full corpus or a model session. The native-log fix was verified by the implementing executor with an unpaid process-termination check. |
| [Grok 4.7](https://ampcode.com/threads/T-01a1280b-2057-75da-b98c-c6c0a29e4a9d) | Confirmed async, deadline, Node and origin corrections. Raised probe/caller attribution, warning scoring and provenance limitations. | Latest follow-up was source review, not a fresh corpus/model execution. |

## Adjudication

Caller metadata names an actual app caller, not a guarantee that the probe uses
that entire request path. The baseline documentation distinguishes boot failures,
HTTP observations and the retry job boundary. The retry probe now uses the actual
async queue adapter rather than deriving a scored difference from an unsupported
inline adapter. Deterministic serialization and repair tests use Rails' test queue.

Grouped archiving and distinct-publication warnings stay separate: the former
changes HAVING-aware update SQL in Arel, while the latter adds a deprecation in
Active Record without changing that publication SQL. New warnings count as
upgrade impacts, not necessarily current failures or required repairs. The tagged
sources and runtime observations establish these different results.

Matching a mutually substituted notification and main result does not authenticate
worker provenance. The runner's stated contract is exact content/request/worker
correlation, with the observed plugin origin, not substitution-resistant producer
authentication. Oracle independently checked the saved real trial and the narrow
origin correction. Synthetic malformed-event tests and the saved real trace pass
offline correlation; the original harness failure remains recorded.

The final app README correction changes documentation only. The final executor
reproduces the complete frozen corpus and repair suites at the resulting app pin.
Five-run model/prompt benchmarks and a positive-issue Redis holdout remain separate
work; no reviewer approval substitutes for those measurements.
