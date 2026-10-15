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
- actor: claude-code
  id: 01m50dc65xmnnw9nxbcczc3jca
  text: |-
    ### New heads for the final run
    Before the final full run, AgentViewKit uses FoundationModelsACPClient 9cedcb9 (not d321543) and FoundationModelsACP fb55b2f. Task ^4tw540d adds its test on these heads, before the final run.
  timestamp: 2026-10-15T18:32:15.293941+00:00
- actor: claude-code
  id: 01m50e23saccpyewxr61kkm6wd
  text: |-
    ### Row 7 base (decision of the step owner)
    - The row 7 base is the current mains: FoundationModelsACPClient 9cedcb9 or later (main is now 904e541), FoundationModelsACP fb55b2f, FoundationModelsACPAgent 180333b, FoundationModelsRouter fa9bf08, FoundationModelsExtras dbd91de. Each one is pushed and checked. The newer ones add only phase 2 elicitation work (UserPresence, headless sessions, the ACPClient fixes).
    - Do not pin. The package rule stays branch main, and Package.resolved is not committed.
    - ACPClient 904e541 (task 28): a question in a mode that the client did not advertise gets cancel at once. AgentViewKit advertises form and URL, so nothing changes for it.
    - Before the final full run: `swift package update` to the mains of that time, and record the resolved revisions in the final report.
  timestamp: 2026-10-15T18:44:13.738139+00:00
- actor: claude-code
  id: 01m50eryksna6q0dfz83tzk8tf
  text: |-
    ### T4 split into area tasks
    The test waits are done in the area tasks T4-A0 (harness, .timeLimit, Task.sleep) and T4-A1 to T4-A6 (one folder group each), and ^yr4zgpz. Each area has one full run and one commit. This task (T4) keeps: the removal of the deprecated wait helpers when no use is left, the docs and comments (no turn words in doc comments; the new ACPAgent behavior), the update to the current mains, the final full run, the examples check, the push, the CI check and the final report with the row 7 check.
  timestamp: 2026-10-15T18:56:42.105512+00:00
depends_on:
- 01M4ZQV6P05Y91E6AAAPVJE3W3
- 01M50ER0NN5DRGV5S3HGQ8H07P
- 01M50ER6WG0M4KZGQ0PCRSAZ8T
- 01M50ER8XX5DEBPXETVW35TFS4
- 01M50ERBW1VKTTV9CJJE9ZR6DX
- 01M50ERDTD2K1RZGM21N0JVM90
- 01M50ERG58ANWMMVTG535SW345
- 01M50ERJRW6EXQ0YFCRYVDG1F4
- 01M50752E2QZQ69JD3WYR4ZGPZ
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