# Prompt-development protocol

## What the benchmark measures

The agent researches a particular gem upgrade in a real application. It does not
apply a repair. The evaluator separately reproduces actual behavior and keeps the
answer key, repair patches and Minitest regression tests outside the worker.
Those runtime checks establish ground truth; independent report review measures
the researcher's ability to explain it accurately.

## Baseline and iterations

Start with the minimal system prompt in `prompts/research.md` and the fixed
version-specific request in `run.rb`. Hold the request, app revision, versions,
model and effort fixed while changing the system prompt. When investigating tool
access, keep the prompt fixed and change tools separately. Retain an unchanged
baseline run group alongside each candidate group.

Choose repetition counts and a usage budget before launching paid trials. Every
trial starts fresh, sees no previous reports or grader feedback, and records its
prompt/tool hashes, app pin, rubric version, raw trace and resolved model/effort.
Store each variant in a reviewed commit with its own freeze and keep its results
with that manifest. Do not alter the rubric, request or app to improve a score.

Grade without exposing candidate identity to the reviewer. Record positive
recall, unsupported claims, uncertainty, execution failures, latency and cost
separately. Compare per-run results and their variation, not the union of facts
found across repeated runs. A longer report or higher recall with more invented
claims is not automatically an improvement.

Use repeated failure patterns to propose generic changes: distinguishing changed
defaults from retained configuration, tracing actual callers, or checking exact
version sources. Do not paste issue IDs, app-specific fixes or expected answers
into the system prompt. Record the hypothesis before running its candidate.

## Independent holdouts

Rails is the development set. Its framework-component requests overlap the same
answer key, and Puma is already a Rails prerequisite issue. Neither is an
independent holdout. A same-version request is a false-positive control, not an
upgrade benchmark.

Redis 4.8.1 → 5.4.1 is a source-supported candidate for the first holdout. Keep
Rails and the server fixed and exercise app-owned Redis calls rather than
Rails.cache. The tagged sources identify distinct candidates: set-operation
Boolean/count changes, use of the original connection inside transaction blocks,
and positional blocking-list timeout arguments. These are selection hypotheses,
not accepted rubric rows: the app must use the APIs, and both versions must be
run before freezing expected results and repairs.
The starting references are the tagged [set commands](https://github.com/redis/redis-rb/blob/v5.4.1/lib/redis/commands/sets.rb),
[transaction commands](https://github.com/redis/redis-rb/blob/v5.4.1/lib/redis/commands/transactions.rb)
and [blocking-list signatures](https://github.com/redis/redis-rb/blob/v5.4.1/lib/redis/commands/lists.rb),
compared with the same files at v4.8.1.

Build each accepted holdout with exact lockfiles, natural app workflows, unchanged
controls, source evidence and evaluator-only regression/repair patches. Use a
separate app revision if those workflows need new features; do not silently
change the Rails development fixture. Select and freeze holdouts before tuning,
then evaluate the chosen candidate against them without further optimization.
Once holdout results influence a prompt change, that set is development data;
reserve another gem/application case for the next generalization check.

The Rails runtime corpus is reproduced. The Redis holdout and paid research
scores are not implemented or measured yet. Astra, Opus and Grok reviews of the
code/evidence assess benchmark validity; they are not substitutes for model trials.
