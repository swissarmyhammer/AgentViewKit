---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7ty0228b6drersrrrzn6j57
  text: 'API approved by testudoapp-9a (2026-11-19): AVK reads `session.isReadOnly`; the change verbs are absent from the registry (no disabled rows); the read verbs stay; a replace keeps the scroll position. Still blocked until foundationmodelsacpclient-1d sends the D208 sha (read-only SessionModel, isReadOnly, replace(with:)).'
  timestamp: 2026-11-19T22:14:22.536021+00:00
- actor: claude-code
  id: 01m7v1spqzhk52n3mt9vp5nem9
  text: |-
    Implementation landed (not committed). Discoveries:
    - The pins: FoundationModelsACPClient 55e7aa7 and FoundationModelsACP b4b7abf (it contains fb08304) in the root, IntegrationTests and ScreenshotTests, with `swift package update`.
    - The composer slot is in `AgentThreadView.floatingControls`, not in `ConversationView`. `AgentThreadLayout.showsComposer(for:)` hides it for a read-only model. The kit has no queue of prompts. The mode and model pickers are only in the accessory of the composer (`DefaultPromptAccessory`), so they go with the slot.
    - The consistent way to hide a verb is "not registered": `AgentCommandTarget.registers(_:)`, the same gate as Fork from Here, and the same effect as `groupsOff`. The change verbs are exactly the groups `compose`, `control` and `fork`, so `AgentCommandGroup.changesSession` names them. `isShownOnlyWhenAvailable` is not used, because it keeps the command in the registry.
    - `MessageActions.actions(for:canFork:isReadOnly:)` drops Fork, Retry and Edit for a read-only model.
    - The secondary chords of `AgentKeymap` (Esc for Stop) stay bound. EditorKit skips a binding whose command is not registered, so no test can see a difference; no change was made.
    - The scroll tests passed on the first run: the row key comes from the wire id, and `replace(with:)` keeps each entry and its id, so no production change was necessary for the scroll position.
    - A read-only model has no pending request (ACPClient guarantee), so `RequestDeck` shows no card. I added no extra guard in the deck.
    - Not changed, for the host to decide: the hunk actions of `DiffView` (Accept, Reject, Attach to prompt) come from the `diffActions` of the host. A host must not give them to a shared tab. The status line has no control that changes the session.
    - The header slot and the stopped state of the brief are not in this card.
  timestamp: 2026-11-19T23:20:48.639657+00:00
- actor: claude-code
  id: 01m7v1t9hwyk0gqganaxsje5j4
  text: |-
    ### implement — changed
    - evidence: 10 files. Sources: AgentCommandGroup.swift, AgentCommandTarget.swift, AgentCommandScope.swift, MessageActions.swift, AgentThreadView.swift, RequestDeck.swift (doc only). Tests: new Thread/ReadOnlyThreadTests.swift (10 tests), Commands/ForkFromHereCommandTests.swift (new parameter). ARCHITECTURE.md: section "Read-only thread". Package.resolved (not tracked) of the root, IntegrationTests and ScreenshotTests: ACPClient 55e7aa7, ACP b4b7abf.
    - `swift test`: "Test run with 1534 tests in 175 suites passed" and "Test run with 54 tests in 11 suites passed". Only the allowed mlx-swift warning.
    - `swift build --build-tests`: IntegrationTests and ScreenshotTests both "Build complete!".
    - `swift format lint -s` errors HEAD→now: AgentCommandGroup 1→1, AgentCommandScope 3→3, AgentCommandTarget 11→11, RequestDeck 8→8, MessageActions 2→2, AgentThreadView 9→9, ForkFromHereCommandTests 21→17, ReadOnlyThreadTests (new) 0.
    - next: /review. The task stays in doing. No commit and no push.
  timestamp: 2026-11-19T23:21:07.900263+00:00
position_column: doing
position_ordinal: '80'
title: 'Read-only thread for a shared session: no composer and no change verbs (D208 i)'
---
Brief: /Users/wballard/github/swissarmyhammer/.briefs/share/avk-brief.md and overview.md (testudoapp-9a, D208, TestudoApp commit d803f1a). Read D208 and D110 in TestudoApp/features/decisions.md.

Blocked: this task waits for FoundationModelsACPClient D208 on main (the read-only `SessionModel` from a snapshot, `SessionModel.isReadOnly`, and `replace(with:)`). On 2026-11-19 ACPClient main is af57058, without them. Send the API proposal to testudoapp-9a before the first push (sent 2026-11-19, see the comments).

Do:
- When `SessionModel.isReadOnly` is true, the thread shows no composer, no queue, no elicitation form and no permission buttons.
- The change verbs are not in the registry for a read-only thread: send, stop or cancel, approve and reject of a request, Fork from Here, Mention, Focus Composer, retry, edit, rewind, and the mode and model pickers. Check each verb, button and menu row of the thread.
- The read verbs stay: Copy Message, Copy Thread, Copy Code Block, Export as Markdown…, Find Next Hit, Find Previous Hit, Clear Search Hits and the navigation verbs.
- When the model gets a newer snapshot (`replace(with:)`), the thread keeps its scroll position.
- D110: no glass in the content.

Tests (unit, no window): a read-only model has no composer, the change verbs are not in the registry, the read verbs work, and a replace keeps the scroll anchor.

Push when `swift test` is green, and send the sha to testudoapp-9a.