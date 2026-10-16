---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m52t75mswe1644mn11wn60t7
  text: |-
    Research (implement step):
    - SessionListView (Sources/AgentViewKit/Sessions/SessionListView.swift) shows connection.sessions. A row is an HStack: the resume control (identifier session-row-<id>) and the delete button. The badge goes in this HStack, outside the resume button, so that it keeps its own identifier.
    - ACPClient: ConnectionModel.session(for:) reads openSessions (observable). SessionModel.pendingRequests holds the permissions and the elicitations in arrival order. acceptElicitation(_:content:) is synchronous on the main actor and removes the item at once.
    - Test helpers: ScriptedSession.sendInOrder(_:) waits only on the pending requests of ScriptedSession.model. Requests for a second open session need a variant that waits on the model of that session, and params with the sessionId of that session (permissionParams and formElicitationParams have the scripted session id in them).
    - SessionPickerConnectionModelHostedTests.mountPicker builds the picker; it needs a currentSession parameter.
    - A second open session: agent.resultQueues["session/new"] with one result for each session, then connection.newSession (the suite already does this).
    - macOS 27 target, so accessibilityLabel(content:) is available to add the open question text to the label of the row.
  timestamp: 2026-10-16T16:55:11.257635+00:00
- actor: claude-code
  id: 01m52trqzbt4s0qy51wmcy2g1x
  text: |-
    Implementation landed (not committed, task stays in doing).
    - New public PendingRequestCountBadge(session:) in Sources/AgentViewKit/Sessions/PendingRequestCountBadge.swift: identifier(for:) gives session-row-<id>-pending, openQuestionsLabel(count:) gives "1 open question" / "N open questions". The badge shows the number in a capsule, and nothing when the count is 0. It makes no announcement.
    - SessionListView: new init parameter currentSession: SessionId? = nil. A row of an open session (connection.session(for:)) that is not the current session shows the badge outside the resume button, and the row label adds the open question text through accessibilityLabel(content:).
    - Test support: ScriptedSession.makePermissionParams(sessionId:) and makeFormElicitationParams(sessionId:) (the old static lets now use them). Test helpers: AgentRequest.permission(id:sessionId:), AgentRequest.formElicitation(id:sessionId:), sendInOrder(_:to:) (sendInOrder(_:) calls it with the scripted model). SessionPickerConnectionModelHostedTests.mountPicker has a currentSession parameter.
    - README: the SessionListView bullet tells about the badge.
    - Press rule: the new hosted tests have no press and no key. They answer through the model API (acceptElicitation, which is synchronous, and selectPermission, which removes the request before it returns). After selectPermission the test does try #require on the empty list before the render.
    - TDD: RED was 10 issues in 5 tests (stub API), then GREEN. The test theAnswerOfTheLastRequestRemovesTheBadge came after the count > 0 code, so it had no RED run.

    ### implement — changed
    - evidence: 7 files — Sources/AgentViewKit/Sessions/PendingRequestCountBadge.swift (new), Sources/AgentViewKit/Sessions/SessionListView.swift, Sources/AgentViewKitTestSupport/ScriptedSession.swift, Tests/AgentViewKitTests/Helpers/ScriptedSessionRequests.swift, Tests/AgentViewKitTests/Sessions/SessionPickerConnectionModelHostedTests.swift, Tests/AgentViewKitTests/Sessions/PendingRequestCountBadgeHostedTests.swift (new), Tests/AgentViewKitTests/Sessions/PendingRequestCountBadgeTests.swift (new), README.md. `swift build --build-tests` complete with no warning from the package code. `swift test --skip-build --filter 'PendingRequestCountBadge'`: 6 tests in 2 suites passed. Affected suites (session picker, recorded sessions, request deck, pending requests, permission, elicitation, tool call, commands, thread accessibility, symbols, scripted session, badge): 225 tests in 19 suites passed. ReadmeCoverageTests: 12 passed. Scripts/check-readme.sh: passed.
    - next: /review
  timestamp: 2026-10-16T17:04:47.083581+00:00
- actor: claude-code
  id: 01m52vd7jc909etq31yng850vp
  text: |-
    ### test — green
    - no other swift build or swift test of this package ran. Found: index builds of other packages, and a test run of FoundationModelsAgents (checked with lsof cwd).
    - first run: swift build --build-tests complete, no warning in Sources/ or Tests/ (one SwiftPM warning only: "missing creator for mutated node ... mlx-swift_Cmlx.bundle"). swift test --skip-build: 1 failure. FixedColorTests.noViewUsesAFixedSystemColor found Sources/AgentViewKit/Sessions/PendingRequestCountBadge.swift:70 (.foregroundStyle(.white)). Message: "Use a color of the EditorKit theme".
    - fix: in PendingRequestCountBadge.swift the number uses editorTheme.accent and the capsule is Capsule().fill(editorTheme.accent.opacity(Self.fillOpacity)), the same as InlineCitationPill. New: import EditorSwiftUI and EditorTheme, @Environment(\.editorTheme), static let fillOpacity = 0.18. The fixed .white and .tint are gone from the whole file.
    - verify: swift build --build-tests (no warning in Sources/ or Tests/); swift test --skip-build --filter "FixedColorTests|PendingRequestCountBadge": 6 tests in 2 suites passed.
    - final full run: swift test --skip-build: 1258 tests in 147 suites passed, 2 known issues (existing withKnownIssue marks); PackageStructureTests 127 tests passed; 0 failures, 0 skipped.
    - Scripts/check-readme.sh (one time): "README gate passed".
    - no commit, no push.
    - next: review
  timestamp: 2026-10-16T17:15:58.412709+00:00
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BCGGAV4K4YPJ5ZSTWA42Z
position_column: doing
position_ordinal: '80'
title: 'Elicitation task 40: show open question counts for sessions not on screen'
---
elicitation-plan.md task 40, section 4: a session that is not on screen shows a count of its open questions (from its pendingRequests). Where the count shows comes from the accepted deck design. Tests with the step 7 rules. Write all text in STE.

## Accepted design
Source: deck design section 6, test plan row 40 (design card 01M51BBZPSYD6PQ2CSQAQQTHFK).

What to build:
- Each SessionListView row shows connection.session(for: info.sessionId)?.pendingRequests.count. A session that is not open has no model and no count (the router cancels its questions).
- ACPClient API: ConnectionModel.openSessions and session(for:) (Model/ConnectionModel.swift:41, :373).
- New optional init parameter on SessionListView: currentSession: SessionId? = nil. Its row has no badge.
- A public PendingRequestCountBadge(session:).
- Badge identifier session-row-<id>-pending. Text = the number. The row label adds "1 open question" / "N open questions".
- No announcement on a count change.

Answers:
- Q6 yes: a currentSession parameter on SessionListView, and a public PendingRequestCountBadge(session:).

Test plan (row 40). Rules: no clock wait, sleep, poll, retry or timeLimit. Hosted suites use .hostedSerially (HostedTestLock). After a main-actor change: render(). After async work: render(when:) or ObservationWait.until on a certain event. No new XCUITest, no new waitForExistence.
- [x] Two open sessions with requests show counts. The currentSession row has no badge.
- [x] Answer one request: the count changes.
- [x] Unit test of the plural text ("1 open question", "N open questions").
- Waits: render(when: both sessions have pendingRequests); ObservationWait.until { count changed } after the answer, then render().

#elicitation-phase-6