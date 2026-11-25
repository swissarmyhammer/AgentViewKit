---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m89h9ac2sq4bamqhxz0484zq
  text: |-
    Implementation landed.
    - New modifier TopBarPartContextMenu (Sources/AgentViewKit/Thread/TopBarPartContextMenu.swift): a content shape of the floating glass shape (EditorSurface.shape, large radius) plus .hostPathContextMenu(path). topBarParts in AgentThreadView.swift attaches it to ThreadHeaderSlot and to the banners Group (thus to each banner).
    - ThreadStatusHeader is not changed. A try to make it use the new modifier failed: the unit test ThreadStatusHeaderTests.theInsetOfTheLineInItsGlassHasTheHitShapeOfTheGlass reads the body type and needs the content shape before floatingGlass(). I reverted that change.
    - Docs updated: topBarParts, the stored headerContextMenuPath, the init parameter docs in AgentThreadView.swift and DefaultThreadComposer.swift, ThreadHeaderSlot and .threadHeader(_:) in ThreadHeader.swift.
    - Hosted tests added in ThreadHeaderContextMenuHostedTests: host header text, empty part of the host header, notice banner, nil path on the host header, nil path on the banner. mountThread got a `header: AnyView?` parameter (sets \.threadHeader).
    - RED was not seen in a run: the user allowed one hosted run only, so before the fix I only built the test target (build clean). The one hosted run after the fix: 10/10 pass.
  timestamp: 2026-11-25T14:20:50.946629+00:00
- actor: claude-code
  id: 01m89h9cykqmm32zxsgc3kwqrm
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/Thread/TopBarPartContextMenu.swift (new), Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKit/Thread/ThreadHeader.swift, Sources/AgentViewKit/Input/DefaultThreadComposer.swift, IntegrationTests/Tests/IntegrationTests/Thread/ThreadHeaderContextMenuHostedTests.swift. `swift test`: 1742 + 59 tests pass, 0 warnings. `swift test --package-path IntegrationTests --filter ThreadHeaderContextMenuHostedTests`: 10 tests pass (one run).
    - next: /review
  timestamp: 2026-11-25T14:20:53.587854+00:00
- actor: claude-code
  id: 01m89hf7hcb8t1sbezkkh6tnfp
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` (commit b629bc5f): 5 findings (5 confirmed, 3 refuted). All `reuse/reuse` in IntegrationTests/Tests/IntegrationTests/Thread/ThreadHeaderContextMenuHostedTests.swift:205, :215, :221, :239, :247.
    - next: /implement — share one helper for the repeated mount, menu, trailing point and no-path checks in ThreadHeaderContextMenuHostedTests.swift; then /review again.
  timestamp: 2026-11-25T14:24:04.652616+00:00
- actor: claude-code
  id: 01m89hqx4fkzzry4npxxmtd90h
  text: |-
    Review findings fixed (5 of 5). ThreadHeaderContextMenuHostedTests.swift now has shared helpers, and each of the 10 tests calls them:
    - `ClickSpot` (`.identifier(_)`, `.trailingEdge(ofFrame:)`). The trailing point arithmetic is in one place, `contextMenu(at:in:)`.
    - `withContextMenu(at:of:path:header:log:_:)` mounts the thread, reads the menu at the spot, and gives it to a closure while the window is open. The run test performs the item in the closure, so the order of steps did not change.
    - `expectMenuOfHostPath(at:of:header:)` and `expectNoContextMenu(at:of:header:)` hold the menu check and the no-path check. They pass `sourceLocation` to `#expect`.
    - `noticeBannerIdentifier(of:)` gives the banner identifier of the first notice.
    - `mountThread` keeps its signature, because AnswerTextContextMenuPointerHostedTests and AnswerCodeBlockItemMenuPointerHostedTests call it.
    Note: I ran the root `swift test` twice by mistake. The first run kept only the tail of the log. The code did not change between the two runs.
  timestamp: 2026-11-25T14:28:48.911675+00:00
- actor: claude-code
  id: 01m89hqz9rtk69z8se82s3znd5
  text: |-
    ### implement — changed
    - evidence: 1 file — IntegrationTests/Tests/IntegrationTests/Thread/ThreadHeaderContextMenuHostedTests.swift. `swift test`: 1742 + 59 tests pass, 0 code warnings. `swift test --package-path IntegrationTests --filter ThreadHeaderContextMenuHostedTests`: 10 tests pass (one run). `swift format lint`: clean. The 5 findings are checked.
    - next: /review
  timestamp: 2026-11-25T14:28:51.128697+00:00
position_column: doing
position_ordinal: '80'
title: The host header and each top-bar banner show the header context menu
---
Testudo request (TestudoApp card ^jgtq55d). The UI test testShareSessionShowsTheShareHeaderAndStopSharingRemovesIt fails. In a shared session, a right-click on the share notice ("Shared · …", the host header of `.threadHeader`) opens no context menu, so Stop Sharing is not reachable there. Only the status line (`ThreadStatusHeader`) has the menu of `headerContextMenuPath`. D108: each action is a command, and the menu is the same at each point of the bar.

## What
- `Sources/AgentViewKit/Thread/AgentThreadView.swift`: in `topBarParts`, attach `.hostPathContextMenu(headerContextMenuPath)` to `ThreadHeaderSlot` and to each banner of `banners` (AgentConnectionBanner, SessionNoticeBanner, UnconfirmedSessionBanner, WaitingDescendantBanner, SessionStreamBanner). Give each part a content shape of its full bar, so that a right-click on the inset or on empty space of the part opens the menu and does not go through to the list.
- A control of a banner or of the host header (a button) keeps its own action. A right-click on a part shows the same menu as a right-click on the status line.
- With no `headerContextMenuPath`, no part has a context menu (as now).
- Update the doc comments of `topBarParts`, `ThreadHeaderSlot`, `.threadHeader(_:)` in `Sources/AgentViewKit/Thread/ThreadHeader.swift` and the init parameter `headerContextMenuPath`.

## Acceptance Criteria
- [x] A right-click on the host header text shows the menu of `headerContextMenuPath`, with the same items and groups as the status line.
- [x] A right-click on a session notice banner shows the same menu.
- [x] With a nil path, the header and the banners show no context menu.
- [x] All unit tests and the hosted suite pass.

## Tests
- [x] Hosted test first, in `IntegrationTests/Tests/IntegrationTests/Thread/ThreadHeaderContextMenuHostedTests.swift`: a thread with `.threadHeader { Text("Shared · Ann") }` and a host path; a right-click on the header text shows the host menu items. It fails before the fix.
- [x] Hosted test: a session with a notice (SessionNoticeBanner); a right-click on the banner shows the host menu items.
- [x] Hosted test: with a nil path, a right-click on the header shows no host item.
- [x] Behavior tests only (no source-scan tests). Bound each wait on a certain event; no sleep, poll or retry.
- [x] `swift test` passes; the hosted suite in `IntegrationTests` passes (one run, after a message to testudoapp-9a).

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #testudo

## Review Findings (2026-11-25 08:21)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `IntegrationTests/Tests/IntegrationTests/Thread/ThreadHeaderContextMenuHostedTests.swift:205` `reuse/reuse` — The new test `theHostHeaderShowsTheContextMenuOfTheHostPath` repeats the body of the existing test `theHeaderShowsTheContextMenuOfTheHostPath` (line 156). The only difference is the identifier that is queried. Each test repeats the mount, the `contextMenu(identifier:)` call, and the `menuTitles` check. The near-match was copied instead of being parameterized. Add one helper, for example `expectMenuOfHostPath(identifier:header:)`, that mounts the thread, reads the menu of the identifier, and checks `menuTitles`. Call it from both tests. Keep the mount in the helper so that the two tests state only what differs.
- [x] `IntegrationTests/Tests/IntegrationTests/Thread/ThreadHeaderContextMenuHostedTests.swift:215` `reuse/reuse` — The new test `theEmptyPartOfTheHostHeaderShowsTheContextMenuOfTheHostPath` repeats the existing test `theEmptyPartOfTheHeaderShowsTheContextMenuOfTheHostPath` (line 165). It has the same steps: mount, read the frame, compute a point at `maxX - trailingClickInset`, and check the menu. Only the frame identifier and the header argument differ. The near-match was copied instead of being shared. Make one helper that takes the frame identifier and the header, and returns the menu at the trailing point of that frame. Use it from both empty-part tests. The point arithmetic then lives in one place.
- [x] `IntegrationTests/Tests/IntegrationTests/Thread/ThreadHeaderContextMenuHostedTests.swift:221` `reuse/reuse` — The changed line repeats the trailing click point conversion of the status line test at line 170. The same frame, inset, and window conversion are written out a second time instead of being shared. Use the same shared point helper for the header frame as for the status line frame.
- [x] `IntegrationTests/Tests/IntegrationTests/Thread/ThreadHeaderContextMenuHostedTests.swift:239` `reuse/reuse` — The new test `aHostHeaderWithNoPathHasNoContextMenu` repeats the existing test `aHeaderWithNoPathHasNoContextMenu` (line 198). It mounts the thread with `path: nil` and checks that the context menu of one identifier is nil. Only the identifier and the header argument differ. The near-match was copied instead of being shared. Use one helper for the no-path check that takes the identifier and the optional header, as the menu tests do. Call it from both tests.
- [x] `IntegrationTests/Tests/IntegrationTests/Thread/ThreadHeaderContextMenuHostedTests.swift:247` `reuse/reuse` — The new test `aNoticeBannerWithNoPathHasNoContextMenu` repeats the body of `aHostHeaderWithNoPathHasNoContextMenu` (line 239). Both mount with `path: nil`, then check a nil menu of one identifier. The new test differs only in the session with a notice and the identifier. The near-match was copied instead of being shared. Cover both no-path cases with one helper that takes the identifier and the optional session and header. Call it from both tests.