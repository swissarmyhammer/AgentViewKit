---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7qv8dp4rfspne6j1j0d05er
  text: 'API approved by testudoapp-9a (2026-11-18), with a change (D108): Send to Chat, Open and Close must be command buttons of verbs in a side-card command scope, so that the palette and the keyboard can run them when a card has the focus, as the message actions do. Escape on a focused card runs Close. Send to Chat text: "Side question: <question>", a blank line, "Answer: <answer>". API: `SideQuestionCard(question:session:onOpen:onClose:onSendToChat:)` (onSendToChat optional; default inserts into the composer of the thread with no send), and `AgentThreadView.sideCards { }`. The side-card verbs are in the main menu per D41 only if the other item-scope verbs are; follow the existing pattern.'
  timestamp: 2026-11-18T17:28:47.556984+00:00
- actor: claude-code
  id: 01m7qxkm217reh9ad9m1n8nzg0
  text: |-
    Research done. Plan:
    - New verbs `SideCardVerb` (Send to Chat, Open, Close) in a new public group `AgentCommandGroup.sideCard`, as the attachment verbs do: each card registers its verbs at its own scope path `agentSideCard:<sessionId>` (new `AgentScopeKind.sideCard`, an item kind, so the thread verbs stay out of its context menu). Close carries Escape (`StandardChords.leave`) in its definition, so Escape on a focused card resolves to Close before the Stop key of the thread.
    - The card mounts its scope with `AgentScopeMount`, and uses the ambient command system or a private one, as `AgentAttachmentScope` does.
    - Default Send to Chat calls `AgentComposerHook.insert` of the thread target (the path of Mention…), after a focus, with no send. With `onSendToChat`, the host gets the text.
    - `.sideCards { }` puts an AnyView in the environment; `AgentThreadView` shows it in the overlay of the floating controls above the composer (as the scroll pill), so the bottom inset of the list and the scroll position do not change. A custom Layout puts the cards at the trailing edge at a fixed card width, and at full width in a narrow thread.
    - Logic that tests read: `SideQuestionCard.answer(in:)`, `chatText(question:answer:)`, `needsInput(_:)`, `verbs(needsInput:)`, the target availability and runs, the registry.
  timestamp: 2026-11-18T18:09:51.681475+00:00
- actor: claude-code
  id: 01m7qyjfesb5cdbknmpr207bfd
  text: |-
    ### implement — changed
    - evidence: `swift test` at the root: 1377 tests in 161 suites passed, and 54 tests in 11 suites passed. No warning of the kit. `swift build --build-tests` passes in IntegrationTests/ and in ScreenshotTests/ (compiled only; not run). `swift format lint -s` gives no new finding on each changed file.
    - New: Sources/AgentViewKit/Commands/SideCardCommands.swift (SideCardVerb, SideCardCommand, SideCardTarget, SideCardRegistration), Commands/SideCardScope.swift (scope and mount), Thread/SideQuestionCard.swift, Thread/SideCards.swift (SideCardLayout, SideCardStack, `AgentThreadView.sideCards(_:)`). Tests: Tests/AgentViewKitTests/Commands/SideCardCommandsTests.swift, Thread/SideQuestionCardTests.swift, Thread/SideCardsTests.swift; IntegrationTests/.../Thread/SideCardsHostedTests.swift; two snapshots in ScreenshotTests GlassSnapshotTests (`side-card`, `side-card-needs-input`, light and dark).
    - Changed: AgentCommandGroup (new public group `sideCard`, `sideCardVerbs`), AgentCommandPlacement (`AgentScopeKind.sideCard`, an item kind), AgentCommandScope (shared `AgentCommandRegistration.deregister(_:at:from:)`, which the attachment scope now also calls), AgentSymbol (`sendToChat`, `openSideQuestion`), the string catalog, AgentThreadView (cards in the overlay of the floating controls), ARCHITECTURE.md (new section "Side cards"), AgentCommandGroupTests and SymbolConceptTests (the new group and symbols).
    - Decisions: Close and Send to Chat are not available while the fork needs input (only Open shows). With the group `sideCard` off, a card shows no button, as an attachment does. Send to Chat focuses the composer, then calls `AgentComposerHook.insert` (the path of Mention…).
    - Discovery: `SideCardTarget.thread` is weak; a test must keep the thread target alive.
    - next: review.
  timestamp: 2026-11-18T18:26:42.777093+00:00
- actor: claude-code
  id: 01m7qyp3md61gc2ceqgz0sh1sp
  text: |-
    ### test — green
    - evidence: `swift test` at the package root exits 0, no test failure, no skipped test. SideCardsTests, SideCardCommandsTests and SideQuestionCardTests pass. `swift format lint -s` on changed and new files: no new finding versus HEAD. `swift build --build-tests` in IntegrationTests and ScreenshotTests: build complete. The three new unit test files have no sleep, poll, retry, clock, window or focus call.
    - next: review
  timestamp: 2026-11-18T18:28:41.741246+00:00
position_column: doing
position_ordinal: '80'
title: SideQuestionCard and the .sideCards slot of the thread view for /btw (D205)
---
Brief: /Users/wballard/github/swissarmyhammer/.briefs/fork/avk-brief.md, items 4 to 6 (testudoapp-9a, D205). No dependency. Send the API proposal to testudoapp-9a before the first push (sent 2026-11-18, see the comments).

Do:
- Public view `SideQuestionCard(question:session:onOpen:onClose:)`. It shows the question, and the agent messages of the transcript of the fork `SessionModel` as they stream, with the Markdown renderer of the thread. It shows a progress mark while the turn runs.
- Send to Chat: the card puts the question and the answer into the composer of the thread that shows the card, with no send (the composer insertions of AVK-15.6). An optional `onSendToChat` closure lets the host do it instead.
- When the fork needs input (a pending permission request or an elicitation), the card shows "Needs input" and the Open button only.
- Each button is an EditorKit `EditorToolbarButton`, as in the message actions. Escape on a focused card is Close.
- Modifier `.sideCards { ... }` on `AgentThreadView`: a vertical stack of cards at the trailing edge of the thread, above the composer. The host gives the cards in order, newest first. The cards do not change the transcript and do not move the scroll position. In a narrow window the stack goes above the composer at full width.
- Accessibility: each card is one element group with the label "Side question" and the question text. Identifiers: `side-card`, `side-card-send`, `side-card-open`, `side-card-close`.
- Text on glass or a material uses the vibrant label role (D110).

Tests: `SideQuestionCard` with a scripted `SessionModel` shows the streamed answer; Send to Chat, Open and Close call their actions; "Needs input" shows for a pending permission request; `.sideCards` shows two cards with the newest at the top, and the transcript does not change. A snapshot test of the card in light and dark (ScreenshotTests: add it, compile only, do not run; give the PNG paths when the user runs it).

Push when `swift test` is green, and send the sha to testudoapp-9a.