---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7y3rz6tstkszb812vwgtk6b
  text: |-
    ### implement — changed
    - cause 1: the content of ConversationEmptyState was smaller than its scroll view. A click on the empty space hit the AppKit HostingScrollView, so the tap gesture of the host (`.focusesScopeOnClick(.emptySpaceOnly)`) did not fire. Fix: the content fills the visible height (onScrollGeometryChange, less the content margins), with a rectangle content shape.
    - cause 2: the read-only text of the empty state was in the thread scope. EditorKit gives the focus of a scope to the one text view of the scope, or to a focusable view at its center. So the focus of the thread landed in the empty-state text, not on the beacon of the thread. Fix: the title and the text have a scope of their own (`agentEmptyState`), with `.targetable(false)`.
    - test: new hosted suite EmptyThreadClickFocusHostedTests (Testudo bed: window scope, host click outside the agent scope, composer in its own scope, host inspector mode). Red before the fix (no focus move; then the empty-state text was the first responder). Green after the fix: 2 tests passed. The user approved this one hosted run (2026-11-20).
    - note: with a composer that has no scope of its own, the focus goes to the beacon of the thread, as in a thread with messages. The composer does not take the focus. Asked testudoapp-9a if they need that.
    - evidence: swift test: 1553 tests in 177 suites and 54 tests in 11 suites passed. swift format lint -s: 0 findings.
    - next: commit and push.
  timestamp: 2026-11-21T03:53:04.986874+00:00
position_column: todo
position_ordinal: '80'
title: The composer takes the focus in an empty thread (Testudo)
---
Request from testudoapp-9a (2026-11-20). In Testudo, a chat with no messages does not give the focus to the composer, and a click on the empty space of the chat does not focus the chat. This stops 4 Testudo UI tests: the composer click, the ⌥⌘ digit keys, Stop in the Session menu, and the command surfaces.

Facts:
- Testudo applies EditorKit `.focusesScopeOnClick(.emptySpaceOnly, segment:)` on the chat. It clicks at 50% x, 15% y of the chat. In an empty chat this is empty space of the `ScrollView` of `ConversationEmptyState`, above the centered text.
- fb3d8e60 replaced the Textual text of the empty state with an EditorKit `EditorView` (`RenderedMarkdownView`). The `ScrollView` was there before.

Do:
- Add a hosted test in IntegrationTests: an `AgentThreadView` of a session with no transcript entry, a click on the empty space of the empty state. Find the cause with it. The user approved one run of this test (2026-11-20).
- When an empty thread shows, or its scope gets the focus, the composer becomes the first responder.
- Push when `swift test` passes, and send the sha to testudoapp-9a.