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