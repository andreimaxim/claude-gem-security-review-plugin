# Gem upgrade research

A Claude Code mod that gives the main agent one tool for researching a Ruby gem
version change. It does not select CVE fixes, update dependencies, or open pull
requests.

## Try it

Requires Claude Code with mods support. Tested with version 2.1.296.
From the application you want to inspect, load this plugin by its absolute path:

```sh
claude --plugin-dir /path/to/claude-gem-security-review-plugin
```

Ask Claude to research a specific upgrade, for example:

> Research upgrading faraday from 2.14.2 to 2.14.4 and explain the application impact.

The tool `mcp__gem-upgrade__research` takes three required strings:

```json
{"gem": "faraday", "currentVersion": "2.14.2", "requestedVersion": "2.14.4"}
```

It starts a researcher in the current application's directory, using Opus 5.5
with low reasoning effort. The researcher can read files and search the web, but has
no shell, editing, or delegation tools. Its prompt is in `prompts/research.md`.

## Report delivery

The tool returns a launch acknowledgement. When the researcher finishes, the mod
submits its labelled report as a plugin-authored follow-up message. This wakes the
main agent so it can continue without another user prompt. Research failures are
labelled as failures; cancelled runs do not wake the main agent.

This is asynchronous because a mod-created subagent runs in the background and a
hook cannot wait on its own promise for more than ten seconds. Claude Code 2.1.296
does not wake the main agent for these workers' native completion notifications,
so the mod forwards their completion events explicitly. It does not add polling
or a second agent process.

For unattended use, keep a streaming-input session open until the main agent
answers the report. Pass `--input-format stream-json`, `--output-format stream-json`,
and `--verbose`, and close stdin only after the follow-up result. Interactive sessions
already stay open. One-shot `claude -p` and `claude plugin eval` can exit before
the completion hook queues its message in 2.1.296; output streaming alone does not
prevent that shutdown race.

The output can contain an initial `result` with a waiting message and a later
`result` with the main agent's answer. The raw worker report is also in the completed
`task_notification` event's `summary`. Add `--forward-subagent-text` to retain worker
text and thinking alongside tool calls for evaluation. Native plugin eval can
capture worker reports, but is not a reliable check of main-agent continuation.

The Agent SDK can load the mod with its `plugins` option. Give the main agent a
fixed dispatcher `systemPrompt`; the researcher uses its own whole prompt from
`prompts/research.md`, not that main-agent prompt. The evaluator's SDK driver
keeps streaming input open and checks the exact worker-ID-labelled report
returned by the main session. See [the evaluator workflow](evals/README.md).

## Local checks

```sh
claude plugin test /path/to/claude-gem-security-review-plugin
claude plugin validate /path/to/claude-gem-security-review-plugin --strict
```

These checks cover input and launch failures, report forwarding, and cancellation,
not research accuracy. Evaluate research with real sessions and inspect their
source-linked reports and traces.

## Evaluations

[evals/README.md](evals/README.md) describes the Ruby evaluation workflow and
[evals/BASELINE.md](evals/BASELINE.md) defines its Rails upgrade baseline.
The application is [margin-notes](https://github.com/andreimaxim/margin-notes).
Evaluation commands use the existing application
directory in the Orb and require the pinned revision in `evals/fixture_source.json`.
Do not expose `evals/` to the research worker.
