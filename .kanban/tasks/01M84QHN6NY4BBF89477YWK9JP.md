---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m84tkqyvdkhk9hjftkfvdbgd
  text: |-
    Research and implementation notes:
    - ThreadHeaderBar is an HStack: Text(verbatim: title) (secondary, one line, tail truncation, layout priority -1), Spacer(minLength: 0), EditorToolbarButton(command:). The overload calls threadHeader { ThreadHeaderBar(...) }, so the view goes in the same ThreadHeaderSlot.
    - EditorToolbarButton(command:) shows nothing when no command system is installed, or when the registry has no visible row of the id at the scope path (EditorButtonPresentation.commandPresentation). The host must register the command at the scope of the thread or at a scope above it. AgentCommandScope appends its segment to the parent commandScopePath, so a host scope above AgentThreadView works.
    - The unit tests read the accessibility tree of an NSHostingView with no window (withAccessibilityTree, accessibilityElements(identifiedAs:under:)), as AgentRowSectionHeaderTests does. performAccessibilityPress on the button runs the command headless, so no hosted IntegrationTests run was necessary for the press proof.
    - The narrow tests first passed with an empty stub header. A require on a height above zero makes them fail correctly. A mutation check (lineLimit removed) made the one-line height test fail.
    - Swift Testing arguments cannot read MainActor statics. FailedTurnFixtures.threadWidth/threadHeight/threadSize are now nonisolated (the file is a symlink shared by IntegrationTests and ScreenshotTests).
  timestamp: 2026-11-23T18:27:37.563786+00:00
- actor: claude-code
  id: 01m84v03qkp89nkff6a49hs9wt
  text: |-
    ### implement — changed
    - evidence: headless `swift test` green (1657 tests in 187 suites, and 54 tests in 11 suites; 0 failures; no code warnings). ThreadHeaderTests: 8 tests, 6 new, each seen RED first. Gallery `HOME=<temp> swift test --package-path ScreenshotTests`: 43 tests passed. Images: ~/Library/Caches/AgentViewKit/screenshot-check/generated/HostedSnapshotTests/thread-external-{light,dark}.png and thread-external-narrow-{light,dark}.png. Look checked: at the narrow width the title truncates and the button stays whole.
    - files: Sources/AgentViewKit/Thread/ThreadHeader.swift, Tests/AgentViewKitTests/Thread/ThreadHeaderTests.swift, ScreenshotTests/Tests/ScreenshotTests/SharedThreadFixtures.swift, ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift, IntegrationTests/Tests/IntegrationTests/Helpers/FailedTurnFixtures.swift (three size constants are now nonisolated, for the @Test arguments)
    - next: /review
  timestamp: 2026-11-23T18:34:22.835620+00:00
- actor: claude-code
  id: 01m84v62hw1jdbvnqmpw8c60j2
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit e673e935): 0 findings, 0 confirmed, 0 refuted. 7 files attempted, 5 reviewed, 2 .kanban files not reviewed (ignore rule), 0 failed. The 8 card boxes are ticked from the implement evidence: headless `swift test` 1657 tests and 54 tests pass; the gallery passes 43 tests; the IntegrationTests build passes; the images are thread-external-{light,dark}.png and thread-external-narrow-{light,dark}.png.
    - next: the task is done.
  timestamp: 2026-11-23T18:37:38.236827+00:00
position_column: done
position_ordinal: ffffffff9680
title: Read-only thread header with a title and one EditorKit command action
---
## What
TestudoApp decision D212 (design /Users/wballard/github/swissarmyhammer/TestudoApp/features/session-import-redesign.md, 5.3, 5.4 and 6): the read-only tab of an external session has a header that shows the source, "read-only", the date of the last record, and the button "Continue in Testudo". Today `.threadHeader { ... }` (TestudoApp D208 (i)) takes only a host view.

Change /Users/wballard/github/swissarmyhammer/AgentViewKit/Sources/AgentViewKit/Thread/ThreadHeader.swift:
- Add a public overload `threadHeader(_ title: String, action command: String) -> some View` (`title` is the host text, already localized, for example "Claude Code · read-only · Nov 21, 2026"; `command` is the id of an EditorKit command, for example the id of Continue in Testudo). It sets `\.threadHeader` to a new view `ThreadHeaderBar`.
- Add `struct ThreadHeaderBar: View`: an `HStack` with `Text(title)` (one line, truncates at its tail, lower layout priority) and, at the trailing edge, `EditorToolbarButton(command: command)`, as Sources/AgentViewKit/Items/MessageActions.swift and Sources/AgentViewKit/Thread/SideQuestionCard.swift bind a command. The command registry gives the button title, the state and the disabled reason. The kit writes no source name, date format or button text.
- The view goes in the same `ThreadHeaderSlot`, so it keeps the identifier `AgentThreadLayout.headerIdentifier`, the content button surface and no glass.
- Update the doc comment of `threadHeader(_:)` with the new overload and an example.

Do not change Sources/AgentViewKit/StatusLine/*.

## Acceptance Criteria
- [x] `.threadHeader("<title>", action: "<command id>")` compiles and shows the title and one command button in the header of `AgentThreadView`.
- [x] The button runs the command through the EditorKit registry and is disabled when the command is not available, as other `EditorToolbarButton(command:)` buttons are.
- [x] At a narrow width, the title truncates and the button stays whole.
- [x] The view overload `threadHeader { ... }` works as before.
- [x] VoiceOver reads the header group with the title text, and the button keeps its own label.

## Tests
- [x] Unit tests first (headless `swift test`), in /Users/wballard/github/swissarmyhammer/AgentViewKit/Tests/AgentViewKitTests/Thread/ThreadHeaderTests.swift: the overload sets the header environment value (use the probe of SlotProbe.swift); the header contains the title text; the button binds the given command id; the old overload still gives the host view.
- [x] Screenshot gallery screen in /Users/wballard/github/swissarmyhammer/AgentViewKit/ScreenshotTests/Tests/ScreenshotTests: a read-only thread with the header "Claude Code · read-only · Nov 21, 2026" and the action "Continue in Testudo" (extend SharedThreadFixtures.swift and add a snapshot in HostedSnapshotTests.swift beside `thread-shared`), at the normal width and at a narrow width. Run: `HOME=$(mktemp -d) swift test --package-path ScreenshotTests`. Give the PNG paths for review.
- [x] `swift test` passes with no new warning.

## Workflow
- Use /tdd -- write failing tests first, then implement to make them pass. #d212