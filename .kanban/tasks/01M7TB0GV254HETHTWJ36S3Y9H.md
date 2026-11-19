---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7tb4xgfbj54609zzqdvqs46
  text: |-
    Research:
    - The Cancel of the hits is `AgentCommandTarget.searchHitsCancel(for:)` (AgentFindCommands.swift). `AgentCommandRegistration.register` adds it after the verbs and before the secondary chords. `deregister(at:)` removes `.cancel` too.
    - Esc order: `register` binds the first chord of each definition. Esc of Stop is a secondary chord (`bindSecondaryChords`), so a verb with Esc as its first chord comes before Stop in the keymap stack. The resolver skips an unavailable binding.
    - Hide: `CommandDefinition.isVisible` is the per-surface gate (palette, menu bar, context menu). `AgentCommand.definition` passes `verb.isVisible(in:)`, which has no target. The new verb needs the target, so the gate reads the availability of the verb at its live target (EditorKit `EditorTogglePresentationCommand` reads its model in `isVisible` the same way, through `MainActor.assumeIsolated`).
    - Hosted test `AgentCommandScopeHostedTests.definitionCount` is `verbCount + 1` for the Cancel; it becomes `verbCount`.
  timestamp: 2026-11-19T16:44:58.767462+00:00
- actor: claude-code
  id: 01m7tbx2sqemysewqjaah8pv2r
  text: |-
    Implementation landed (not committed, not pushed: the dispatcher said so).
    - New verb `AgentCommandVerb.clearSearchHits` (`agent.clearSearchHits`, "Clear Search Hits", Esc = `StandardChords.leave`, group `find`, Edit menu group `agentFind` third row, icon `xmark.circle`). Availability and run use the rules of Find Next Hit; run calls `TranscriptSearch.removeHits()`, which sets the host binding to nil.
    - Hide: new `AgentCommandVerb.isShownOnlyWhenAvailable` (true only for Clear Search Hits). `AgentCommand.isVisible(_:at:in:)` is the `isVisible` gate of each verb definition; for that verb it also needs the availability of its command at the live target.
    - Removed `AgentCommandTarget.searchHitsCancel(for:)` and `canRemoveSearchHits`, the `edit.cancel` registration, and `.cancel` from `deregister(at:)`.
    - Discovery: `AgentKeymap.defaultKeymap` bound the chords in verb order, so its Esc gave Stop before Clear Search Hits (first match wins), which is the opposite of a scope. `sortedChords` now gives the first chord of each verb, then the secondary chords, the same order as a scope binds.
    - Test changes: `noTwoVerbsOfTheKitShareAChord` became `noTwoVerbsOfTheKitShareAChordButEscape`; Esc order tests expect [clearSearchHits, cancel].
    - Not checked (hosted suites are not run): `AgentCommandScopeHostedTests.aMountedThreadViewDoesNotRegisterTheVerbsOfAGroupThatTheHostTurnsOff` expects `forkFromHere` in the set with no host fork action. This was so at HEAD too.
  timestamp: 2026-11-19T16:58:10.615502+00:00
- actor: claude-code
  id: 01m7tbx67dn4x9pc986pmrf8sr
  text: |-
    ### implement — changed
    - evidence: 18 files. `swift test`: "Test run with 1522 tests in 173 suites passed after 26.018 seconds." and "Test run with 54 tests in 11 suites passed after 0.008 seconds." IntegrationTests and ScreenshotTests: `swift build --build-tests` complete, 0 errors, 0 warnings. `swift format lint -s` (now/HEAD): AgentFindCommands 0/0, AgentCommandPlacement 0/0, AgentSymbol 0/0, FindHitCommandsTests 0/0, AgentCommands 2/2, AgentCommandsTests 34/35, AgentKeymap 2/2, AgentCommandScope 3/3, AgentCommandTarget 11/11, AgentCommandGroup 1/1, AgentThreadView 9/9, AgentCommandGroupTests 15/15, AgentCommandPlacementTests 19/19, SessionCommandsTests 6/6, AgentCommandScopeHostedTests 24/24.
    - next: /review
  timestamp: 2026-11-19T16:58:14.125474+00:00
position_column: doing
position_ordinal: '80'
title: 'Clear Search Hits: a custom Esc command, not the EditorKit Cancel row (D207 f)'
---
Request from testudoapp-9a (2026-11-19), after task 01M7SY6JVREKFKFE8JVJ04C0Z9 (ee9fb3fa, 993c94b3).

Now: Esc in a thread with search hits uses the EditorKit standard Cancel command (`edit.cancel`). The thread registers it for its full life, so the Edit menu shows a disabled "Cancel" row while a thread has the focus.

The host does not want that row. TestudoApp does not bind ⌘G or ⇧⌘G, so those keys stay.

Do:
- Add the kit verb `agent.clearSearchHits`, "Clear Search Hits", key Esc, in the `find` group. Register it before the Esc of Stop, as now.
- It is available only while the thread has hits and the focus is not in a text input. It shows in the palette and in the find group of the Edit menu only when it is available: no disabled row when the thread has no hits.
- It sets the host binding to nil, as the Cancel command does now.
- Remove the registration of EditorKit Cancel for the hits. The Edit menu must not show a "Cancel" row from the thread.
- Keep the order: with hits while the agent runs, the first Esc clears the hits and the second Esc stops the agent.
- Update the verb count, the placement, the keymap and the group tests, and the docs (README, ARCHITECTURE.md "Search hits of a thread", AgentCommandGroup).
- TDD unit tests: the verb is hidden with no hits; Esc clears the hits only with hits; the first Esc clears and the second stops; no `edit.cancel` registration from the thread.

Run `swift test`. Push, and send the sha to testudoapp-9a.