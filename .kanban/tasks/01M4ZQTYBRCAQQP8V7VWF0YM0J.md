---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m501b9dgwe0tj545s8sv05r9
  text: |-
    ## Research and design (implement)

    - Client model (FoundationModelsACPClient 838bbad): `SessionModel.prompt(_:meta:)` gives the clear rule: "To know when the work for this prompt ended, wait for the first `idle` agentState after the echo of the message id of the response." The local user message (`origin == .local`) gets `messageId` from the response (or the echo, whichever arrives first).
    - Schema (FoundationModelsACP 7570149): `PromptResponse.messageId`, `UserMessage.messageId` and `ContentChunk.messageId` are all required (not optional). Thus an echo with no messageId cannot decode, and the "no messageId on the echo" case does not occur. No stuck decision is necessary. An agent that sends no echo for a prompt gives no announcement for that prompt (the client rule).
    - The observable model state does not show when the echo arrives in the ACPAgent order (response first, echo later): the echo only updates the linked local entry with the same values. Thus the kit reads `SessionModel.updateTap()`, which gives each raw update in arrival order (echo and state updates in one ordered stream).
    - Design: `ThreadAccessibility.makeTurnAnnouncements(of:) -> AsyncStream<String>` reads the tap with `PromptEndTracker`. The tracker keeps the messageIds of the echoes (`user_message` and `user_message_chunk`) since the last idle. Each idle clears them; it announces only when one of them is the messageId of a local user message of the transcript. `isReplaying` updates are skipped. `turnAnnouncement(old:new:)` became `turnAnnouncement(for: IdleStateUpdate)` (text only). `SessionAnnouncementObserver` uses `.task(id:)` on the stream in place of `onChange(agentState)`.
    - Test design: each fixed-order test makes the stream, sends the prompt (ScriptedWireAgent `.afterResult`, follow-ups after the echo), waits with `ObservationWait.until` for the last agent state, then `connection.disconnect()` ends the tap, and the test collects the whole stream. Thus a test can assert "no announcement" with no clock.
    - Changed tests that encoded the old rule (none deleted): `ThreadAccessibilityTests` turn tests now test `turnAnnouncement(for:)` and `PromptEndTracker` (`aSessionChangeThatDoesNotStopForegroundWorkIsSilent` became `anIdleWithNoEchoOfASentPromptIsSilent`, and the other three were renamed for the new signature); `ThreadAccessibilityHostedTests.aSessionThatGoesIdleAfterItRunsAnnounces...` became `aPromptThatGoesIdleAfterItRunsAnnounces...` and now sends a prompt first.
  timestamp: 2026-10-15T15:02:02.928930+00:00
- actor: claude-code
  id: 01m501bczwqm29c4rw9wrfcc8p
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKit/Accessibility/ThreadAccessibility.swift, Tests/AgentViewKitTests/Accessibility/TurnAnnouncementTests.swift (new, 6 fixed-order tests), Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityTests.swift, Tests/AgentViewKitTests/Accessibility/ThreadAccessibilityHostedTests.swift, Docs/decisions/accessibility.md. RED: `swift build --build-tests` failed with "type 'ThreadAccessibility' has no member 'makeTurnAnnouncements'". GREEN: `swift test --filter 'TurnAnnouncementTests|ThreadAccessibilityTests|ThreadAccessibilityHostedTests'`: 34 tests in 3 suites passed, 0 failures, 0 package warnings.
    - next: the task stays in `doing` for /test and /review. Full-suite run not done (rule: filtered tests only).
  timestamp: 2026-10-15T15:02:06.588883+00:00
- actor: claude-code
  id: 01m501mtvzjby86mcxvqpj28q0
  text: |-
    ### test — red
    - evidence: `swift test` (one full run). 1172 tests in 132 suites. 1 failure, 2 known issues (expected, by design). 0 project compiler warnings. The only build warning is the mlx-swift "missing creator for mutated node" warning from SwiftPM (not a project warning).
    - failure: `theScrollAnchorsSeeTheRowKeyOfEachRowInView()` at Tests/AgentViewKitTests/Thread/SessionTranscriptViewHostedTests.swift:239:7. Text: "Expectation failed: anchors.visibleIDs == session.model.transcript.map(\.rowKey)"; `anchors.visibleIDs` was `[]`; the transcript rowKeys were `["user-message-anchor-u", "agent-message-anchor-m"]`. The test failed after 12.795 seconds.
    - cause analysis: The test pumps with `harness.pump(until: Self.waitTimeout) { anchors.visibleIDs.count == 2 }` (line 237). The pump ended at the timeout with no anchors. This test uses ConversationView and ScrollAnchorManager. This task did not change them. The changed files (ThreadAccessibility.swift and the accessibility tests) are not in its path. It looks timing dependent under load (this suite took 90 seconds). It is a test that fails only sometimes: reported, not fixed. No .timeLimit, sleep, clock wait, poll or retry was added.
    - no source or test changed in this step. No test deleted. The new TurnAnnouncementTests, ThreadAccessibilityTests and ThreadAccessibilityHostedTests passed in this run.
    - next: A person decides on the test in SessionTranscriptViewHostedTests. Do not run the suite again to prove the failure.
  timestamp: 2026-10-15T15:07:15.711162+00:00
- actor: claude-code
  id: 01m5025jr1q4a33pkjb25mrf9j
  text: |-
    ### test — green
    - evidence: `swift test` ran one time over the full suite. Exit code 0. 1172 tests in 132 suites passed. 0 failures. 0 skipped. 2 known issues. Both known issues are in the harness self-tests (HostedLayoutExpectationsTests.swift:23 and ThemeHeightExpectationsTests.swift:35). These tests expect a failure and they pass. No project compiler warning. The only warning is the mlx-swift "missing creator for mutated node" warning from the build system.
    - scope: this one run covers the working tree with both changes (^66f5w2n and ^wf0ym0j). The tests in Tests/AgentViewKitTests/Accessibility/ passed.
    - next: none. No code was changed in this step.
  timestamp: 2026-10-15T15:16:24.449387+00:00
depends_on:
- 01M4ZQTVZC2TE4TJBSADH5H115
position_column: doing
position_ordinal: '8180'
title: 'Mail step 7 T2: Announce "Response complete" only for the idle that ends a user prompt (elicitation-plan task 48)'
---
elicitation-plan.md task 48 (needs ACPAgent task 49, which is done).

Announce "Response complete" only for the first idle after the user_message echo of a user prompt (find the prompt by its messageId). Do not announce on each change to idle (ThreadAccessibility.turnAnnouncement).

An idle from background work (no user prompt ended) announces nothing.

Tests: a fixed-order test for each case (the first idle after the echo of a user prompt announces; an idle from background work does not announce; a later idle with no new prompt does not announce). No clock wait, sleep or poll.

Commit with AgentViewKit green. Report after the task. Write all text in STE. #mail-step-7