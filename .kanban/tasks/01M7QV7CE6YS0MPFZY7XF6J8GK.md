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
- actor: claude-code
  id: 01m7qz2jhnapfayednj0xtyz0p
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (8eab72b1). 5 findings confirmed, 2 refuted. Sources/AgentViewKit/Commands/SideCardCommands.swift:134, Sources/AgentViewKit/Commands/SideCardScope.swift:101, Sources/AgentViewKit/Thread/SideQuestionCard.swift:98, Tests/AgentViewKitTests/Commands/SideCardCommandsTests.swift:135, Tests/AgentViewKitTests/Commands/SideCardCommandsTests.swift:148
    - next: Do each item of the "Review Findings (2026-11-18 12:29)" checklist. Then do the review again. The task stays in review.
  timestamp: 2026-11-18T18:35:30.229033+00:00
- actor: claude-code
  id: 01m7qz34zbgxv469qn1sk08nk6
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 19 files (SideQuestionCard, SideCards, SideCardCommands, SideCardScope, tests, snapshots)
    - test: green — swift test, 1377 tests in 161 suites + 54 tests in 11 suites passed
    - commit: 8eab72b1
    - review: findings — SideCardCommands.swift:134, SideCardScope.swift:101, SideQuestionCard.swift:98, SideCardCommandsTests.swift:135, SideCardCommandsTests.swift:148
  timestamp: 2026-11-18T18:35:49.099100+00:00
- actor: claude-code
  id: 01m7rfgj5yqbk5ntj4a5as05fh
  text: |-
    Review findings (2026-11-18 12:29) done:
    1. Duplication: new `AgentCommandPresentation` and `CommandDefinition.init(_:target:isVisible:make:)` in Sources/AgentViewKit/Commands/AgentCommandPresentation.swift. `SideCardVerb.presentation` and `AgentAttachmentCommand.Action.presentation` give the data. `SideCardCommand.definition(of:for:)` and `AgentAttachmentCommand.definition(of:for:)` use the helper. AgentCommands.swift is not changed: new task ^7jp7d (01M7RF9TSZHFTJXXR3R0V7JP7D) moves `AgentCommand.definition(of:for:)` to the helper.
    2. Reuse: new generic `AgentScopeAnchor<Target>` (NSViewRepresentable) in AgentScopeMount.swift owns makeCoordinator, makeNSView, updateNSView and dismantleNSView. `SideCardMount` and `AgentAttachmentMount` are now plain views that give only the write step and the register step. `AgentCommandMount` stays as it is: its coordinator also removes parts from the target.
    3. Docs: `body` of SideQuestionCard, and each declaration with no doc comment in the new files (SideCardCommand members, Availability extension, SideCardLayout sizeThatFits and placeSubviews, environment and view extensions, property wrappers, SideCardScope body).
    4 and 5. Reuse in tests: new Tests/AgentViewKitTests/Commands/CommandTestSupport.swift with `availability(of:at:in:)` (CommandID, FocusPath, CommandRegistry) and `expectKitPrefix(of:id:)`. SideCardCommandsTests lost its copy; ForkFromHereCommandTests forwards to the shared helper. The kit-prefix check of AgentCommandsTests, AgentAttachmentCommandsTests and AgentFileSelectionCommandsTests also calls the helper.
    New tests: AgentCommandPresentationTests (7), AgentScopeAnchorTests (3; a window-less NSHostingView mounts and removes the anchor in the layout pass, with no wait).
    Discovery: in a test struct, a stored property with the name `system` clashes with the C function `system` inside a computed property; use `self.system`.
  timestamp: 2026-11-18T23:22:45.822235+00:00
- actor: claude-code
  id: 01m7rfgp005gv6b9k4cyzvwc9k
  text: |-
    ### implement — changed
    - evidence: `swift test` at the root: 1388 tests in 163 suites passed, and 54 tests in 11 suites passed; no warning in Sources or Tests of the kit. `swift build --build-tests` passes in IntegrationTests/ and ScreenshotTests/ (not run). `swift format lint -s` on each changed file: no new finding versus HEAD. Files: Sources/AgentViewKit/Commands/{AgentCommandPresentation (new), AgentAttachmentCommands, AgentAttachmentScope, AgentScopeMount, SideCardCommands, SideCardScope}.swift, Sources/AgentViewKit/Thread/{SideQuestionCard, SideCards}.swift, Tests/AgentViewKitTests/Commands/{CommandTestSupport (new), AgentCommandPresentationTests (new), AgentScopeAnchorTests (new), SideCardCommandsTests, ForkFromHereCommandTests, AgentCommandsTests, AgentAttachmentCommandsTests, AgentFileSelectionCommandsTests}.swift. All 5 findings checked.
    - next: review
  timestamp: 2026-11-18T23:22:49.728071+00:00
- actor: claude-code
  id: 01m7rfgz0smqnqyqrqxt1stmqw
  text: 'Correction: the short id of the new task (01M7RF9TSZHFTJXXR3R0V7JP7D) is ^0v7jp7d, not ^7jp7d.'
  timestamp: 2026-11-18T23:22:58.969316+00:00
- actor: claude-code
  id: 01m7rfmfbd4yeg0db219d4jmn3
  text: |-
    ### test — green
    - evidence: swift test at package root: "Test run with 1388 tests in 163 suites passed after 29.885 seconds." and "Test run with 54 tests in 11 suites passed after 0.036 seconds." Exit code 0.
    - evidence: swift format lint -s on all changed and new Swift files: zero findings.
    - evidence: swift build --build-tests in IntegrationTests and ScreenshotTests: both "Build complete". They were not run.
    - evidence: AgentCommandPresentationTests, AgentScopeAnchorTests and CommandTestSupport have no sleep, poll, retry, clock, window or focus code.
    - note: the only warning is "missing creator for mutated node" for the mlx-swift_Cmlx bundle. It comes from the build system and not from this change.
    - next: review.
  timestamp: 2026-11-18T23:24:53.997329+00:00
- actor: claude-code
  id: 01m7rfw92emcvgp16q8et4a22y
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (497a1d5a); 5 findings (5 confirmed, 3 refuted). Tests/AgentViewKitTests/Commands/AgentCommandPresentationTests.swift:31, Tests/AgentViewKitTests/Commands/AgentCommandPresentationTests.swift:70, Tests/AgentViewKitTests/Commands/AgentScopeAnchorTests.swift:39, Tests/AgentViewKitTests/Commands/AgentScopeAnchorTests.swift:53, Tests/AgentViewKitTests/Commands/AgentScopeAnchorTests.swift:82. The 5 findings of 2026-11-18 12:29 are all checked.
    - next: implement the 5 open items of the section "Review Findings (2026-11-18 17:25)". The task stays in review.
  timestamp: 2026-11-18T23:29:09.710345+00:00
- actor: claude-code
  id: 01m7rfwt4w7hsn2jvkq89p0gvs
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — 17 files (AgentCommandPresentation, AgentScopeAnchor, docs, CommandTestSupport)
    - test: green — swift test, 1388 tests in 163 suites + 54 tests in 11 suites passed
    - commit: 497a1d5a
    - review: findings — AgentCommandPresentationTests.swift:31, AgentCommandPresentationTests.swift:70, AgentScopeAnchorTests.swift:39, AgentScopeAnchorTests.swift:53, AgentScopeAnchorTests.swift:82
  timestamp: 2026-11-18T23:29:27.196334+00:00
- actor: claude-code
  id: 01m7rgbf19wtgvxdf2d7vm9bv5
  text: |-
    Review findings (2026-11-18 17:25) done:
    1. AgentCommandPresentationTests: `makePresentation` starts from `SideCardVerb.closeSideCard.presentation` and sets only `key` and `buttonTitle`. These two fields of `AgentCommandPresentation` are `var`, so `SideCardVerb.presentation` needs no new parameters. The literal title "Close" is gone; the tests compare with the title of the presentation.
    2. `staticText(of:)` moved from AgentAttachmentCommandsTests to `CommandTestSupport.staticText(of:)`. All callers use it: AgentCommandPresentationTests, AgentAttachmentCommandsTests, ForkFromHereCommandTests, ExportMarkdownCommandTests.
    3. AgentScopeAnchorTests shows `SideCardMount` (its body is the `AgentScopeAnchor`), so the anchor uses the production write and register steps. No injected closure is left. The tests assert the question and the session that the production write copies from the values.
    4. New `StyleViewHost.layOut(_ hosting: NSHostingView<some View>)` in Sources/AgentViewKitTestSupport/StyleViewHost.swift. `StyleViewHost.layOut(_ view:)` calls it, and `Fixture.show` calls it on its one hosting view.
    5. The removal test expects the registered ids after the mount, before the removal.
    Discovery: the line of AgentAttachmentCommandsTests with the button title became too long after the move; it is now two lines, so the LineLength count is the same as at HEAD.
  timestamp: 2026-11-18T23:37:27.337320+00:00
- actor: claude-code
  id: 01m7rgbj2x2jed86pm4qqpewcw
  text: |-
    ### implement — changed
    - evidence: `swift test` at the root: 1389 tests in 163 suites passed, and 54 tests in 11 suites passed. `swift build --build-tests` in IntegrationTests/ and ScreenshotTests/: Build complete (not run). `swift format lint -s` on each changed file: no new finding versus HEAD. Files: Sources/AgentViewKitTestSupport/StyleViewHost.swift, Tests/AgentViewKitTests/Commands/{AgentScopeAnchorTests, AgentCommandPresentationTests, CommandTestSupport, AgentAttachmentCommandsTests, ForkFromHereCommandTests, ExportMarkdownCommandTests}.swift. All 5 findings of 2026-11-18 17:25 checked. No test waits, shows a window or takes the focus.
    - next: review
  timestamp: 2026-11-18T23:37:30.461956+00:00
- actor: claude-code
  id: 01m7rgfwghbnyh55e86q81hj0k
  text: |-
    ### test — green
    - evidence: `swift test` at package root. Log lines: "Test run with 1389 tests in 163 suites passed after 31.057 seconds." and "Test run with 54 tests in 11 suites passed after 0.013 seconds." No failure, no skip, no code warning. The only warning is a build tool note about the mlx bundle (not from this task).
    - `swift format lint -s` on the 7 changed Swift files: no new finding against HEAD. AgentAttachmentCommandsTests.swift and ForkFromHereCommandTests.swift have 21 findings each, and HEAD has the same 21.
    - `swift build --build-tests` in IntegrationTests and in ScreenshotTests: both build complete. Not run.
    - next: review
  timestamp: 2026-11-18T23:39:52.209432+00:00
- actor: claude-code
  id: 01m7rgm31s39dex45js8d73n27
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (968473ff). 7 files reviewed. 0 findings, 0 confirmed, 1 refuted. All 10 earlier findings are checked.
    - next: none. The task moved to done.
  timestamp: 2026-11-18T23:42:09.977925+00:00
- actor: claude-code
  id: 01m7rgmg583zwzd9ybbnpy8va8
  text: |-
    ### finish iteration 3 — clean
    - implement: changed — 7 test and test-support files (production steps, shared helpers)
    - test: green — swift test, 1389 tests in 163 suites + 54 tests in 11 suites passed
    - commit: 968473ff
    - review: clean — 0 findings, 10 earlier findings checked
  timestamp: 2026-11-18T23:42:23.400274+00:00
position_column: done
position_ordinal: fffffff580
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

## Review Findings (2026-11-18 12:29)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 17 file(s) reviewed, 6 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

> 2 file(s) not reviewed — no validator matched:
> - `ARCHITECTURE.md` — no validator matches this file
> - `Sources/AgentViewKit/Resources/Localizable.xcstrings` — no validator matches this file

- [x] `Sources/AgentViewKit/Commands/SideCardCommands.swift:134` `duplication/duplication` — SideCardCommand.definition(of:for:) builds a CommandDefinition with the same shape as AgentCommand.definition(of:for:) and AgentAttachmentCommand.definition(of:for:). The keys dictionary, the id, title, icon, menu and contextMenu wiring, and the weak-target make closure repeat. A fix to one copy, such as how keys or the weak target are handled, will not reach the others. Extract one shared helper that takes the id, title, icon, menu, contextMenu, cua key and make closure as parameters. Build the side card definition through it. Keep the difference (the side card keys and the absence of isVisible) as arguments. Do not edit AgentCommands.swift; report the other copies as a separate task.
- [x] `Sources/AgentViewKit/Commands/SideCardScope.swift:101` `reuse/reuse` — SideCardMount repeats the NSViewRepresentable lifecycle of AgentAttachmentMount: makeCoordinator builds an AgentScopeMount around a deregister function, makeNSView and updateNSView both call apply(scopeMount:), dismantleNSView calls coordinator.unmount(), and apply writes the target and then calls scopeMount.mount(at:in:) with a register closure. Only the target, the values written and the register call differ. Two copies of this boilerplate will drift apart on the next change to the mount lifecycle, such as the newest-mount rule. Move the representable shell into one generic mount, parameterized by the target, the values write and the register closure, or extend AgentScopeMount so it owns makeNSView, updateNSView and dismantleNSView. Then SideCardMount and AgentAttachmentMount each supply only their write and register steps.
- [x] `Sources/AgentViewKit/Thread/SideQuestionCard.swift:98` `code-hygiene/missing-docs-swift` — AllPublicDeclarationsHaveDocumentation: add a documentation comment for 'body'.
- [x] `Tests/AgentViewKitTests/Commands/SideCardCommandsTests.swift:135` `reuse/reuse` — The new `availability(of:in:)` helper repeats the same lookup as `ForkFromHereCommandTests.availability(at:in:)`: find the row by verb id in `eligible(path:)`, then map `isEnabled` to `.available` or `.unavailable(reason:)`. Two copies of one test helper will drift apart. Move one shared helper into a common test file, taking a `CommandRegistry`, a `FocusPath`, and a `CommandID` (not a fixture type), and call it from both suites. Then delete the copy in SideCardCommandsTests.swift.
- [x] `Tests/AgentViewKitTests/Commands/SideCardCommandsTests.swift:148` `reuse/reuse` — The kit-prefix check repeats in each verb test suite. The test that checks each verb id is `agent.<rawValue>` is a copy of the same assertion in other suites, so the rule for the kit prefix is not kept in one place. Add one helper that takes a sequence of verb ids and their raw values and asserts the `agent.` prefix, then call it from each verb suite. Keep each suite's own title assertion, since the titles differ per verb.

## Review Findings (2026-11-18 17:25)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 16 file(s) reviewed, 4 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

- [x] `Tests/AgentViewKitTests/Commands/AgentCommandPresentationTests.swift:31` `reuse/reuse` — makePresentation rebuilds the presentation of the Close verb field by field. SideCardVerb.presentation already builds it, but it does not take a key or a button title, so the test copies it and adds those two values. Give SideCardVerb.presentation optional buttonTitle and key parameters with nil defaults, then build the test presentation from it with `.closeSideCard.presentation`, changing only the parameters the test sets.
- [x] `Tests/AgentViewKitTests/Commands/AgentCommandPresentationTests.swift:70` `reuse/reuse` — The same cross-suite call to AgentAttachmentCommandsTests.staticText(of:) appears again to read the button title. The helper should live in the shared test support, not in the attachment suite. Use the moved CommandTestSupport.staticText(of:) helper here, as in the fix for line 62.
- [x] `Tests/AgentViewKitTests/Commands/AgentScopeAnchorTests.swift:39` `test-integrity/no-hard-code` — The injected `write` closure writes the literal `AgentScopeAnchorTests.question` into the target. The test then asserts that the target holds that same literal, so the assertion matches the stub's constant instead of a value the anchor computes. This is the stub-returns-expected-value pattern that the rule forbids, and it means the test cannot fail for a wrong write. Remove the `write` override so the anchor uses its production write. Assert on the value the production write computes from the target's state. If a seam is needed, make the injected closure compute a value from its input and assert that the output depends on that input.
- [x] `Tests/AgentViewKitTests/Commands/AgentScopeAnchorTests.swift:53` `reuse/reuse` — Fixture.show re-implements the sizing and layout code that already exists in StyleViewHost.layOut. StyleViewHost's doc comment says the unit tests use that one helper and keep no copy of the sizing code. The new copy sets the frame from fittingSize and calls layoutSubtreeIfNeeded, the same steps as layOut. The copy adds a second place to maintain the same behavior. The helper cannot be called as is, because layOut builds a new NSHostingView each time, and show must reuse one hosting view so the anchor can mount, update and dismantle. So the near-match should be extended, not copied. Add a StyleViewHost function that lays out a given NSHostingView<AnyView> (for example layOut(_ hosting: NSHostingView<AnyView>, with view: some View)), and make StyleViewHost.layOut call it. Then have Fixture.show call the shared function on its persistent hosting view, and import AgentViewKitTestSupport in this file.
- [x] `Tests/AgentViewKitTests/Commands/AgentScopeAnchorTests.swift:82` `test-integrity/no-test-cheating` — The removal test never checks that the commands were registered before the anchor went away. If the anchor never registers anything, `registeredIDs.isEmpty` still passes, so the test cannot fail for a broken removal path. This makes the assertion trivial. Add `#expect(fixture.registeredIDs == Set(SideCardVerb.allCases.map(\.id)))` after the mount and before the removal. Keep the emptiness check after the removal so the test proves that the removal clears the registered commands.