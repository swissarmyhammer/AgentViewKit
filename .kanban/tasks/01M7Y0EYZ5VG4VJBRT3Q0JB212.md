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
- actor: claude-code
  id: 01m7yxarrdv2zvasx5jdsa5295
  text: |-
    ### research
    - da74534b meets the hosted test item and the click item, but not the item "the composer becomes the first responder". After the click, the first responder is the beacon of the thread (the hosted test expects `GeometryProbeView`), not the editor of the composer.
    - EditorKit `requestFocus(at:)` gives the focus to the content of the scope, and never to a view that a nested scope wraps. In Testudo the composer has a scope of its own (`composer`), so a focus on the thread scope lands on the beacon. Thus AgentViewKit must move the focus to the composer itself.
    - Plan: `AgentCommandTarget.focusComposerOfEmptyThread(after:)` calls the composer hook when the transcript is empty, and the move is nil (the thread shows) or its path is the thread path. A driver view in `AgentThreadView` calls it when the thread shows (`.task(id:)` of the session) and on each change of `GeometryRegistry.lastFocusMove`. The composer hook focuses the editor directly, so it records no new focus move, and the last focus move stays the thread path.
  timestamp: 2026-11-21T11:19:42.605577+00:00
- actor: claude-code
  id: 01m7yxzny0y4fy7k8p1m8678y5
  text: |-
    ### implement — changed
    - gap: da74534b did not meet "the composer becomes the first responder". The focus of the thread scope landed on the beacon of the thread.
    - fix: `AgentCommandTarget.focusComposerInEmptyThread(after:)` calls the composer hook when the transcript is empty and the move is `nil` (the thread shows) or goes to the thread path. A new view, `EmptyThreadComposerFocus` (Sources/AgentViewKit/Thread/), in the background of `AgentThreadView`, calls it when the thread shows (after `GeometryRegistry.focusable(at:)` of the thread scope) and at each change of `GeometryRegistry.lastFocusMove`. The hook focuses the editor directly, so it records no new focus move. The new environment value `emptyThreadFocusReport` gives each result to the tests.
    - unit tests: EmptyThreadComposerFocusTests (5 tests). RED: the 2 positive tests failed with `log.focuses == 0`. GREEN after the fix.
    - hosted tests: EmptyThreadClickFocusHostedTests now has 3 tests (show focuses the composer; a click on an empty thread focuses the composer; a click on a thread with a message keeps the beacon). Compile only: `cd IntegrationTests && swift build --build-tests` passed. NOT run (no hosted run allowed).
    - risk for CI: each hosted test that shows an empty `AgentThreadView` with a composer now has the editor as the first responder after the show. A scan of the hosted tests found no test that expects another first responder in an empty thread, but only a hosted run can prove it.
    - not done here, by the order of the caller: push, and the sha to testudoapp-9a.
    - evidence: swift test: 1561 tests in 179 suites and 54 tests in 11 suites passed. swift format lint -s: 0 findings in the new files, and no new findings in AgentThreadView.swift and AgentCommandTarget.swift (same counts as HEAD).
  timestamp: 2026-11-21T11:31:07.840389+00:00
position_column: doing
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