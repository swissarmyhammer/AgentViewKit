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
position_column: todo
position_ordinal: '9980'
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