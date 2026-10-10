# Gem security review plugin: migration context

## Requested outcome

Move development of the current Claude Code gem-upgrade research plugin and its
evaluation work to `@andrei/claude-gem-security-review-plugin`. Build a very simple,
synthetic Ruby on Rails application with 100 distinct, real upgrade issues as a
baseline. The user authorized starting a thread in that project and committing
the work there.

The source is the local `fix-cves` checkout of `WEForum/fws-virtual-assistant` on
runner `citadel`, not the source repository's remote default branch. The plugin
and all evaluation work were uncommitted. The source thread is:
https://ampcode.com/threads/T-01a12456-35e9-71e8-9427-45308971e37e

This bundle contains the seven plugin source/configuration files and 15 reference
scripts/templates. It excludes generated Claude SDK types, the business
application, credentials, dependency directories, and historical session logs and
reports. Those historical artifacts remain intact in the source checkout. The
reference tooling depends on the old artifact layout; it is not a portable suite
yet, and its embedded report IDs, paths, sample counts and snapshot hashes must
not become the new benchmark's inputs by accident.

## Plugin behavior to preserve

The tool `mcp__gem-upgrade__research` accepts exactly three required strings:
`gem`, `currentVersion`, and `requestedVersion`. The main agent owns advisory
triage, target selection, application changes and eventual PR creation. This
worker researches the selected version change and application impact only.

The plugin currently registers Opus 5.5 at low effort. Model-comparison trials
used frozen plugin copies; the latest Sonnet/medium experiment did not change the
main plugin's default. Preserve the minimal researcher prompt and read-only tools.
No separate upgrade-research skill, app-location argument, resolver-preview
argument or production-write ability was added.

The launch returns an acknowledgement. A completion hook forwards the worker's
labelled text as a plugin-authored follow-up prompt. It distinguishes failures
and cancellations and does not forward unrelated agents. Claude Code 2.1.296 can
exit a one-shot headless session before that handoff finishes. Persistent
streaming-input sessions work; keep stdin open until the follow-up answer.
Native plugin eval captures worker reports but does not establish main-agent
continuation. Read the plugin README and its existing tests before changing this.

On the source host immediately before transfer, Claude Code 2.1.296 passed all
five plugin tests and strict plugin validation. Validation advised adding a
marketplace installation command once a marketplace exists. No marketplace was
created, and the plugin is loaded with `--plugin-dir`.

## Why a synthetic baseline is needed

The reference application currently pins Ruby 3.4.7 and Rails 8.0.5, retains
`load_defaults 7.0`, uses API controllers, Jbuilder, SSE, Redis object caching and
selective framework loading. It has relatively few direct gems. These traits,
not its domain-specific implementation, are useful starting points. It is not a
confirmed example of an unsupported Ruby runtime or 100 actual upgrade problems.

Earlier trials repeated ten Rails component requests ten times each. They were
100 research reports, not 100 distinct issues. The new requested baseline should
contain 100 independently identifiable, source-verified upgrade issues across
deliberately chosen version transitions and exercised application surfaces.
Do not pad the count with repeated trials, duplicate descriptions of one root
cause, hypothetical exposure, or 100 mandatory CVEs. Security advisories are one
kind of upgrade concern; compatibility, defaults, configuration, dependency and
runtime changes also matter. Nonissues/same-version controls should be additional
and explicitly labelled, not counted toward the 100 positive issues.

Keep the application small and bootable on its pinned baseline. Research exact
baseline and target versions before committing the issue catalogue. Every
expected finding needs a source-backed before/after distinction, an application
location that exposes it, and an appropriate executable check or an explicit
source-only verification limit. Keep evaluator answers out of the application
snapshot supplied to the research worker. Count and validate the catalogue
mechanically. If the 100-issue target cannot be met without fabrication or a much
larger application, surface the evidenced shortfall rather than silently padding.

## Lessons worth carrying over

- Compare exact source tags on both sides. A target changelog often lists fixes
  already backported to the baseline.
- Distinguish installing a new Rails version from opting into its versioned
  defaults. New defaults were repeatedly misreported as automatic changes.
- Distinguish installed, explicitly loaded and feature-used frameworks. Source
  search absence does not prove runtime non-loading or lack of external clients.
- Find real application surfaces: API-only applications can render Jbuilder,
  stream SSE and cache model objects. Generic change lists miss these impacts.
- Verify manifest blockers, Rails component coupling, actual attribute types,
  patch-level reversions and prerequisites of changes explicitly recommended.
- Freeze the grading rubric before running candidates. Earlier reviewers
  disagreed over materiality of conditional parser checks and optional RSpec
  upgrades; later adjudication changed scores substantially. Preserve initial
  findings and any documented adjudication rather than silently rewriting them.
- Blind review should hide model, effort and cost. Preserve exact quotes, source
  evidence, omissions and reviewer uncertainty. Controls and prior anchors are
  useful but do not certify accuracy; our 20 anchors were heavily imbalanced.
- Capture the resolved worker model and effort, raw reports, tool calls, timing,
  and usage. Native assistant messages repeat during streaming: deduplicate tool
  calls by tool-use ID, not message ID. Read the final usage record rather than
  summing repeated result events. Account list-price estimates are not invoices.
- Report execution failures separately from research quality. Preserve failed
  attempts and never rerun trials merely to recover output. Fewer tool calls and
  shorter reports do not establish better research.

The latest completed study contains 551 reports. Sonnet/high had 68/100 reports
without a material issue, versus 63/100 for medium; medium took a median 22.3
worker seconds versus 72.4 and cost an estimated $12.05 versus $30.71 per batch.
This narrow study does not select a universal best model. Fable and Haiku/xhigh
were dropped from the experiments at the user's request. Do not launch another
large paid model matrix just because the old runner scripts are present.

The existing HTML builder/template illustrate cost, time, reviewed outcomes and
within-case verdict variation, with individual report drill-down and offline
exports. Port only the useful pieces; do not imply the historical scores were
measured on the new synthetic application.
