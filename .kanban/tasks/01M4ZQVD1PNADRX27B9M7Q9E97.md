---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4zyg8n0fjsnps585aj8jzm5
  text: |-
    ### Decisions from the step owner (after T0)
    - ExampleGateTimeLimitTests.swift:53: remove the .timeLimit trait. If the subject of the test is the value of the CI example time limit, check that value as data, with no trait.
    - Replace the 3 Task.sleep, the 39 waitUntil polls, the 327 pump(until: waitTimeout) and the 273 harness.pump() calls with waits on events (withObservationTracking on the models, gates, fixed orders). Do it in several commits by area, each with one full run.
    - If a wait has no event (for example a SwiftUI or AppKit render that the test must let happen), report that kind of wait with an example to the step owner BEFORE you change it. Do not invent a time bound.
    - The 9 XCUITest waitFor…Existence(timeout:) calls can stay (XCUITest drives the app in another process). Add no new ones.
  timestamp: 2026-10-15T14:12:20.256310+00:00
- actor: claude-code
  id: 01m501pjfxgbwwvgd12b4mx1gx
  text: |-
    ### Decision from the step owner: the pattern for render waits
    First make the render happen directly where the test can (for example `layoutSubtreeIfNeeded()` on the hosting view, or a display pass of the window), then check, so that the test does not depend on when the run loop turns. Where no such call exists, wait on the event (ObservationWait.until on the observed value, or the appear callback), with no time bound. A small internal observation point is OK where a value is not observable. Example: ^66f5w2n.
  timestamp: 2026-10-15T15:08:12.669055+00:00
- actor: claude-code
  id: 01m5064q5qh5fet4h582abgdys
  text: |-
    ### Before the final run
    Move to the ACPClient head that has the fix of ^4tw540d (the step owner gives the head), then do the final full run. Close ^4tw540d after that check.
  timestamp: 2026-10-15T16:25:50.519883+00:00
- actor: claude-code
  id: 01m50743axan5ew8byae6ec21p
  text: |-
    ### ACPClient head for the final run
    Before the final full run, move FoundationModelsACPClient to d321543 (`swift package update`; CI green there). It has the resume fix of ^4tw540d. ^4tw540d stays open for the session/new part (ACPClient ^hfby9sz).
  timestamp: 2026-10-15T16:42:58.781762+00:00
- actor: claude-code
  id: 01m5091qt983et2hgt0q64k2kd
  text: |-
    ### Decision from the step owner (from ^809cwz0)
    - ConversationViewHostedTests, ThreadMinimapViewHostedTests and AgentCommandScopeHostedTests wait for the SwiftUI visibility report. Give them the treatment of ^809cwz0: a unit test that feeds the reports in a fixed order, a hosted check after a direct layout pass with no wait for the report, and a check (or a named gap in the doc) for the link between the SwiftUI callback and the handler.
    - A hosted test holds HostedTestLock. If it waits with no bound for an event that does not come, all other hosted tests stop. Each hosted wait must wait for an event that is certain to come.
  timestamp: 2026-10-15T17:16:38.601273+00:00
depends_on:
- 01M4ZQV6P05Y91E6AAAPVJE3W3
position_column: todo
position_ordinal: '8480'
title: 'Mail step 7 T4: Remove time limits and clock waits from the tests, align the docs, run the full suite, push, and report'
---
1. Remove the .timeLimit trait and each sleep, clock wait and poll in the tests. Use a wait on an event, a gate or a fixed order. A clock may only measure and print time.
2. Make the docs and comments agree with the new ACPAgent behavior (no turn words; state changes with no prompt open; an idle with no stop reason; more than one open prompt; cancel while idle with pending requests; the announcement only for the idle that ends a user prompt).
3. One full test run. Run the examples check if the CI runs it.
4. The final commit and the push. Report the head and the CI result.
5. Final report: the list of commits, and the check of mailbox.md row 7: "AgentViewKit builds and passes its tests against the mains that steps 1 to 6 checked, and elicitation-plan tasks 47 and 48 are done."

If a test hangs, take a `sample <pid>` of the test process first, then stop only that process id (never pkill or a pattern kill). Delete no test without a decision. Write all text in STE. #mail-step-7