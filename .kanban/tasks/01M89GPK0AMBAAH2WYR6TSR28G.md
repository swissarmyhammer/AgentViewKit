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