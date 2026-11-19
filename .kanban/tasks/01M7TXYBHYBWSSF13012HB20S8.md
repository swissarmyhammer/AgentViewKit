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
- actor: claude-code
  id: 01m7v212vxm0mgx55dk971284k
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (542c9a0d). 2 findings, 2 confirmed, 0 refuted. Tests/AgentViewKitTests/Thread/ReadOnlyThreadTests.swift:70, Tests/AgentViewKitTests/Thread/ReadOnlyThreadTests.swift:141. The test file is new in this commit, thus the rule for tests that existed before does not apply.
    - next: Do the 2 items in the "Review Findings (2026-11-19 17:22)" section. Then do the review again.
  timestamp: 2026-11-19T23:24:50.429516+00:00
- actor: claude-code
  id: 01m7v22ktb1kj7embsghdhdx4f
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — AgentCommandGroup, AgentCommandTarget, AgentCommandScope, MessageActions, AgentThreadView, RequestDeck (doc), ReadOnlyThreadTests (new), ForkFromHereCommandTests, ARCHITECTURE.md; ACPClient 55e7aa7, ACP b4b7abf
    - test: green — swift test, 1534 tests in 175 suites + 54 tests in 11 suites passed (run by the implement step after its edits)
    - commit: 542c9a0d
    - review: findings — ReadOnlyThreadTests.swift:70 (reuse of chunk helper), ReadOnlyThreadTests.swift:141 (test passes on an empty menu)
    - note: the board read the text of a finding as the tag "expect"; the orchestrator removed that tag.
  timestamp: 2026-11-19T23:25:40.555355+00:00
- actor: claude-code
  id: 01m7v27twwhk24dz78r3w3krv2
  text: |-
    ### implement — changed
    - Finding 1: removed the local chunk(_:id:). The suite now calls TranscriptSearchTests.chunk. That helper is internal, and other suites already call static helpers of other suites (AgentCommandsTests), so no move was necessary.
    - Finding 2: the context menu test now requires copyMessage in the menu before the isDisjoint check. The same gap was in two more tests: the change verb test now requires that copyThread is in the registry, and the replace row key test now requires that the first transcript is not empty.
    - evidence: Tests/AgentViewKitTests/Thread/ReadOnlyThreadTests.swift; swift format lint -s: 0 errors (HEAD 0); swift test: "Test run with 1534 tests in 175 suites passed", "Test run with 54 tests in 11 suites passed".
    - next: review
  timestamp: 2026-11-19T23:28:31.644810+00:00
- actor: claude-code
  id: 01m7v2bvn06fazzjx4mh644xzb
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (32ddc0ca). 0 findings (confirmed 0, refuted 0, 7 attempted, 0 failed). 1 file reviewed. 4 .kanban files are excluded by .reviewignore. The 2 earlier findings are checked.
    - next: the task is in done.
  timestamp: 2026-11-19T23:30:43.488606+00:00
- actor: claude-code
  id: 01m7v2d7a4jp7tp30j6n7f6wkt
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — ReadOnlyThreadTests.swift (shared chunk helper; non-empty checks before each disjoint check)
    - test: green — swift test, 1534 tests in 175 suites + 54 tests in 11 suites passed (run by the implement step after its edits); lint 0 errors
    - commit: 32ddc0ca
    - review: clean — 0 findings, 2 earlier findings checked
  timestamp: 2026-11-19T23:31:28.196565+00:00
position_column: done
position_ordinal: ffffffff8780
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

## Review Findings (2026-11-19 17:22)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 8 file(s) reviewed, 3 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `ARCHITECTURE.md` — no validator matches this file

- [x] `Tests/AgentViewKitTests/Thread/ReadOnlyThreadTests.swift:70` `reuse/reuse` — The new static helper chunk(_:id:) reimplements an existing helper with the same body. A second copy can diverge from the first and must be fixed twice. Call the existing helper instead. Remove the local chunk(_:id:) and call the existing helper, for example TranscriptSearchTests.chunk, if it is reachable from this test target. If it is private to that test type, move it to a shared test support file and have both suites use it.
- [x] `Tests/AgentViewKitTests/Thread/ReadOnlyThreadTests.swift:141` `test-integrity/no-test-cheating` — The test theContextMenuOfAMessageOfAReadOnlyThreadHasNoChangeVerb passes when the context menu is empty. It checks only that no change verb is present (isDisjoint), and it never checks that the menu holds any verb. If the message path is wrong, or the mirror returns nothing, the assertion still passes. The test can therefore pass without proving that the read-only filter works on a message menu. Add a precondition that the menu is not empty, for example(ids.contains(AgentCommandVerb.copyMessage.id)), before the isDisjoint check. This shows the menu was measured and that the message path is correct, so the disjoint check can fail.
