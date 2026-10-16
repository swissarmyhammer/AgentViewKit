---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m530zadxdr741b6ccssybd46
  text: |-
    Research and work:
    - ACPTabView holds the selected session in phase, as .started(.running(agent, session)). The sidebar now reads the session from that case and gives `currentSession: session.sessionId` to SessionListView. The `select` function and the `onOpen` closure set phase, so the sidebar gets the new id when the user picks or opens another session.
    - `sessionList(of:)` is now `sessionList(of:showing:)`. The onOpen closure parameter is now `resumed`, so that it does not hide the new `session` parameter.
    - The demo has only XCUITests (ACPTabEndToEndTests, GalleryTabEndToEndTests, 5 tests). It has no hosted or unit test target. The rules forbid a new XCUITest and a new waitForExistence, so this step adds no test. The library hosted test PendingRequestCountBadgeHostedTests already checks that the row of currentSession has no badge.
    - The card says "Push with ^74gyjm5". The step owner said: do not commit and do not push. Thus this step did not push.
  timestamp: 2026-10-16T18:53:14.045715+00:00
- actor: claude-code
  id: 01m530zrb44n08wqxgbgf6b3fa
  text: |-
    ### implement — changed
    - evidence: 1 file, Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift. Command: ./Scripts/test-examples.sh AgentViewKitDemo (the same command as the CI job "Examples (AgentViewKitDemo)"), full run, one time. BUILD SUCCEEDED, TEST SUCCEEDED, 5 UI tests, 0 failures. No warning in the demo code. All build warnings come from the C++ headers of the mlx-swift checkout. No new test: the demo has XCUITests only.
    - next: review. The push item stays open, because the step owner said: do not commit and do not push.
  timestamp: 2026-10-16T18:53:28.292945+00:00
- actor: claude-code
  id: 01m5310ha5431kfp3r8p5wbspp
  text: |-
    ### test — green
    - evidence: the change is only in Examples/AgentViewKitDemo/AgentViewKitDemoFeature/ACPTabView.swift, and `swift test` of the package does not build the demo. The full test of this change is the demo CI gate: `./Scripts/test-examples.sh AgentViewKitDemo`, one full run in the implement step: BUILD SUCCEEDED, TEST SUCCEEDED, 5 tests, 0 failures. No warning in the demo code. It was not run again (no repeat runs).
    - next: commit, review, push with ^74gyjm5.
  timestamp: 2026-10-16T18:53:53.861947+00:00
depends_on:
- 01M52QADYKA9KNNYBY174GYJM5
position_column: doing
position_ordinal: '80'
title: 'Demo: give SessionListView the current session in ACPTabView'
---
Request of the step owner after card 40 (^b94apm2, commits ee57f08 and 4e86318). Write all text in STE.

## Fact
- Card 40 added `SessionListView(currentSession:)`. A row of an open session that is not the current session shows `PendingRequestCountBadge` and adds the count text to its label.
- The demo app (`Examples/.../ACPTabView.swift`) does not give `currentSession`. Thus the demo shows the badge on the row of the session that is on screen too.

## To do
- [x] In ACPTabView, give `currentSession` the id of the session that the tab shows.
- [x] Build the demo and run its tests one time (the Examples CI job builds AgentViewKitDemo). Use the commands of the demo target; follow the test rules: fixed order, no clock wait, sleep, poll, retry or timeLimit.
- [ ] Push with ^74gyjm5. #elicitation-phase-6