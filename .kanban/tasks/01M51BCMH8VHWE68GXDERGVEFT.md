---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m51bdracz0he6gmjr5prx2gj
  text: |-
    ### Prerequisite done (from the step owner)
    Elicitation task 8 is done in ACPAgent 3a3d67e: after a URL accept, the agent sends elicitation/complete only when the flow ends, or when the question ends with no answer. Thus the "waiting" state in the client can last, and this task can show it.
  timestamp: 2026-10-16T03:17:23.916001+00:00
depends_on:
- 01M51BBZPSYD6PQ2CSQAQQTHFK
- 01M51BCJD70S015GWDGB94APM2
position_column: todo
position_ordinal: 9a80
title: 'Elicitation task 41: show the URL elicitation waiting state'
---
elicitation-plan.md task 41: show the waiting state of a URL elicitation after the user gave consent and until the flow ends. Needs ACPAgent task 8 (send URL elicitation complete only when the flow ends); check its state before the work. Do it as the accepted deck design says. Tests with the step 7 rules. Write all text in STE.

## Prerequisites
Needs ACPClient elicitation-plan task 51 and 52 (awaitingURLCompletions/stopWaiting) pushed first. Task 51 is ConnectionModel.frontRequest/bringToFront. Both are done in the ACPClient package by another session, not on this board. ACPAgent task 8 is done (ACPAgent 3a3d67e, see the comment).

Repairs bug card ^rkwj84j (01M51WCGABKMC64K4RPRKWJ84J: the browser session stops when the user accepts a URL request).

## Accepted design
Source: deck design section 7, facts A and B, test plan row 41 (design card 01M51BBZPSYD6PQ2CSQAQQTHFK).

Fact A: the URL "waiting" state has no data source today. acceptElicitation removes the request from the model, so ModelClient.elicitationComplete (ModelClient.swift:126) finds no match later.

ACPClient prerequisite (task 52):
- After acceptElicitation of a URL elicitation, the model keeps it in public var awaitingURLCompletions: [PendingElicitation] on SessionModel and ConnectionModel.
- It is removed on elicitation/complete (completeElicitation), cancel(meta:), cancelAllPending(), close, and public func stopWaiting(_ id:). ACPAgent 3a3d67e already sends complete only when the flow ends.

The deck:
- Shows the awaiting elicitations as cards in the same ForEach with the same id, after the pending cards, so ElicitationURLConsentView keeps its @State phase and browser task. This repairs fact B.
- They are not in "k of N". The header adds "1 waiting". After the accept, the next pending card comes to the front.
- The waiting card shows "Waiting for <targetHost> to finish" with a progress indicator, and two buttons: Retry (opens the browser again) and Stop waiting (stopWaiting, stops the browser).
- The tool call status shows "Waiting for <host>" while its elicitation is in awaitingURLCompletions.
- No announcement for a URL waiting state (task 37).

Answers:
- Q7 yes for v1: Stop waiting does not tell the agent. Card ^6hnfscd (01M51WCMFZP7V301NFF6HNFSCD) records the need for a later ACP message.

Test plan (row 41). Rules: no clock wait, sleep, poll, retry or timeLimit. Hosted suites use .hostedSerially (HostedTestLock). After a main-actor change: render(). After async work: render(when:) or ObservationWait.until on a certain event. No new XCUITest, no new waitForExistence.
- [ ] ACPClient tests for awaitingURLCompletions (in that package, task 52).
- [ ] Press Open: elicitation-waiting shows, the next card comes to the front, and the fake presenter is not cancelled.
- [ ] The agent sends complete: the card goes away and the fake presenter records a cancel.
- [ ] Stop waiting removes the card.
- Waits on awaitingURLCompletions.count and fake.cancelCount (ObservationWait.until on each, then render()).

#elicitation-phase-6