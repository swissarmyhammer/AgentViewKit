---
assignees:
- claude-code
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BCGGAV4K4YPJ5ZSTWA42Z
position_column: todo
position_ordinal: '9980'
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
- [ ] Two open sessions with requests show counts. The currentSession row has no badge.
- [ ] Answer one request: the count changes.
- [ ] Unit test of the plural text ("1 open question", "N open questions").
- Waits: render(when: both sessions have pendingRequests); ObservationWait.until { count changed } after the answer, then render().

#elicitation-phase-6