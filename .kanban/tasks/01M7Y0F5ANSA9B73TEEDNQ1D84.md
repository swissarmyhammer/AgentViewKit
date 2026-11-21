---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7yvsdzjhx5z4wawh6ax96rd
  text: |-
    ### Integration job hang — facts (2026-11-21)
    - Run 44863705973, job 136741707622, commit dda19651. Runner: m3u1.
    - The step "Run the selected integration tests" started at 05:32:39 UTC. The job was cancelled at 08:28:55 UTC (duration 10,575 s). I did not cancel it: it was already cancelled when I looked.
    - The last test event is at 05:34:48 UTC. 40 tests started and did not end. The last ones: aSubmitPassesTheAttachmentsAndClearsTheRow(), theFocusedInspectorShowsItsScopeRing(), aLandingOnTheCardWhileTheCommentFieldHasTheFocusFocusesTheCard(landing:), aFocusedItemWithNoSurfaceShowsItsScopeRing(kind:).
    - From 05:34:48 to 08:28:51 UTC, the log shows only one line, about 6 times each second (66,138 lines in all): "info FoundationModelsCodeContext.index: [FoundationModelsExtras] enter FoundationModelsCodeContext.index.pass". The first one is at 05:33:29 UTC.
    - No AgentViewKit source or test uses FoundationModelsCodeContext. The line comes from a dependency, possibly the real agent that an integration test starts.
    - This is not the same as the EditorKit hang (font server): here a process continues to write the index log.
    - At the cleanup, the runner stopped the orphan processes swiftpm-testing (22393) and swift-package (21717).
    - Next: the user decides if the runners get a restart of fontd. Then run the job again. The card stays open.
  timestamp: 2026-11-21T10:52:45.938671+00:00
- actor: claude-code
  id: 01m7yvwrdawq8x22fh0jzjqw3r
  text: |-
    ### Integration job hang — the last lines before the stop (2026-11-21)
    - FoundationModelsExtras says that the "index.pass" lines are an idle poll of each CodeContext (300 ms sleep). They do not block the tests. They are only noise after the stop.
    - The log lines at 05:34:48 UTC are one flush of the output. Their own time stamps are 05:34:45 to 05:34:46 UTC. After log line 18589, the log has no other line than "index.pass", up to the cancel at 08:28:55 UTC.
    - The last lines that are not "index.pass" (log lines 18565 to 18589):
      - 05:34:46 rpc.method=session/close session.id=scripted-session.
      - aFocusedViewWithASurfaceShowsNoScopeRing(surface:) passed. AttachmentCommandsHostedTests passed. theComposerShowsTheRowOnlyWhenItHasAttachments() passed.
      - aSubmitPassesTheAttachmentsAndClearsTheRow() started, then rpc initialize and session/new.
      - aFocusedItemWithNoSurfaceShowsItsScopeRing(kind:) failed for kind .message at AgentItemFocusHostedTests.swift:168: the responder is EditorText.EditorInputTextView (472 x 16), not GeometryProbeView. This is the AgentItemFocus failure of the earlier red job 136420732846.
      - The case kind .toolCall of aFocusedItemWithNoSurfaceShowsItsScopeRing(kind:) started, then rpc initialize and session/new. This is the last line.
    - Thus the process stopped during the case .toolCall of aFocusedItemWithNoSurfaceShowsItsScopeRing(kind:), or during aSubmitPassesTheAttachmentsAndClearsTheRow(), both after session/new. The log does not show which test holds the stop. A timeout with stack samples (workflows 9b5f96b) is necessary to find it.
  timestamp: 2026-11-21T10:54:34.922476+00:00
- actor: claude-code
  id: 01m7ywp9qs6n0j7vamgy529x7b
  text: |-
    ### The index.pass lines — fix in a dependency (2026-11-21)
    - FoundationModelsCodeContext 90f3003 (main): the idle index loop runs a pass only when a file waits. Thus the "index.pass" lines go away from the Integration log.
    - AgentViewKit gets FoundationModelsCodeContext only as a dependency of a dependency (through Multitool). Package.resolved is not tracked, thus CI resolves the newest main on each run.
    - This fix does not fix the stop of the tests. The 30-minute timeout with the stack sample (d2b5ffb3) shows the cause on the next run.
  timestamp: 2026-11-21T11:08:31.865809+00:00
- actor: claude-code
  id: 01m7zzcdayf6vdnk24qk8gkx27
  text: |-
    ### Integration run with the 30-minute limit (2026-11-21)
    - Run 44906413428, job 136859513205, commit 59d61e00, runner m3u1. The test step ran 13:38:54 to 13:59:00 UTC. At 13:58:55 the job sampled the process swiftpm-testing-helper (pid 32768) and stopped it. Artifact: integration-hang-samples (local copy: scratchpad/hang/32768.txt).
    - The same tests fail as in job 136420732846 (about 18): AgentItemFocus (theFirstResponderCoversAFocusedItem, theBeaconOfAnItemWithNoFocusableViewHoldsTheFocus .message), TranscriptSearchStep escape, AgentRowListRename (3, textView.string == text), accessibility text labels (compaction summary, agent message chunks, wire text block, math, linked blocks, Markdown attachment "json"), ThreadHeaderContextMenu empty part, ThreadBarBannerOverlap, submit hook mentions.
    - After about 13:41 no test event comes until the sample. The main thread does not block: it waits in the run loop (OutermostRunLoopGuard.runAgain, OutermostRunLoopGuard.swift:83, mach_msg) and gets no event. The other threads are idle: the CodeContext index loop (GRDB reader, Store.drainLspDirty) and the cooperative pool. Thus one test awaits an event that never comes. It is not a deadlock and not the font server.
    - The output of Swift Testing is buffered, so the start times do not show which test waits. 20 tests started and did not end before 13:41. Tests that are open in both hangs (job 136741707622 and this job): aFocusedItemWithNoSurfaceShowsItsScopeRing(kind:) (in both runs, the .message case of an AgentItemFocus test fails just before the stop), theFocusedInspectorShowsItsScopeRing(), aSubmitPassesTheAttachmentsAndClearsTheRow(), aJumpOnTheCardFocusesTheCardAndNotItsCommentField(), aSubmitAttemptShowsTheErrorOfEachFieldThatIsNotValid().
    - Next: find the await with no bound in those tests (for example in AgentScopeSubjectHostedTests.sendScopeToolCall, used by the .toolCall case after the .message case fails), and fix the failing tests.
  timestamp: 2026-11-21T21:14:48.030177+00:00
position_column: todo
position_ordinal: '8280'
title: Integration CI job on main is red (run 44757895393, a60d101a)
---
Request from testudoapp-9a (2026-11-20). Job "Integration (opt-in, real dependencies)" on mini-01 failed. The user cleared the runner screens, and the job runs again (rerun started 2026-11-20).

Failures:
- `TranscriptSearchStepHostedTests.swift:86` findNextHitRunsInAMountedThreadWithHits: `registry.perform(findNextHit)` is false.
- `ThreadBarBannerOverlapHostedTests.swift:84` theLastRowAtRestIsAboveTheBannersOfTheBottomBar.
- `AttachmentTextContentHostedTests.swift:23` aMarkdownAttachmentShowsTheRenderedForm.
- `ThreadAccessibilityHostedTests.swift:223` theTextsOfTheBlocksOfOneMessageLinkEachOther.
- `AgentItemFocusHostedTests.swift:149` theFirstResponderCoversAFocusedItem(kind: .message, landing: .nav).

Do:
- Read the result of the rerun. For each failure that stays, find the cause from the CI log and the code, and fix it. The hosted suites are not run locally; CI checks them.
- Push, and send the sha and the CI result to testudoapp-9a.