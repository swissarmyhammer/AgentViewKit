---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6p3j3w967gtjvddqkhx2xz1
  text: |-
    Picked up after ^05e7z9g (commit c43c71bc) on the same branch. Research:
    - ThreadHeaderContextMenuHostedTests (4 tests): the header's menu is AVK's HostPathContextMenu, a PLAIN SwiftUI `.contextMenu` that builds its items at a host path that is not an ancestor scope. EK's `.commandContextMenu` builds only at `\.commandScopePath` (or that path plus a child segment), so it cannot serve a host path without an EK change. None of the 4 tests needs command ids: three read titles, and the run test chooses the item of the built NSMenu (`performActionForItem`), which a ContextMenuItemSnapshot cannot do. So the view stays on plain `.contextMenu` and the tests stay on `contextMenu(identifier:)`, the headless read for a plain menu (no event posted, window off screen and not key). No diff in that file.
    - AgentRowListRowMenuHostedTests (6 runs that read at a point): the bed's RowScopeMenu is a plain `.contextMenu`. Two tests (aMenuOnTheContentLeavesTheInsetBare, theMenuCoversTheInset x4 layouts/densities = 5 runs) check WHICH AREA the menu covers — a right click in the top inset of the row. That is a real hit test; `contextMenuItems(of:)` and `contextMenu(identifier:)` read only at the center of the element. They move to a new suite `AgentRowListRowMenuPointerHostedTests` and keep `contextMenu(at:)` (still no posted event, no key window). theWrapperStandsInTheScopeOfTheRow does not test the area, so it reads with `contextMenu(identifier: RowBed.scope.rowIdentifier(for: id))`.
    - Hit tests kept at a point, listed: AgentRowListRowMenuPointerHostedTests.aMenuOnTheContentLeavesTheInsetBare, AgentRowListRowMenuPointerHostedTests.theMenuCoversTheInset(layout:density:).
    - No AVK test reads a `.commandContextMenu` today (AgentItemScope's menu has no hosted menu test), so no test moves to `contextMenuItems(of:)`.
    - ARCHITECTURE.md "Tests of this kit" now says how a test reads a context menu.
    - Note: a filtered run waited ~20 min on EK's machine UI-test gate held by another session's xcodebuild (pid 2947); not caused by this change.
  timestamp: 2026-11-05T14:59:43.113173+00:00
- actor: claude-code
  id: 01m6p43fzytgkpp7r3xt6xhzhg
  text: |-
    ### implement — changed
    - evidence: commit bfb91c53 on worktree-agent-ab4df383ae84c6d94 (after c43c71bc of ^05e7z9g); 2 files — ARCHITECTURE.md, IntegrationTests/Tests/IntegrationTests/Lists/AgentRowListCurrentHostedTests.swift. Root `swift test`: 983 + 48 tests passed. `swift test --package-path IntegrationTests`: 954 tests in 129 suites passed (5 known issues, the pre-existing withKnownIssue checks in FontRoleExpectationsTests). Only warning: the allowed mlx-swift one. Hit tests kept at a point, in AgentRowListRowMenuPointerHostedTests: aMenuOnTheContentLeavesTheInsetBare, theMenuCoversTheInset(layout:density:). ThreadHeaderContextMenuHostedTests unchanged (plain .contextMenu read with contextMenu(identifier:), no command ids needed; .commandContextMenu cannot build at a host path).
    - next: /review
  timestamp: 2026-11-05T15:09:12.574849+00:00
position_column: done
position_ordinal: ffffffab80
title: Read context menus headlessly with EditorKit's contextMenuItems(of:)
---
EK ^arcymge (on EK origin at de292643): `harness.contextMenuItems(of: "id") -> [ContextMenuItemSnapshot]` returns title, isEnabled, commandID? and isSeparator for a `.commandContextMenu`. It needs no NSMenu, mouse event or activation, and the window can stay off-screen and not key. It finds exactly one element and throws `noElement` or `noCommandContextMenu` otherwise. For a plain SwiftUI `.contextMenu`, `contextMenu(identifier:)` still reads headlessly, but with no command ids.

## What
- Move ThreadHeaderContextMenuHostedTests (4 tests) and AgentRowListRowMenuHostedTests (6 runs) off opening the menu at a point. Use `contextMenuItems(of:)`, or `contextMenu(identifier:)` for plain `.contextMenu`. Where a test needs command ids, move the view to `.commandContextMenu`.
- Do it together with the `perform(_:on:)` migration card, since they touch the same test style.

## Tests
- [x] No hosted test opens a context menu at a point or needs a focused window for it. (Exception, a real hit test of the area the menu covers, kept at a point in AgentRowListRowMenuPointerHostedTests: aMenuOnTheContentLeavesTheInsetBare, theMenuCoversTheInset(layout:density:). No test needs a focused window.)
- [x] The full AVK suite is green.