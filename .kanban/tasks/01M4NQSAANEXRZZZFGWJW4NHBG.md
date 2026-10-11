---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4nst1rwtts99zcc0hp8n3jw
  text: |-
    Research and work:
    - RED: two new hosted tests `theMinimumHeightOfTheCardIsNotMoreThanItsHeightAtTheCardWidth` failed before the change. `PermissionView` with a description: minimum height 874 pt, height at 640 pt width 95 pt. `ElicitationURLConsentView` with a Punycode URL (URL text and warning): minimum height 2151 pt, height at 520 pt width 158 pt.
    - GREEN: removed `.fixedSize(horizontal: false, vertical: true)` from the description text of `PermissionView`, and from the URL text and the warning label of `ElicitationURLConsentView`. Added a doc paragraph on each card. Both tests pass.
    - Test helper change: `PermissionViewHostedTests.makeParams` has a new `description` parameter (default `nil`).
    - Search of the other views that `AgentThreadView` shows outside its scroll view (`AgentInfoHeader`, `AgentConnectionBanner`, `SessionNoticeBanner`, `SessionStreamBanner`, `AgentLoginPrompt`/`AgentAuthView`, `PendingRequestsHost`, `ElicitationView`): none has a fixed vertical size now.
    - Other `fixedSize(horizontal: false, vertical: true)` sites in Sources stay. `MathView` is in the transcript scroll view. The completion list of `EditorKitPromptEditor` has a fixed width of 280 pt. `StockPromptEditor` and `EditorKitPromptEditor` clamp the height to 36...200 pt. A probe that I deleted after the run gave minimum height 36 pt and height at 640 pt width 36 pt for both editors, with 4 sentences of text.
    - The first full `swift test` run got SIGTERM after 59 s with no test output, from a cause that is not known. No other build ran in this repository. The second run was green.
  timestamp: 2026-10-11T15:37:53.692304+00:00
- actor: claude-code
  id: 01m4nst4w2yfa9exg71hh1v7vr
  text: |-
    ### implement — changed
    - evidence: 4 files — Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift, Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift, Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewHostedTests.swift, Tests/AgentViewKitTests/Elicitation/ElicitationURLConsentViewHostedTests.swift. `swift test`: 1044 tests in 109 suites passed, 0 failures. Load average 67.96 at start, 58.57 at end. One build-system warning from the `mlx-swift` bundle in `.build` ("missing creator for mutated node"). Earlier cards show the same warning, so this change did not cause it.
    - next: /review. The task stays in doing. No commit.
  timestamp: 2026-10-11T15:37:56.866119+00:00
position_column: doing
position_ordinal: '80'
title: Remove the fixed vertical text size from the request cards of the thread
---
## What
`AgentThreadView` shows `PendingRequestsHost` in its non-scrolling area. These cards use `.fixedSize(horizontal: false, vertical: true)` on wrapped texts:

- `PermissionView`: the description text of the request.
- `ElicitationURLConsentView`: the URL text and the warning label.

A text with a fixed vertical size gives its full wrapped height at width 0 as its minimum height. Then the card is taller at its minimum size than at its usual width. In a `NavigationSplitView` column, this large minimum size goes to the window. Task ^nh1h15p found the same cause in `AgentAuthView`: it made the AgentViewKitDemo window min size 562 x 779 pt (124 pt without the card), and AgentViewKitDemo stopped with an `NSGenericException` constraint update loop in `SplitViewChildController.hostingView(_:didUpdateMinSize:maxSize:)`.

## Work
- [x] For each card, write a hosted test: the minimum height (`NSHostingController.sizeThatFits(in: .zero)`) is not more than the height at a usual width.
- [x] Remove the fixed vertical size from the texts of `PermissionView` and `ElicitationURLConsentView`, or give the texts another layout that keeps the minimum height small.
- [x] Look for the same pattern in each other view that `AgentThreadView` shows outside the scroll view.