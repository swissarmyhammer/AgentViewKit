---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m50pxzz4m9z5ka1s2k7yt66d
  text: |-
    Research (implement):
    - Sites in 8 hosted files of Tests/AgentViewKitTests/Items: ToolCallViewHostedTests, ToolCallEntryViewHostedTests, SessionEntryRowsHostedTests, MessageViewsHostedTests, MessageActionsHostedTests, CompactionAndNoticeHostedTests, EntryTimingHostedTests, UnknownItemViewHostedTests. The other Items files have no wait.
    - All transcript entry objects of FoundationModelsACPClient are @Observable (ToolCallEntry status, locations, rawOutput, linkedElicitationIDs; CompactionEntry status, summary; PlanTranscriptEntry entries; TerminalEntry text; EntryTiming startedAt, endedAt). SessionModel transcript, notices, pendingElicitations, agentState are observable. ScriptedWireAgent.received is observable (A0). So each asynchronous site can wait on a model value that the update is certain to change. The agent sends the frames in order, so a wait on the effect of the last update covers the earlier updates.
    - One update makes the whole tool call entry (init(wire:) copies all fields). Thus after the entry shows in the model, a render pass shows all its parts; the waits for each part (waitForElements, waitForTexts) are not necessary.
    - TerminalView fills the editor model in onChange(of:initial:), which runs in the layout pass. Wait on the terminal entry text, render, then check the editor text.
    - MessageActions edit: composer.load and the promptText binding write synchronously; press(identifier:) renders.
    - Shared helpers to reuse: SessionTranscriptViewHostedTests.entryText(of:at:), ToolCallEntryViewHostedTests.toolCallEntry, TerminalViewHostedTests.firstTerminal(in:), AgentWorkOrderHostedTests.compaction(in:), ComposerSessionModelHostedTests.isRunning, MessageActionsHostedTests.agentEntry, TranscriptChecks.hasErrorEntry, ConfigOptionsSessionModelHostedTests.setParams.
    - Risk: ToolCallViewHostedTests.settle (quiet pumps) let a late body evaluation of the mount happen before the counter reset. Plan: one render pass after the mount, then the reset, then the wait on the model status, then one render pass. If a late evaluation shows in the counts, the site is stuck.
    - Risk: SessionEntryRowsHostedTests.anAppendedErrorShowsItsData has a comment that SwiftUI adds the selectable data text on a second update. Plan: one render pass; if the check fails, the site is stuck.
  timestamp: 2026-10-15T21:19:15.940608+00:00
- actor: claude-code
  id: 01m50r7b9vs47fdt90t6rm9dyx
  text: |-
    ### implement — changed
    - 90 sites changed in 9 files of Tests/AgentViewKitTests/Items: CompactionAndNoticeHostedTests, EntryTimingHostedTests, MessageActionsHostedTests, MessageViewsHostedTests, SessionEntryRowsHostedTests, ThreadExporterTests, ToolCallEntryViewHostedTests, ToolCallViewHostedTests, UnknownItemViewHostedTests. No other file changed.
    - A change from the test (mount, store.expand, choice.identifier, appendError) → harness.render(), then check. A harness action (press) renders, so no line follows it. A change from the agent → ObservationWait.until or render(when:) on the model value that the frame changes (entry count, entry text, tool call status, locations, rawOutput, plan entry status, compaction status or summary, terminal text, notices, pendingElicitations, agentState idle, error entry), then render, then check.
    - Shared helpers reused: SessionTranscriptViewHostedTests.entryText, ToolCallEntryViewHostedTests.toolCallEntry, TerminalViewHostedTests.firstTerminal (FirstTerminalView now uses it, its private copy is deleted), BackgroundRunsHostedTests.agentMessage(messageID:in:), CancelAvailabilityTests.isIdle, ComposerSessionModelHostedTests.isRunning, TranscriptChecks.hasErrorEntry, ConfigOptionsSessionModelHostedTests.setParams. New lookups in SessionEntryRowsHostedTests: thought(in:), plan(in:), compaction(in:), firstPlanStatus(in:).
    - Removed: ToolCallViewHostedTests.settle and quietPumps (one render pass after the mount, then the counter reset); ToolCallEntryViewHostedTests.waitForElements and waitForTexts (one update makes the whole entry); all unused waitTimeout constants. MessageActionsHostedTests.mount now makes the render pass that each caller made.
    - Facts checked in FoundationModelsACPClient: the model links an elicitation to its tool call in the same step as it adds it; accept removes it and its link in the same step as it sends the answer; an idle state ends the open entry in the same step as agentState changes.
    - What did not work: the first filtered run hung. AgentWorkOrderHostedTests.compaction(in:) finds only the compaction id of that suite, not "tests-compaction", so aCompactionUpdateShowsOneRowAtItsPosition waited for ever while it held HostedTestLock, and the other hosted suites waited behind it. sample of the test process: all threads idle (no busy loop). I killed that pid only. Fix: SessionEntryRowsHostedTests.compaction(in:) (first compaction entry). Log: /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/43998bc3-6f4e-4bb7-909b-93c5172edb4f/scratchpad/items-a2.log, sample: items-a2-sample.txt in the same folder.
    - Deviation: two filtered runs, not one. The second run came after the code change that fixed the hang.
    - test: swift test --filter (13 Items suites), run 2: "Test run with 102 tests in 13 suites passed after 5.454 seconds." Only warning: SwiftPM mlx-swift_Cmlx "missing creator for mutated node" (dependency). Log: /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/43998bc3-6f4e-4bb7-909b-93c5172edb4f/scratchpad/items-a2-run2.log
    - search of Tests/AgentViewKitTests/Items: no pump(until:, waitUntil, harness.pump(, pump(for: left. Out of scope and not changed: ScriptedSession.openWithEntry/receiveEntry, receiveElicitation, result(ofRequest:) (Tests/AgentViewKitTests/Helpers) still use waitUntil; SessionTranscriptViewHostedTests.expectAChunkEvaluatesOnlyTheRowOfItsEntry (Thread) still pumps, and SessionEntryRowsHostedTests.aThoughtChunkEvaluatesOnlyTheRowOfItsThought calls it.
    - The working tree of T4-A1 iteration 2 is not touched. No git command that changes the tree.

    step: implement
    outcome: changed
    evidence: 90 sites in 9 files (Tests/AgentViewKitTests/Items); swift test --filter (13 Items suites): 102 tests in 13 suites passed (run 2, after the hang fix of run 1); 0 sites left
    task: ^w35tfs4
  timestamp: 2026-10-15T21:41:51.035003+00:00
- actor: claude-code
  id: 01m50rk233s5ykv7prxjw3dr2d
  text: |-
    ### test - green
    - evidence: swift test, run one time, log /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/43998bc3-6f4e-4bb7-909b-93c5172edb4f/scratchpad/swift-test-9.log. Exit 0. 1201 tests in 138 suites passed. 0 failures. 0 skipped. 2 known issues: aWrappedTextWithAFixedVerticalSizeFails (HostedLayoutExpectationsTests.swift:23) and aViewThatIgnoresTheThemeFails (ThemeHeightExpectationsTests.swift:35). Each test expects a failure by design.
    - warnings: 0 from project sources. 1 warning from the mlx-swift_Cmlx bundle (dependency, not counted).
    - readme gate: Scripts/check-readme.sh exit 0. "README gate passed: each snippet is in its file, and each snippet compiles."
    - code changed: none.
    - next: review.
  timestamp: 2026-10-15T21:48:14.819206+00:00
depends_on:
- 01M50ER0NN5DRGV5S3HGQ8H07P
position_column: doing
position_ordinal: '8180'
title: 'Mail step 7 T4-A2: Remove the clock waits and polls from the Items tests'
---
Part of T4 (^m7q9e97). Area: Tests/AgentViewKitTests/Items (about 85 sites). Same rules as T4-A1: direct render pass, event wait on a certain event where needed, gate or fixed order; no time bound; no read-back of a value that the test wrote; delete no test; report a wait with no event and no direct render before you change it. One full run, one commit. Write all text in STE. #mail-step-7