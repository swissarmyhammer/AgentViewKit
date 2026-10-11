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
- actor: claude-code
  id: 01m4nt9z3gwmtnsz6ne6847c5w
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (a675ebd). 2 findings, 2 confirmed, 0 refuted. Tests/AgentViewKitTests/Elicitation/ElicitationURLConsentViewHostedTests.swift:158, Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewHostedTests.swift:237 (reuse/reuse).
    - next: Move the minimum-height check into one shared helper in Sources/AgentViewKitTestSupport. Make the permission, URL consent and agent auth tests call it.
  timestamp: 2026-10-11T15:46:35.248004+00:00
- actor: claude-code
  id: 01m4ntab50e15y9t607fnj1h4a
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 4 files (PermissionView, ElicitationURLConsentView and their hosted tests)
    - test: green — swift test, 1044 tests passed, load average 65 to 73
    - commit: a675ebd
    - review: findings — Tests/AgentViewKitTests/Elicitation/ElicitationURLConsentViewHostedTests.swift:158, Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewHostedTests.swift:237
  timestamp: 2026-10-11T15:46:47.584803+00:00
- actor: claude-code
  id: 01m4ntrh3rpbzy2hnr6t28e1va
  text: |-
    Work on the 2 review findings:
    - New helper `HostedLayoutExpectations.expectMinimumHeightFitsWidth(of:width:sourceLocation:)` in Sources/AgentViewKitTestSupport/HostedLayoutExpectations.swift. It hosts the view in an `NSHostingController`, measures `sizeThatFits(in: .zero)` and the size at the width, and records the `#expect` at the location of the caller. The helper is a static function on an enum, because the swift immutability rule forbids a new top-level function.
    - The three tests `theMinimumHeightOfTheCardIsNotMoreThanItsHeightAtTheCardWidth` (AgentAuthViewHostedTests, PermissionViewHostedTests, ElicitationURLConsentViewHostedTests) now keep only their setup and call the helper. No `NSHostingController` or `sizeThatFits` stays in the three test files.
    - New Tests/AgentViewKitTests/TestSupport/HostedLayoutExpectationsTests.swift: a wrapped `Text` passes, and a wrapped `Text` with `.fixedSize(horizontal: false, vertical: true)` records an issue inside `withKnownIssue`. So the helper can fail.
    - RED: `swift build --build-tests` failed with "cannot find 'HostedLayoutExpectations' in scope" before the helper existed. GREEN: the three tests passed.
    - The full run reports "1 known issue". This is the expected issue of the failure test, not a skipped test.
  timestamp: 2026-10-11T15:54:32.440084+00:00
- actor: claude-code
  id: 01m4ntrmtvz1qz1ajat9fche6j
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKitTestSupport/HostedLayoutExpectations.swift (new), Tests/AgentViewKitTests/TestSupport/HostedLayoutExpectationsTests.swift (new), Tests/AgentViewKitTests/Connections/AgentAuthViewHostedTests.swift, Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewHostedTests.swift, Tests/AgentViewKitTests/Elicitation/ElicitationURLConsentViewHostedTests.swift. `swift test`: 1046 tests in 110 suites passed (1 known issue, expected), 89 tests in 9 suites passed, 1 test in 1 suite passed, 0 failures. Load average 32.05 at start, 37.16 at end. One build-system warning from the `mlx-swift` bundle in `.build` ("missing creator for mutated node"), the same as on earlier cards. Both findings are checked.
    - next: /review. The task stays in doing. No commit.
  timestamp: 2026-10-11T15:54:36.251267+00:00
- actor: claude-code
  id: 01m4nv6ndhe6nhwb43hp6r1cab
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (56c30de). 0 findings, 0 confirmed, 0 refuted. 5 files reviewed, 7 pairs attempted, 0 failed. All prior findings are checked.
    - next: none. The task is in done.
  timestamp: 2026-10-11T16:02:15.601354+00:00
- actor: claude-code
  id: 01m4nv6xx7dgt1emxqxaqp5tb9
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — shared helper HostedLayoutExpectations.expectMinimumHeightFitsWidth(of:width:); 5 files; both findings checked
    - test: green — swift test, 1046 tests passed, 1 expected known issue, load average 35 to 46
    - commit: 56c30de
    - review: clean — 0 findings (5 files); task in done
  timestamp: 2026-10-11T16:02:24.295626+00:00
position_column: done
position_ordinal: ffa280
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

## Review Findings (2026-10-11 10:42)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 4 file(s) reviewed, 2 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

- [x] `Tests/AgentViewKitTests/Elicitation/ElicitationURLConsentViewHostedTests.swift:158` `reuse/reuse` — The new test `theMinimumHeightOfTheCardIsNotMoreThanItsHeightAtTheCardWidth` duplicates the same minimum-height body that exists in the permission card tests and the agent auth card tests. The copy in this file will drift from the others. Call the shared minimum-height helper, which would live in Sources/AgentViewKitTestSupport, with `ElicitationURLConsentView(request:owner:)` as the view. Keep only the elicitation setup in this test.
- [x] `Tests/AgentViewKitTests/HumanInTheLoop/PermissionViewHostedTests.swift:237` `reuse/reuse` — The new test `theMinimumHeightOfTheCardIsNotMoreThanItsHeightAtTheCardWidth` repeats the same body (open a scripted session, host the card in an NSHostingController, compare `sizeThatFits(in: .zero)` with the height at card width) that already exists in two other test files. Each copy must be fixed separately when the check changes. Move the minimum-height assertion into a shared helper in Sources/AgentViewKitTestSupport, such as `assertMinimumHeightFitsWidth(_ controller: NSHostingController<some View>, width: CGFloat)`, and have all three tests call it with their own view. Each test keeps only its setup.
