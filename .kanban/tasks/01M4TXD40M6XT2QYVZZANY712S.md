---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4tyvbeyb6wh22xk2eewyksp
  text: |-
    Research and discoveries:
    - The artifact examples-AgentViewKitDemo-results (5.8 GB) holds no .ips crash report. The app output of pid 7688 (StandardOutputAndStandardError-org.agentviewkit.examples.AgentViewKitDemo.txt in the diagnostics of the test xcresult) holds the NSGenericException and the stack in the description. I deleted the artifact after I read it.
    - A hosted test with the offscreen HostedViewHarness window did not crash. The harness window grows when the minimum size grows, so no loop occurs. A probe showed the true fault: in a resizable window, the Gallery columns (sidebar, detail with AgentThreadView, inspector) have a minimum content width of 1476 pt, the width of the window. setContentSize to a narrower width snaps back to 1476. With a Text detail the minimum is 840 pt.
    - Bisection: each part of AgentThreadView alone gives a small minimum (header 72 pt, stream banner 96 pt, conversation 95 pt). A `Text` with `.inspector(isPresented: .constant(false))` or with `.attachmentInspector(selection:)` in the detail gives 1380 pt. So two nested inspectors cause the fault: the look inspector of the Gallery and the attachment inspector that AgentThreadView always applies.
    - The fault is in this repository (the demo layout), not in a sibling package.
    - What did not work: comparing sizeThatFits(.zero) or fittingSize of the detail alone. These values were small and stable. Only contentMinSize of a resizable window shows the fault.
    - I did not change the kit inspector behavior. The test theThreadViewOfASessionShowsTheSelectionOfTheHost documents that AgentThreadView shows the inspector of a host selection itself.
  timestamp: 2026-10-13T15:42:11.422347+00:00
- actor: claude-code
  id: 01m4tyw4499dews2278ehys7zk
  text: |-
    ### implement — changed
    - evidence: crash = NSGenericException "more Update Constraints in Window passes than there are views", from SplitViewChildController.hosting(_:didUpdateMinSize:maxSize:), because the Gallery look inspector and the AgentThreadView attachment inspector are nested. Fix: new Sources/DemoSupport/GalleryColumns.swift (the look controls show in a popover of the Look button); GalleryTabView uses it; doc notes in AgentThreadView.swift and README.md. Tests: RecordedSessionsAgentTests/theGalleryWindowOfEachRecordedSessionGetsNarrower (RED: 7 of 7 sessions snapped back to 1476 pt; GREEN after the fix) and theGalleryDetailShowsATranscriptRowOfEachRecordedSession, over Tests/AgentViewKitTests/ACP/GalleryWindowReplica.swift. Full swift test: 1155 tests in 129 suites passed (2 known issues are the meta-tests of HostedLayoutExpectations and ThemeHeightExpectations), 123 tests in 16 suites passed, 1 test passed; one SwiftPM build-graph warning "missing creator for mutated node" for the mlx-swift_Cmlx bundle, which is not from this change. xcodebuild build of AgentViewKitDemo: BUILD SUCCEEDED. The built app ran 25 s with --tab gallery and quit with status 0; I did not click a row, because that needs UI automation. Commit c3efe56 (local, not pushed).
    - next: /review. CI must run GalleryTabEndToEndTests to confirm the fix in the app.
  timestamp: 2026-10-13T15:42:36.681745+00:00
- actor: claude-code
  id: 01m4v13szzs4csnr4wpw3df6p5
  text: |-
    ### CI green: run 38424460243 (commit 9a9a362)
    - Examples passed: `GalleryTabEndToEndTests.testOpeningARecordedSessionShowsItsTranscript` now passes on CI, with the 4 ACP tab tests.
    - README gate and Build & test passed.
    - next: /review.
  timestamp: 2026-10-13T16:21:45.599905+00:00
- actor: claude-code
  id: 01m4v20egeszqj8tzem44jrzaf
  text: |-
    ### review — findings
    - evidence: review sha c3efe56~1..c3efe56 — 2 findings — Tests/AgentViewKitTests/ACP/GalleryWindowReplica.swift:15, Tests/AgentViewKitTests/ACP/RecordedSessionsAgentTests.swift:214
    - next: Do the 2 open items in the "Review Findings (2026-10-13 11:34)" section. Then review the task again.
  timestamp: 2026-10-13T16:37:24.110656+00:00
- actor: claude-code
  id: 01m4v20w6fzbdw5mrbeqq5w3wk
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — earlier, in commit c3efe56
    - test: green — swift test (implement record), CI run 38424460243 green
    - commit: c3efe56
    - review: findings — Tests/AgentViewKitTests/ACP/GalleryWindowReplica.swift:15, Tests/AgentViewKitTests/ACP/RecordedSessionsAgentTests.swift:214
  timestamp: 2026-10-13T16:37:38.127026+00:00
- actor: claude-code
  id: 01m4v2cdkjc1cmj5m0nx021hz9
  text: |-
    ### implement — changed
    - evidence: 2 files — Tests/AgentViewKitTests/ACP/GalleryWindowReplica.swift (the window size now uses the named constants windowWidth and windowHeight; no other unnamed number stays in the file), Tests/AgentViewKitTests/ACP/RecordedSessionsAgentTests.swift (new helper resumeEachSessionFromTheStart(of:_:) lists the sessions, resumes each one from the start, and gives each resumed session to an async closure; aResumeFromTheStartReplaysEachRecordedSession, openAndResumeEachSession and hostTheGalleryWindowOfEachSession use it; the suite stays .serialized). swiftlint no_magic_numbers with allowed_numbers [0, 1, -1, 100]: the HEAD version of GalleryWindowReplica.swift gives 2 violations, the new versions of both files give 0. Full swift test: 1 test in 1 suite passed, 123 tests in 16 suites passed, 1155 tests in 129 suites passed (2 known issues are the meta-tests of HostedLayoutExpectations and ThemeHeightExpectations). One SwiftPM build-graph warning "missing creator for mutated node" for the mlx-swift_Cmlx bundle stays; it is not from this change. Both findings are checked. No commit, no push.
    - next: /review.
  timestamp: 2026-10-13T16:43:56.402198+00:00
position_column: doing
position_ordinal: '8280'
title: Stop the crash of the demo app when the Gallery opens a recorded session
---
## Problem

CI run 38417316066 (commit c70fa53), job Examples (AgentViewKitDemo). The 4 UI tests of the ACP tab pass. The UI test `GalleryTabEndToEndTests.testOpeningARecordedSessionShowsItsTranscript` lists the recorded sessions and clicks the row `session-row-01M4QARTPZYRA02Y9RD2PBJA5A`. Then the test fails: "Failed to get matching snapshots: Lost connection to the application (pid 7688)".

## Evidence (app output of pid 7688 in the xcresult bundle)

- The client sends `session/resume` for 01M4QARTPZYRA02Y9RD2PBJA5A. The agent resumes it replay-only.
- Two times: `[Invalid Configuration] onChange(of: AnyTextLayoutCollection) action tried to update multiple times per frame.`
- Then: `*** Terminating app due to uncaught exception 'NSGenericException', reason: 'The window has been marked as needing another Update Constraints in Window pass, but it has already had more Update Constraints in Window passes than there are views in the window. <SwiftUI.AppKitWindow> {{510, 193}, {1475, 587}}'`
- Stack (top): `-[NSWindow(NSDisplayCycle) _postWindowNeedsUpdateConstraints]` < `-[NSView setNeedsUpdateConstraints:]` < `NSHostingView.setNeedsUpdate` < `NSHostingView.beginTransaction` < `GraphHost.asyncTransaction` < `ViewGraphHost.LayoutInvalidator.invalidate` < `AppKitPlatformViewHost.invalidateLayout` < `AppKitPlatformViewHost.enqueueLayoutInvalidation` < `SplitViewChildController.hosting(_:didUpdateMinSize:maxSize:)` < `NSHostingView.SizeConstraints.update(from:)` < `NSHostingView._willUpdateConstraintsForSubtree` < `-[NSWindow updateConstraintsIfNeeded]`.
- So the minimum size of a column of the `NavigationSplitView` of the Gallery tab changes in each constraint pass, and AppKit stops the app.

## Cause

The Gallery tab put its look controls in an `.inspector` of its `NavigationSplitView`. The detail holds `AgentThreadView`, which always has its own attachment inspector (`attachmentInspector(selection:)`). With two inspectors, the minimum width of the detail column becomes the width of the window (1475.5 pt for a 1475 pt window), so the window cannot get narrower. A window that also cannot get wider then gets a new minimum size in each constraint pass, and AppKit stops the app. The ACP tab has no inspector of its own, so its tests pass.

## Work

- [x] Write an in-process package test (no UI test) that opens each recorded session through `DemoAgent.makeInProcess(recordedSessions:)` and hosts the views of the Gallery detail. The test fails before the fix.
- [x] Fix the cause. When the cause is in a sibling package, record it here and stop.
- [x] Run the full `swift test` and build the demo app.

#bug

## Review Findings (2026-10-13 11:34)

> Scope: `review sha c3efe56~1..c3efe56` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 5 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `README.md` — no validator matches this file

- [x] `Tests/AgentViewKitTests/ACP/GalleryWindowReplica.swift:15` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/AgentViewKitTests/ACP/RecordedSessionsAgentTests.swift:214` `reuse/reuse` — The new hostTheGalleryWindowOfEachSession repeats the resume loop that openAndResumeEachSession and aResumeFromTheStartReplaysEachRecordedSession already write out: list the sessions, then resume each one from the start. The same request builder is repeated in each copy. Add one helper that lists the sessions and yields each resumed session to a closure, then call it from all three functions. The per-session checks stay in each caller.
