---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4nqs0a3dzjq5bbdcgn7sbjp
  text: |-
    Research results.

    1. The result bundle in the scratchpad (art/AgentViewKitDemo-test.xcresult) is not from this run. Its dateCreated is 14:10:46Z and it holds only "Timed out while enabling automation mode". Run 38145335740 has two attempts. Artifact 11705056714 (14:13Z) is attempt 1. Artifact 11704604097 (14:32Z) is attempt 2, which holds the crash. I downloaded attempt 2 to scratchpad/art2.

    2. Attempt 2 has 4 crash reports of AgentViewKitDemo, one for each test:
    - pid 16222 (test 1): launch 09:29:56, crash 09:30:04, EXC_BREAKPOINT in +[NSApplication _crashOnException:].
    - pid 16247 (test 2): launch 09:30:04.99, crash 09:30:06.04, SIGABRT.
    - pid 16258 (test 3): launch 09:30:30.52, crash 09:30:31.73, SIGABRT.
    - pid 16278 (test 4): launch 09:30:56.10, crash 09:30:57.18, SIGABRT.
    All four have the same exception: NSGenericException "The window has been marked as needing another Update Constraints in Window pass, but it has already had more Update Constraints in Window passes than there are views in the window." The stack: -[NSWindow updateConstraintsIfNeeded] -> NSHostingView._willUpdateConstraintsForSubtree -> NSHostingView.SizeConstraints.update(from:) -> SplitViewChildController.hostingView(_:didUpdateMinSize:maxSize:) -> AppKitPlatformViewHost.enqueueLayoutInvalidation -> NSHostingView.setNeedsUpdate -> setNeedsUpdateConstraints. It is a constraint update loop on the minimum size of a NavigationSplitView column. No frame of the app or of the kit is on the stack.

    3. The app log of pid 16222 shows before the crash: "onChange(of: AnyTextLayoutCollection) action tried to update multiple times per frame", "ScrollTargetVisibilityChange tried to update multiple times per frame", "<OnScrollGeometryChange Modifier> tried to update multiple times per frame".

    4. Screen recordings (OCR of frames): test 1 shows the session, the sign-in card ("Sign in to the agent", "Demo sign-in"), "hello" sent, and "The agent is working". The window goes away when the turn updates come. Tests 2 to 4 show "Starting In-Memory Agent" and the app stops about 1 s after launch, when the running phase shows the sidebar and the thread with the sign-in card.

    5. The other three tests show "The sidebar shows no session" because the app crashes about 1 s after each launch, before the session row shows. XCUITest then reads a dead app for 20 s. The cause of the three failures is the same crash.

    6. The model path works: a package probe test opened a session on the in-memory agent through DemoAgent, sent "hello" and got demo-reply-1. Hosted probes of the thread and of a NavigationSplitView in an NSHostingView did not crash.

    7. Measurement (probe, not kept): AgentAuthView has the minimum size 58 x 631 pt (sizeThatFits(.zero)) but its height at a usual width is 138 pt. The minimum height is larger than the maximum height. A window with the ACP tab layout (NavigationSplitView, SessionListView, AgentThreadView with the sign-in card, ContextUsageView, PromptInputView) gets contentMinSize 562 x 779 with the card, and 552 x 124 after login (no card). The cause is .fixedSize(horizontal: false, vertical: true) on three texts of AgentAuthView: the minimum height is the wrapped height at width 0.

    8. The pins: CI resolved FoundationModelsACP 7570149 and EditorKit bd2f6fa, not the local 5f94484 and 235cbb7. FoundationModelsACP 5f94484..7570149 is a kanban commit only. EditorKit 235cbb7..bd2f6fa changes CompletionPopup (focusable) and EditorSearchField; none of it is on the crash stack. The alpha.8 move (f3f5c2d) changed StateBanner, SessionNoticeBanner, CompactionEntryView and the theme; none of it is on the stack.

    Note: probeWindow opened real windows on the screen for about 10 s (5 cases). Later probes use an off-screen origin.
  timestamp: 2026-10-11T15:02:22.275960+00:00
- actor: claude-code
  id: 01m4nr6k0nzq48xgamrfkanvsb
  text: |-
    ### implement — changed
    - evidence: Crash = NSGenericException "more Update Constraints in Window passes than there are views in the window" in SplitViewChildController.hostingView(_:didUpdateMinSize:maxSize:) (4 crash reports, one for each UI test, attempt 2 artifact 11704604097). Cause found: AgentAuthView used .fixedSize(horizontal: false, vertical: true) on 3 texts, so its minimum height (446 pt for the test card, 631 pt for the demo card) is more than its height at a usual width (166 pt / 138 pt); the demo ACP tab window min size was 562 x 779 with the card and 552 x 124 without it. The 3 other tests show no session because the app crashes about 1 s after each launch (same exception). Files: Sources/AgentViewKit/Connections/AgentAuthView.swift (remove the 3 fixed vertical sizes, doc text), Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift (new test theMinimumHeightOfTheCardIsNotMoreThanItsHeightAtTheCardWidth: RED 445.9 > 165.9, then GREEN). swift test: 1042 tests in 109 suites passed, 89 tests in 9 suites passed, exit 0; load average 54.64 at start, 41.20 at end. The only warning is the SwiftPM "missing creator for mutated node ... mlx-swift_Cmlx.bundle" of a dependency. xcodebuild build of AgentViewKitDemo: BUILD SUCCEEDED, no warning in AgentViewKit or demo sources.
    - not proven: the constraint loop itself was not reproduced in a package test (hosted NavigationSplitView probes did not crash). A UI test run must confirm the fix.
    - new task: ^ (01M4NQSAANEXRZZZFGWJW4NHBG) for the same fixed vertical text size in PermissionView and ElicitationURLConsentView.
    - next: run the UI tests on CI (or Scripts/test-examples.sh on the CI box), then /review.
  timestamp: 2026-10-11T15:09:47.413800+00:00
- actor: claude-code
  id: 01m4nr6q7pd7va1wv0ypvbe87f
  text: The new task of the step record above is ^jw4nhbg.
  timestamp: 2026-10-11T15:09:51.734577+00:00
- actor: claude-code
  id: 01m4nrqzp6y3dnpp4c2e8wckc0
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 0b962c2). 0 findings, 0 confirmed, 0 refuted. 2 files reviewed. 16 .kanban files not reviewed (ignore rule).
    - next: The task is in done. A UI test run (Scripts/test-examples.sh or CI) must still confirm the fix.
  timestamp: 2026-10-11T15:19:17.446999+00:00
- actor: claude-code
  id: 01m4nrrak8qcjb4m3w8q99yz0x
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — AgentAuthView fixed vertical sizes removed; new hosted test (RED 446 > 166, then GREEN)
    - test: green — swift test, 1042 tests passed, load average 34 to 59; only the known mlx-swift dependency warning
    - commit: 0b962c2
    - review: clean — 0 findings (2 files); task in done
    - open: a CI UI test run must confirm the fix
  timestamp: 2026-10-11T15:19:28.616794+00:00
position_column: done
position_ordinal: ffa180
title: Fix the AgentViewKitDemo crash in the CI UI tests
---
## What
CI run 38145335740 (commit a71b027), job Examples (AgentViewKitDemo): the UI tests now start, but AgentViewKitDemo quits unexpectedly. The owner sees the crash dialog on the CI box.

- `ACPTabEndToEndTests.testASendOfHelloShowsTheReplyOfTheAgent` fails: "Lost connection to the application (pid 16222)".
- Then `testSelectingTheSavedSessionShowsItsReplayedHistory`, `testStoppingTheAgentShowsTheDisconnectedBanner` and `testTheSettingsSheetShowsTheAgentAuthenticationAndNoAgentConnection` fail: "The sidebar shows no session."
- The result bundle `examples-AgentViewKitDemo-results` (artifact of the run) has the crash report.

## Work
- [x] Get the crash report and the stack from the result bundle.
- [x] Find the cause and write a test that shows it, where a package test can show it.
- [x] Fix the cause.
- [x] Find why the other three tests show no session. If the cause is the crash, record that.

## Open
- A UI test run (`Scripts/test-examples.sh` or CI) must confirm the fix. The UI tests were not run on the owner machine.