---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5n1b065pxycszpjhgjjdq4z
  text: |-
    Picked up. Discoveries before any code change:
    - Package.resolved is not tracked (8684838). The local pins were stale (EditorKit bae8f95 has no CommandSystem.mount), so `swift build` and the Xcode build of the demo failed. `swift package update` moves to the newest mains, but then FoundationModelsACPClient 6395cca (2026-10-23) "move InProcessAgent from AgentViewKit into FoundationModelsACPClient" makes `InProcessAgent` ambiguous in DemoSupport/DemoAgent.swift and Examples/ReadmeSnippets. Local workaround: pin FoundationModelsACPClient in the untracked Package.resolved to 04197c9 (6395cca^). With that pin `swift build --build-tests` passes. The kit must adopt the client InProcessAgent in a separate task.
    - The demo xcodeproj keeps its own Package.resolved in project.xcworkspace/xcshareddata/swiftpm. Copy the root Package.resolved there before Scripts/test-examples.sh.
    - Run 3 of Scripts/test-examples.sh (EditorKit 0222582): testASendOfHelloShowsTheReplyOfTheAgent failed at typeText: "Neither element nor any descendant has keyboard focus". The log shows an interrupting window of another app (Icon Composer, "Untitled (Testudo copy)") over the demo window. The other 3 ACP tests and the Gallery test passed.
  timestamp: 2026-10-23T18:45:56.549910+00:00
- actor: claude-code
  id: 01m5n31g8rmm0zvrbgk0dby372
  text: |-
    Root cause found.
    - The demo WindowGroup had no default size. SwiftUI sized the window to the ideal size of its first content: 900 by 494, 572 or 619 points in the runs. While the in-memory agent asks for a sign-in, the detail column of the ACP tab needs more height: toolbar, top bar, and a bottom bar with the state banner (60), the sign-in card (139.5), the composer and the mode picker.
    - Hosted replica of the ACP window (NavigationSplitView + toolbar, titled window): at 1100x700, 760 and 820 the process stops with NSGenericException "more Update Constraints in Window passes than there are views in the window" (stack: SplitViewChildController didUpdateMinSize). With print probes: the detail column is taller than the window (scroll view height 919-1018 in a 760 window), the list scrolls the short content under the top bar, the list reports no visible row, the manager unpins, the scroll-to-bottom pill shows, the bottom bar grows 32 points, the row is visible again, the manager pins, the pill goes away, and so on with no end. With the pill line removed, 760 passes. At 900 the test passes in 0.55 s.
    - In the real app AppKit catches the exception in the run loop, so the app does not stop. This explains the AX snapshot of the failure: conversation-list content "Other" 0x0 with no rows, and the state banner stuck at "The agent is working".
    - At 572 the hosted test does not crash, but the rows of the first turn are not all in the list (RED).
    - Environment noise seen in some runs, not a kit defect: other app windows (Icon Composer "Testudo copy", Finder) interrupted the clicks, and typeText then failed with "Neither element nor any descendant has keyboard focus".
    Fix in this task: DemoWindowLayout.defaultSize (1100x900) on the WindowGroup, and a hosted test of the ACP window at that size. The kit loop (pill height feeds back into the pin state when the bars do not fit) goes to a new task.
  timestamp: 2026-10-23T19:15:42.488140+00:00
- actor: claude-code
  id: 01m5n3dq8bnmn2szx5d4jrc4dy
  text: |-
    ### implement — changed
    - evidence: 7 files — Sources/DemoSupport/DemoWindowLayout.swift (new: defaultSize 1100x900, shared sidebar widths), Examples/AgentViewKitDemo/AgentViewKitDemo/AgentViewKitDemoApp.swift (.defaultSize), Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift and GalleryTabView.swift (sidebar widths from DemoWindowLayout), Tests/AgentViewKitTests/ACP/ACPWindowReplica.swift (new), Tests/AgentViewKitTests/ACP/ACPWindowLayoutHostedTests.swift (new), Tests/AgentViewKitTests/ACP/GalleryWindowReplica.swift (sidebar widths from DemoWindowLayout). The UI test is unchanged.
    - RED: theListOfTheDefaultWindowShowsEachRowOfTheFirstTurn failed at 900x572 (rows out of view); at 700/760/820 the process stopped with the Update Constraints loop. GREEN at 1100x900.
    - Scripts/test-examples.sh: 3 runs in a row, each "Executed 5 tests, with 0 failures", "The example gate passed."
    - swift test: 1698 tests in 209 suites passed (3 known issues, all existing withKnownIssue tests); 227 tests in 30 suites passed.
    - Local setup, not in git: Package.resolved updated with `swift package update`, FoundationModelsACPClient pinned to 04197c9, and copied to the demo xcodeproj.
    - New tasks: ^tqvfq6z (use the client InProcessAgent), ^4yw9781 (kit layout loop with the pill when the bars are taller than the column).
    - next: /review
  timestamp: 2026-10-23T19:22:22.859333+00:00
- actor: claude-code
  id: 01m5n3mb2stjghcwv3e4cne02p
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (6a80b43). Counts: findings 0, confirmed 0, refuted 1, attempted 7, failed 0. The ignore rule (.reviewignore) excluded 6 .kanban files.
    - next: The task moved to done.
  timestamp: 2026-10-23T19:25:59.769739+00:00
- actor: claude-code
  id: 01m5n3mkxjfbdpht7e06hdsgfg
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 7 files
    - test: green — swift test, 1698 passed, 0 failed, 0 skipped
    - commit: 6a80b43
    - review: clean — review sha HEAD~1..HEAD, 0 findings
  timestamp: 2026-10-23T19:26:08.818376+00:00
position_column: done
position_ordinal: ffffc980
title: 'Demo UI test: after a send of "hello" the reply row is not in the AX tree (testASendOfHelloShowsTheReplyOfTheAgent)'
---
Found by the implement step of ^69g4a69 (2026-10-23), with EditorKit 37325a2 and the EditorKit composer (EditorKitPromptEditor with `.editorTextAccessibilityIdentifier("prompt-editor")`).

`Scripts/test-examples.sh`: `ACPTabEndToEndTests.testASendOfHelloShowsTheReplyOfTheAgent` now gets past the composer: XCUI finds "prompt-editor" (a TextView), clicks it, types "hello", and clicks "prompt-submit". It then fails at ACPTabEndToEndTests.swift:100, "The transcript shows no reply.": `item-row-agent-message-demo-reply-1` never exists within 20 s.

The failure-time AX snapshot in `.build/examples/AgentViewKitDemo/AgentViewKitDemo-test.xcresult` shows the send worked:
- `state-banner`: "The response is complete"; `context-usage`: 1%.
- `conversation-list` ScrollView: value "3 of 3 items", frame height 96.6 pt in a 900x619 window, with no row children exposed (one 0x0 `Other`).
- `scroll-to-bottom-pill` shows, so the list is not pinned to the bottom.
- Above the composer, the floating controls hold the end-turn banner (60 pt) and the `agent-auth` panel (139.5 pt), which leave the list little room.
- "prompt-editor" TextView {580x16}, Keyboard Focused, Disabled; Send Disabled (empty after the send). XCUI still logs "Falling back to element center point" for both clicks. That is the ^bc6fapz hit-point symptom, but it no longer fails the test.
- Measured in a hosted probe: AppKit reports `isAccessibilityEnabled() == false` for every NSTextView, even an editable one (plain NSTextView, SwiftUI TextEditor, and EditorKit EditorInputTextView all report false). So the "Disabled" on the editor is AppKit's default and not a kit bug.

To do: find why the reply row is not in the AX tree. Candidates are a list that isn't pinned after the send (the pill shows) and lazy rows outside a 96 pt viewport. Fix it in the kit, or make the demo layout leave the list room, without weakening the UI test.

Acceptance: `Scripts/test-examples.sh` passes, with this test green on 3 runs in a row; `swift test` green. #bug #avk-8