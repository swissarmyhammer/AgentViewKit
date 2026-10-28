---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m61qk8smgbkvmq4efte7n47n
  text: |-
    ### review — findings
    - evidence: review sha a6117c6..0b9889f — counts findings 2, confirmed 2, refuted 0; plus 1 finding raised by the caller and judged by the reviewer (in-flight reload result after a session swap). Sources/AgentViewKit/Status/SessionStreamBanner.swift:126, :129, :139. Work items 2 and 3 checked: the hosted test is missedUpdatesThatComeBackAfterAClearShowTheMissedUpdatesBanner; `swift test` per the implementer's worktree run (285 + 1901 + 37 passed, 0 failures, 7 intentional known issues, 1 environment-gated demo-project skip). Work item 1 left open: the in-flight swap breaks "make that state follow the model".
    - next: implement the 3 findings, re-run /review ^xwj53qw.
  timestamp: 2026-10-28T17:05:49.364184+00:00
- actor: claude-code
  id: 01m621gr3px5aahk580hr9vz9p
  text: |-
    ### review — clean
    - evidence: review sha 2b978da..2e68708 — 0 findings (0 confirmed, 1 refuted, 7 attempted, 0 failed); 2 files. Prior findings verified against 2e68708: `ReloadScope.contains(_:)` reads `session` and `missesUpdates`; `@State reload: Reload?` carries its scope, `reloadPhase` derives from `reload.scope.contains(session)`, `record(_:in:of:)` drops a late outcome whose scope no longer matches; hosted test `aLateReloadFailureOfTheSessionBeforeASwapLeavesTheNextSessionAlone` covers the swap. Tests per implementer: 285 + 1902 + 37 passed, 1 demo-project skip.
    - next: none; moved to done.
  timestamp: 2026-10-28T19:59:12.502432+00:00
position_column: done
position_ordinal: fffff780
title: 'SessionStreamBanner: don''t show a stale reload failure after missed updates clear elsewhere and come back'
---
From the wt/banner work (reload-failed phase). The banner keeps a private reload state: idle, reloading or failed. If `hasMissedUpdates` is cleared somewhere other than this banner and later comes back, the old `failed` state is still there, and the banner shows an old failure. KVK's board banner has the same behaviour, so fix both in the same way. Ask the KVK session to do theirs.

## Work
- [x] Reset the reload state whenever missed updates clear, from any source, and make that state follow the model.
- [x] A hosted test: fail a reload, clear the missed updates through the model, raise them again, and expect the plain missed-updates message.
- [x] `swift test` is green.

Order: after the wt/banner merge.

## Review Findings (2026-10-28 12:04)

> Scope: `review sha a6117c6..0b9889f` — reviewed the diffs only — lines this change added or modified. 2 file(s) reviewed, 0 not reviewed.

- [x] `Sources/AgentViewKit/Status/SessionStreamBanner.swift:126` `code-hygiene/dead-code-swift` — var.instance `session` is assignOnlyProperty.
- [x] `Sources/AgentViewKit/Status/SessionStreamBanner.swift:129` `code-hygiene/dead-code-swift` — var.instance `missesUpdates` is assignOnlyProperty.
- [x] `Sources/AgentViewKit/Status/SessionStreamBanner.swift:139` `review/caller-raised-edge` — A swap to another session model while the old session's reload still runs lets the late result land in the new session's state: `.onChange(of: reloadScope)` resets `reloadPhase` to `.idle`, but `Self.resume` still writes `.failed(errorDescription:)` or `.idle` through the captured `$reloadPhase` binding, which belongs to the view and not to the session the reload was started for, so the new session shows a reload failure that is not its own (and its Reload button is enabled while the old resume runs). This breaks the documented "forgets the failed reload ... when it gets another session model" and the Work item "make that state follow the model". Tie the outcome to the scope it started in (for example, record the `ReloadScope` with the phase and drop a result whose scope no longer matches), and add a hosted test that holds the first session's resume answer, swaps the banner to a second session with missed updates, releases a failure, and expects the plain missed-updates message.