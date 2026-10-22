---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5hkwa18g8akgs5z8g0gg8jj
  text: |-
    Blocker: the EditorKit option is not on EditorKit main.

    - `git fetch origin` in ../EditorKit: origin/main is 348324fd2dda570e3a15c1d939a4e70078d9d6d3, the same commit AgentViewKit resolves. There are no new commits on main.
    - At origin/main, `Sources/EditorCommandsUI/ContextMenuPipeline.swift` has `contextMenuMirror(at path: FocusPath, mode: KeymapMode = .cua)` and `commandContextMenu(_ system: CommandSystem, mode: KeymapMode = .cua)`. Neither has a parameter that hides the rows that are not available.
    - The card says "Do not start this card before that option is on EditorKit main", and both acceptance tests need `contextMenuMirror(at:)` with the option. The work cannot be done inside AgentViewKit alone.
    - The ../EditorKit working tree has uncommitted changes (GeometryRegistry.swift, CommandScopeHarnesses.swift, GeometryRegistryTests.swift) and new kanban tasks. None of them is on main. I did not edit or commit there.

    No code changed in AgentViewKit. The card stays in todo. Start it again after the option is merged to EditorKit main.

    ### implement — stuck
    - evidence: EditorKit origin/main = 348324f (no new commits); ContextMenuPipeline.swift has no option to hide the unavailable rows
    - next: merge the hide-unavailable option of `.commandContextMenu` / `contextMenuMirror(at:)` to EditorKit main, then run /implement ^sq1j7ce again
  timestamp: 2026-10-22T10:53:00.328989+00:00
- actor: claude-code
  id: 01m5hkwmzkhd9gkedtryqhx3ts
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — EditorKit origin/main 348324f (= resolved): commandContextMenu(_:mode:) and contextMenuMirror(at:mode:) in Sources/EditorCommandsUI/ContextMenuPipeline.swift have no option to hide unavailable rows. 0 files changed.
    - test, commit, review: not run
    - next: EditorKit main ships the hide-unavailable option on .commandContextMenu; then /implement this card again.
  timestamp: 2026-10-22T10:53:11.539441+00:00
- actor: claude-code
  id: 01m5hkyvp61k3ng0maxfbykwqc
  text: 'Blocker tracked in EditorKit as ^1se9rnw (01M5HK4EQWPG2MW99NV1SE9RNW), per editorkit-28. Planned: an option on `.commandContextMenu` and `contextMenuMirror(at:)`, either "disable" (default, today''s behaviour) or "hide". With hide, unavailable rows are dropped, and so are empty or doubled separators. The parameter name comes with the SHA. Not landed yet.'
  timestamp: 2026-10-22T10:54:23.942125+00:00
- actor: claude-code
  id: 01m5j8p8dg1c55d5j8wb8xrg5w
  text: 'UNBLOCKED: EditorKit main 83731ed (^1se9rnw), additive. `.commandContextMenu(system, unavailable: .hide)`. The enum is `ContextMenuUnavailablePolicy`, with `.disable` (the default) and `.hide`. With `.hide`, unavailable rows are dropped, and so are sections or separators left empty or doubled. `contextMenuMirror(at:mode:unavailable:)` and iOS `UIContextMenuMirror(system:path:mode:unavailable:)` take the same option. It works with `.targetable(false)`: commands still resolve at the nearest targetable ancestor. To do: in AgentItemScope (around line 47), use `.commandContextMenu(system, unavailable: .hide)`; the card''s acceptance tests use `contextMenuMirror(at:unavailable: .hide)`.'
  timestamp: 2026-10-22T16:56:42.160417+00:00
- actor: claude-code
  id: 01m5jbgehtdar9g11rzcewqv19
  text: |-
    Research and implementation notes:
    - EditorKit pin: Package.swift pins EditorKit at `branch: "main"`, and Package.resolved is not tracked in git. The resolved checkout .build/checkouts/EditorKit is e72f75f. `git merge-base --is-ancestor 83731ed HEAD` there exits 0, so the option is present. No manifest edit is needed for the pin.
    - Shared policy: added `ContextMenuUnavailablePolicy.agentItem` (= `.hide`) in Commands/AgentItemScope.swift. AgentItemScope calls `.commandContextMenu(system, unavailable: .agentItem)`, and the test calls `contextMenuMirror(at:unavailable: .agentItem)`, so the test reads the same policy as the view. `AgentItemScope` is generic, so a static stored property there is not possible. That is why the constant is an extension on the EditorKit enum.
    - Test: AgentCommandPlacementTests.theContextMenuOfAMessageHidesTheJumpsThatTheViewMenuDisables. With no scroll anchors, Next Prompt and Previous Prompt are not available at a message path. The test checks that the context menu leaves out both, and that `menuMirror(at:)` shows both in the View menu with isEnabled == false. No clock, sleep, poll, retry, timeLimit or XCUITest.
    - TDD: RED 1 was a compile error (no `.agentItem`). RED 2 set `.agentItem = .disable`: 2 issues, `!contextIDs.contains(verb.id)` failed for both jumps, and the main-menu assertion passed. GREEN came with `.hide`.
    - The existing theContextMenuOfAMessageShowsCopyMessageAndTheJumps test still passes. It uses the default `.disable` policy on the registry directly.
  timestamp: 2026-10-22T17:45:57.562289+00:00
- actor: claude-code
  id: 01m5jbghp1yf39e16tmypmberc
  text: |-
    ### implement — changed
    - evidence: 2 files — Sources/AgentViewKit/Commands/AgentItemScope.swift, Tests/AgentViewKitTests/Commands/AgentCommandPlacementTests.swift. `swift test --filter AgentCommandPlacementTests`: 11/11 passed. Full `swift test`: 1593 tests in 199 suites passed (3 known issues: the intentional withKnownIssue tests in SnapshotStoreTests, HostedLayoutExpectationsTests and ThemeHeightExpectationsTests), plus 219 tests in 29 suites and 1 test in 1 suite, all passed. The one build warning, "missing creator for mutated node" on the mlx-swift_Cmlx bundle, comes from the SwiftPM build and not from this change.
    - next: /review ^sq1j7ce
  timestamp: 2026-10-22T17:46:00.769773+00:00
- actor: claude-code
  id: 01m5jbpf00zhhn3pmzw9t5c0e4
  text: |-
    ### test — green
    - evidence: `swift test` — 1593 tests in 199 suites passed, 0 failed, 0 skipped; no project warnings (only the known mlx-swift "missing creator" dependency notice). The 3 "known issues" are existing withKnownIssue negative-path tests (e.g. SnapshotStoreTests, HostedLayoutExpectationsTests) that pass by design.
    - next: review/commit
  timestamp: 2026-10-22T17:49:14.624835+00:00
- actor: claude-code
  id: 01m5jbt0t2k5xf52er9wqrkywx
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (e99caba) — 0 findings, 0 confirmed, 0 refuted; 2 files reviewed, 4 .kanban/ files excluded by .reviewignore
    - next: task moved to done
  timestamp: 2026-10-22T17:51:11.170297+00:00
- actor: claude-code
  id: 01m5jbtfakqr2vf5rwpgwsyanc
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — AgentItemScope.swift (ContextMenuUnavailablePolicy.agentItem = .hide) and AgentCommandPlacementTests.swift (new test; red first with .disable: 2 issues)
    - test: green — swift test 1593 passed, 0 failed, 0 skipped (EditorKit e72f75f, which contains 83731ed)
    - commit: e99caba (local, not pushed)
    - review: clean — 0 findings, task in done
  timestamp: 2026-10-22T17:51:26.035995+00:00
position_column: done
position_ordinal: ffffb380
title: AVK-9 Hide the commands that are not available in the item context menus
---
Source: testudoapp-4c, TestudoApp card ^tt5k0r6. Rules D41, D109 and D44.

Rule: a command that is not available for the focus is disabled in the main menu. It does not show in a context menu.

Problem: `AgentItemScope` (Commands/AgentItemScope.swift) uses EditorKit `.commandContextMenu`. That modifier, and `contextMenuMirror(at:)`, show a row that is not available as a disabled (grey) row. Thus Next Prompt and Previous Prompt show grey in the context menu of a message row or a request card when they are not available.

Dependency: EditorKit must first get an option of `.commandContextMenu` (and of `contextMenuMirror(at:)`) that hides the rows that are not available. This change is in the EditorKit repo, not in this repo. Do not start this card before that option is on EditorKit main.

Do:
- Update the EditorKit pin to the commit that has the option.
- Use the option in `AgentItemScope`.

Acceptance:
- A headless test: at a message path where Next Prompt is not available, `contextMenuMirror(at:)` with the option does not contain Next Prompt.
- The same test: the main menu still shows Next Prompt as disabled.
- The AgentCommandPlacementTests still pass.
- No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-9