---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dexnes8z2jykqbea8akd3z
  text: |-
    Research and implementation notes (AVK-7d).

    - EditorKit facts: a bare `.commandScope` has a zero-size beacon. `GeometryRegistry.snapshot(layer:)` drops zero-area scopes, so the nav kernel did not see the item scopes. `.navVisible()` gives the beacon the area of the content. Jump mode already listed each scope, but with a zero-size anchor.
    - Focus commit: `GeometryProbeView.requestFocus` gives the first responder to the focusable view that holds the center of the scope, else to the first focusable view in order. A message row has only small Textual `NSTextInteractionView`s, so a jump or a nav move to message 2 focused the text view of message 1. Fix: `AgentItemFocusTarget` (new file Sources/AgentViewKit/Commands/AgentItemFocusTarget.swift), an NSView behind each item with the size of the item. It accepts first responder, is not a key view (Tab does not change), is not a click target (hitTest nil), and draws the system focus ring.
    - `AgentItemScope` now applies, in this order: focus target background, `.jumpTarget(isJumpTarget ? JumpTargetOverride() : .hidden)`, the context menu, `.commandScope`, `.navVisible()`. New parameter `isJumpTarget` (default true). `DeckCard` passes `role.showsWhole`, so an edge card or a hidden card has no jump label.
    - The thread scope is not navVisible. Its beacon center is in the middle of the thread, so a focus commit on it would focus an item. The kit registers no nav.* command: the host does, as EditorKit tells. The content verbs of the kit do not change.
    - Discovered: EditorKit nav.up / nav.down are inverted on macOS (AppKit window coordinates are y-up). New task ^brhhdf4. The nav test orders the two messages by EditorKit minY, so it holds before and after that fix.
    - Discovered: a deck card that does not show whole is still in the nav snapshot. An `if` on the role would change the identity of the card and lose its state, and EditorKit has no value form of `.navVisible()`. New task ^td23hf5.
    - Tried and dropped: the question to the user about these two blockers. The user said to make a good decision.
  timestamp: 2026-10-20T20:09:24.185085+00:00
- actor: claude-code
  id: 01m5dey0cxrsg4qp7p7wxqh4by
  text: |-
    ### implement — changed
    - evidence: 4 files — Sources/AgentViewKit/Commands/AgentItemFocusTarget.swift (new), Sources/AgentViewKit/Commands/AgentItemScope.swift, Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift, Tests/AgentViewKitTests/Commands/AgentNavigationHostedTests.swift (new). RED: `swift test --filter AgentNavigationHostedTests` 5 tests failed with 10 issues for the expected causes. GREEN: the same 5 tests (6 cases) pass. Full `swift test`: 1356 tests in 159 suites pass (2 known issues are the existing withKnownIssue self-tests), 130 PackageStructure tests pass, no new warnings.
    - follow-up tasks: ^brhhdf4 (EditorKit nav y-axis inverted on macOS), ^td23hf5 (deck card that does not show whole stays in the nav snapshot).
    - next: /review
  timestamp: 2026-10-20T20:09:35.389454+00:00
- actor: claude-code
  id: 01m5df271mrnh3cwz6khdbf4bx
  text: |-
    ### test — green
    - evidence: swift test — 1356 tests in 159 suites passed, 0 failed, 0 skipped, 2 known issues (existed before). The only warning is the mlx bundle build warning (existed before). No new warnings.
    - next: review
  timestamp: 2026-10-20T20:11:53.268578+00:00
depends_on:
- 01M5D07NRD75D8MPV6VDJVERBA
position_column: doing
position_ordinal: '80'
title: AVK-7d EditorKit navigation and jump on messages, tool calls and request cards
---
Design: AVK-7, D105 (d). Step 5 work.

Each item scope (agentMessage, agentToolCall, agentRequest) becomes a target of the EditorKit navigation (FocusNavigator, the nav.* drill) and of the jump engine (`.jumpTarget`, EditorCommandsUI/JumpTargetModifier.swift:226). Follow the pattern of KanbanViewKit and SnapshotViewKit (their plan.md §6.3).

The content verbs of the kit stay: Next/Previous Prompt, Next/Previous Request, Scroll to Bottom.

Acceptance: hosted tests show that the nav chords move between two message items, and that the jump overlay lists the items of the thread. Tests follow the repo test rules: certain events, no clock, no sleep, no poll. #avk-7